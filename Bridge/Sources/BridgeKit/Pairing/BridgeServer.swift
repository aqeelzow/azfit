import AZSync
import Foundation
import Network
import Synchronization

/// Listens for paired phones on the local network (Bonjour) and answers their requests.
/// Only phones holding a pairing key get past the TLS handshake (`ChannelSecurity`).
public final class BridgeServer: Sendable {
    public struct ConnectedPhone: Sendable, Equatable, Identifiable {
        public var id: UUID
        public var name: String
    }

    /// What the menu shows.
    public struct Snapshot: Sendable, Equatable {
        public var port: UInt16?
        public var problem: String?
        public var phones: [ConnectedPhone] = []

        public init() {}
    }

    public let store: PairingStore
    public let bridgeName: String
    private let status: @Sendable () async -> ClaudeStatus
    private let handle: @Sendable (Request) async -> Outcome
    private let onChange: @Sendable (Snapshot) -> Void
    private let queue = DispatchQueue(label: "azfit.bridge-server")
    private let state = Mutex(State())

    private struct State {
        var listener: NWListener?
        var snapshot = Snapshot()
        var channels: [UUID: Channel] = [:]
    }

    /// - Parameters:
    ///   - status: whether Claude is signed in, sent to each phone when it connects.
    ///   - handle: syncs or runs a Div job. Called concurrently, one task per request.
    ///   - onChange: called on any thread when the port or the connected phones change.
    public init(
        store: PairingStore, bridgeName: String, status: @escaping @Sendable () async -> ClaudeStatus,
        handle: @escaping @Sendable (Request) async -> Outcome, onChange: @escaping @Sendable (Snapshot) -> Void = { _ in }
    ) {
        self.store = store
        self.bridgeName = bridgeName
        self.status = status
        self.handle = handle
        self.onChange = onChange
    }

    public var snapshot: Snapshot { state.withLock { $0.snapshot } }

    /// Starts listening, or restarts with the current keys (after a new pairing). Phones already connected stay
    /// connected. With no pairings there is nothing to listen for.
    public func start() {
        let keys = store.keys()
        let previousPort = state.withLock { state in
            state.listener?.cancel()
            state.listener = nil
            return state.snapshot.port
        }
        guard !keys.isEmpty else { return update { $0.port = nil } }
        do {
            let listener = try makeListener(keys: keys, port: previousPort ?? BridgeService.preferredPort)
            state.withLock { $0.listener = listener }
            listener.start(queue: queue)
        } catch {
            update { $0.problem = "Couldn't listen: \(error.localizedDescription)" }
        }
    }

    public func stop() {
        let (listener, channels) = state.withLock { state in
            defer {
                state.listener = nil
                state.channels = [:]
            }
            return (state.listener, Array(state.channels.values))
        }
        listener?.cancel()
        channels.forEach { $0.close() }
    }

    /// Tells every connected phone something changed, such as Claude signing out.
    public func broadcast(_ claude: ClaudeStatus) {
        let channels = state.withLock { Array($0.channels.values) }
        let status = BridgeStatus(bridgeName: bridgeName, claude: claude)
        for channel in channels {
            Task { try? await channel.send(.status(status)) }
        }
    }

    private func makeListener(keys: [ChannelSecurity.Key], port: UInt16) throws -> NWListener {
        let parameters = ChannelSecurity.parameters(keys: keys)
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? .any)
        listener.service = NWListener.Service(
            name: bridgeName, type: BridgeService.type,
            txtRecord: NWTXTRecord([BridgeService.idKey: store.bridgeID.uuidString.lowercased()]))
        listener.stateUpdateHandler = { [weak self, weak listener] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                update {
                    $0.port = listener?.port?.rawValue
                    $0.problem = nil
                }
            case .failed(let error):
                // The preferred port is taken: try any port. Phones find it through Bonjour.
                if case .posix(.EADDRINUSE) = error, port != 0, case let keys = store.keys(), !keys.isEmpty,
                    let fallback = try? makeListener(keys: keys, port: 0)
                {
                    state.withLock { $0.listener = fallback }
                    fallback.start(queue: queue)
                } else {
                    update {
                        $0.port = nil
                        $0.problem = "Stopped listening: \(error.localizedDescription)"
                    }
                }
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        return listener
    }

    private func accept(_ connection: NWConnection) {
        let id = UUID()
        let channel = Channel(connection)
        state.withLock { $0.channels[id] = channel }
        Task {
            defer {
                state.withLock { $0.channels[id] = nil }
                update { $0.phones.removeAll { $0.id == id } }
            }
            do {
                try await channel.start()
                try await serve(channel, id: id)
            } catch {
                channel.close()
            }
        }
    }

    private func serve(_ channel: Channel, id: UUID) async throws {
        for try await message in channel.messages {
            switch message {
            case .hello(let hello):
                if let pairing = hello.pairingID { store.seen(pairing, phoneName: hello.phoneName) }
                update { snapshot in
                    snapshot.phones.removeAll { $0.id == id }
                    snapshot.phones.append(ConnectedPhone(id: id, name: hello.phoneName))
                }
                try await channel.send(.status(BridgeStatus(bridgeName: bridgeName, claude: await status())))
            case .request(let request):
                let handle = handle
                Task {
                    let outcome = await handle(request)
                    try? await channel.send(.response(Response(id: request.id, outcome: outcome)))
                }
            case .status, .response:
                break
            }
        }
    }

    private func update(_ change: (inout Snapshot) -> Void) {
        let snapshot = state.withLock { state in
            change(&state.snapshot)
            return state.snapshot
        }
        onChange(snapshot)
    }
}
