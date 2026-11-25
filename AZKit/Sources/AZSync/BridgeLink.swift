import Foundation
import Network
import Synchronization

/// The phone's connection to its paired bridge: finds it, connects, and sends Div jobs.
/// One link is one connection. When it drops, make a new one.
public final class BridgeLink: Sendable {
    public enum Event: Sendable, Equatable {
        case status(BridgeStatus)
        case disconnected(String)
    }

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notFound(String)
        case disconnected(String)
        case olderBridge

        public var description: String {
            switch self {
            case .notFound(let name): "Couldn't find \(name). Is AZfit Bridge running on the same network?"
            case .disconnected(let reason): reason
            case .olderBridge: "Your Mac's AZfit Bridge is out of date. Update it."
            }
        }
    }

    public let code: PairingCode
    public let phoneName: String
    /// Status updates from the bridge, then `disconnected` once, then the stream ends.
    public let events: AsyncStream<Event>
    private let eventSink: AsyncStream<Event>.Continuation
    private let state = Mutex(State())

    private struct State {
        var channel: Channel?
        var pending: [UUID: CheckedContinuation<Outcome, any Error>] = [:]
        var closedReason: String?
    }

    public init(code: PairingCode, phoneName: String) {
        self.code = code
        self.phoneName = phoneName
        (events, eventSink) = AsyncStream.makeStream()
    }

    /// Finds the bridge (Bonjour first, then the addresses in the pairing code), connects, says hello and returns
    /// the bridge's status.
    public func connect(searchFor: Duration = .seconds(4)) async throws -> BridgeStatus {
        let parameters = ChannelSecurity.parameters(keys: [ChannelSecurity.Key(code)])
        var candidates: [NWEndpoint] = []
        if let found = await Self.find(bridgeID: code.bridgeID, within: searchFor) { candidates.append(found) }
        candidates += code.hosts.compactMap { host in
            NWEndpoint.Port(rawValue: code.port).map { NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: $0) }
        }

        var lastError: any Error = Failure.notFound(code.bridgeName)
        for endpoint in candidates {
            let channel = Channel(NWConnection(to: endpoint, using: parameters))
            do {
                try await channel.start()
                return try await greet(channel)
            } catch {
                channel.close()
                lastError = error
            }
        }
        throw lastError
    }

    /// Sends a job and waits for the bridge's answer.
    public func ask(_ job: Job, person: UUID? = nil) async throws -> Outcome {
        let request = Request(job: job, person: person)
        let channel = try state.withLock { state in
            guard let channel = state.channel else { throw Failure.disconnected(state.closedReason ?? "Not connected.") }
            return channel
        }
        return try await withCheckedThrowingContinuation { continuation in
            state.withLock { $0.pending[request.id] = continuation }
            Task {
                do { try await channel.send(.request(request)) } catch { fail(request.id, error) }
            }
        }
    }

    public func close() {
        state.withLock { $0.channel }?.close()
    }

    private func greet(_ channel: Channel) async throws -> BridgeStatus {
        try await channel.send(.hello(Hello(phoneName: phoneName, pairingID: code.pairingID)))
        var messages = channel.messages.makeAsyncIterator()
        guard case .status(let status) = try await messages.next() else { throw Failure.disconnected("The bridge didn't answer.") }
        guard status.wireVersion >= WireVersion.current else { throw Failure.olderBridge }
        state.withLock { $0.channel = channel }
        eventSink.yield(.status(status))
        Task { await read(&messages) }
        return status
    }

    private func read(_ messages: inout AsyncThrowingStream<Message, any Error>.Iterator) async {
        var reason = "The bridge closed the connection."
        do {
            while let message = try await messages.next() {
                switch message {
                case .status(let status):
                    eventSink.yield(.status(status))
                case .response(let response):
                    let waiting = state.withLock { $0.pending.removeValue(forKey: response.id) }
                    waiting?.resume(returning: response.outcome)
                case .hello, .request:
                    break
                }
            }
        } catch {
            reason = "\(error)"
        }
        let waiting = state.withLock { state in
            state.channel = nil
            state.closedReason = reason
            defer { state.pending = [:] }
            return Array(state.pending.values)
        }
        waiting.forEach { $0.resume(throwing: Failure.disconnected(reason)) }
        eventSink.yield(.disconnected(reason))
        eventSink.finish()
    }

    private func fail(_ id: UUID, _ error: any Error) {
        state.withLock { $0.pending.removeValue(forKey: id) }?.resume(throwing: error)
    }

    /// Looks for the bridge with this ID on the local network.
    static func find(bridgeID: UUID, within limit: Duration) async -> NWEndpoint? {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: BridgeService.type, domain: nil), using: parameters)
        let (found, sink) = AsyncStream<NWEndpoint?>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let wanted = bridgeID.uuidString.lowercased()
        browser.browseResultsChangedHandler = { results, _ in
            for result in results {
                if case .bonjour(let txt) = result.metadata, txt[BridgeService.idKey]?.lowercased() == wanted {
                    sink.yield(result.endpoint)
                    sink.finish()
                }
            }
        }
        browser.stateUpdateHandler = { state in
            if case .failed = state { sink.finish() }
        }
        browser.start(queue: .global())
        let timer = Task {
            try? await Task.sleep(for: limit)
            sink.finish()
        }
        var iterator = found.makeAsyncIterator()
        let endpoint = await iterator.next() ?? nil
        timer.cancel()
        browser.cancel()
        return endpoint
    }
}
