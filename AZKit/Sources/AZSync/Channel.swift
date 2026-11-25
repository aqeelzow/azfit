import AZModel
import Foundation
import Network
import Synchronization

/// TLS with a pre-shared key from the pairing code. Only someone holding the key can connect, both ways, and the
/// traffic is encrypted. The identity tells the bridge which pairing's key the phone is using.
public enum ChannelSecurity {
    public struct Key: Sendable, Equatable {
        public var identity: String
        public var secret: Data

        public init(identity: String, secret: Data) {
            self.identity = identity
            self.secret = secret
        }

        public init(_ code: PairingCode) {
            self.init(identity: code.pairingID.uuidString.lowercased(), secret: code.key)
        }
    }

    /// The phone's side: one key. The bridge's side: every paired phone's key.
    public static func parameters(keys: [Key]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        for key in keys {
            sec_protocol_options_add_pre_shared_key(options, dispatchData(key.secret), dispatchData(Data(key.identity.utf8)))
        }
        // External pre-shared keys need TLS 1.2 and a PSK cipher suite in Network.framework.
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_append_tls_ciphersuite(options, tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!)

        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 15
        tcp.connectionTimeout = 10
        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = true
        return parameters
    }

    private static func dispatchData(_ data: Data) -> __DispatchData {
        data.withUnsafeBytes { DispatchData(bytes: $0) } as __DispatchData
    }
}

/// One connection between the phone and the bridge: sends and receives `Message`s.
/// Call `start()`, read `messages` until it finishes, and `close()` when done.
public final class Channel: Sendable {
    public enum Failure: Error, CustomStringConvertible {
        case closed
        case network(String)

        public var description: String {
            switch self {
            case .closed: "The connection closed."
            case .network(let message): message
            }
        }
    }

    public let connection: NWConnection
    public let messages: AsyncThrowingStream<Message, any Error>
    private let continuation: AsyncThrowingStream<Message, any Error>.Continuation
    private let queue = DispatchQueue(label: "azfit.channel")
    private let state = Mutex(State())

    private struct State {
        var buffer = FrameBuffer()
        var started = false
        var ready: CheckedContinuation<Void, any Error>?
    }

    public init(_ connection: NWConnection) {
        self.connection = connection
        (messages, continuation) = AsyncThrowingStream.makeStream()
    }

    /// Connects (or accepts) and waits until the TLS handshake is done.
    public func start() async throws {
        try await withCheckedThrowingContinuation { (ready: CheckedContinuation<Void, any Error>) in
            state.withLock { $0.ready = ready }
            connection.stateUpdateHandler = { [weak self] in self?.handle($0) }
            connection.start(queue: queue)
        }
    }

    public func send(_ message: Message) async throws {
        let frame = try Framing.frame(message)
        try await withCheckedThrowingContinuation { (sent: CheckedContinuation<Void, any Error>) in
            connection.send(
                content: frame,
                completion: .contentProcessed { error in
                    if let error { sent.resume(throwing: Failure.network(error.localizedDescription)) } else { sent.resume() }
                })
        }
    }

    public func close() {
        connection.cancel()
    }

    private func handle(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            let ready = state.withLock { state in
                defer { state.ready = nil }
                state.started = true
                return state.ready
            }
            ready?.resume()
            receive()
        case .waiting(let error), .failed(let error):
            // `waiting` means the network path is down or the handshake was refused (wrong key). Give up rather
            // than retry forever: the caller decides when to try again.
            finish(Failure.network(Self.describe(error)))
        case .cancelled:
            finish(Failure.closed)
        default:
            break
        }
    }

    private func finish(_ error: Failure) {
        let ready = state.withLock { state in
            defer { state.ready = nil }
            return state.ready
        }
        ready?.resume(throwing: error)
        if case .closed = error { continuation.finish() } else { continuation.finish(throwing: error) }
        if connection.state != .cancelled { connection.cancel() }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                do {
                    let bodies = try state.withLock { state in
                        state.buffer.append(data)
                        var bodies: [Data] = []
                        while let body = try state.buffer.next() { bodies.append(body) }
                        return bodies
                    }
                    for body in bodies {
                        // A message this version doesn't know is skipped, so a newer peer doesn't break an older one.
                        if let message = try? DivJSON.decode(Message.self, from: body) { continuation.yield(message) }
                    }
                } catch {
                    return finish(.network("The other side sent a frame that was too large."))
                }
            }
            if let error { return finish(.network(Self.describe(error))) }
            if isComplete { return finish(.closed) }
            receive()
        }
    }

    static func describe(_ error: NWError) -> String {
        switch error {
        case .tls: "The bridge didn't accept this phone's key. Pair again."
        case .posix(let code) where code == .ECONNREFUSED: "The bridge isn't running."
        case .posix(let code) where code == .ETIMEDOUT: "The bridge didn't answer."
        default: error.localizedDescription
        }
    }
}
