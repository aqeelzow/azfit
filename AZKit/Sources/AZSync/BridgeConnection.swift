import AZModel
import AZStore
import Foundation
import Observation

/// Where the phone keeps its pairing code (the Keychain in the app, memory in tests and previews).
public protocol PairingStorage: Sendable {
    func load() -> PairingCode?
    func save(_ code: PairingCode?)
}

public final class MemoryPairingStorage: PairingStorage, @unchecked Sendable {
    private var code: PairingCode?
    public init(_ code: PairingCode? = nil) { self.code = code }
    public func load() -> PairingCode? { code }
    public func save(_ code: PairingCode?) { self.code = code }
}

/// The phone's view of its Mac: paired or not, connected or not, and Claude's status there.
/// Keeps reconnecting while the app is open, so screens only read `state` and call `ask`.
@MainActor
@Observable
public final class BridgeConnection {
    public enum State: Equatable, Sendable {
        case unpaired
        case connecting
        case connected(BridgeStatus)
        /// Paired, but the Mac can't be reached right now. The reason is for the screen.
        case offline(String)
    }

    public private(set) var state: State = .unpaired
    public private(set) var code: PairingCode?
    public let phoneName: String

    /// True when Div can answer right now.
    public var isReady: Bool {
        if case .connected(let status) = state { return status.claude == .ready }
        return false
    }

    public var bridgeName: String? { code?.bridgeName }

    /// The phone's database. Set it and every connection starts with a sync, and `ask` sends whose data it is.
    @ObservationIgnored public var store: AZStore?
    /// When the last sync finished.
    public private(set) var lastSynced: Date?

    @ObservationIgnored private let storage: any PairingStorage
    @ObservationIgnored private var link: BridgeLink?
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private let retryDelays: [Duration]

    public init(storage: any PairingStorage, phoneName: String, retryDelays: [Duration] = [.seconds(3), .seconds(10), .seconds(30)]) {
        self.storage = storage
        self.phoneName = phoneName
        self.retryDelays = retryDelays
        code = storage.load()
        state = code == nil ? .unpaired : .offline("Not connected yet.")
    }

    /// Pairs with a code from the bridge (scanned or pasted) and connects.
    public func pair(text: String) throws(PairingCode.Failure) {
        let code = try PairingCode(text: text)
        storage.save(code)
        self.code = code
        attempt = 0
        connect()
    }

    public func forget() {
        storage.save(nil)
        code = nil
        stop()
        state = .unpaired
    }

    /// Connects now if paired and not already connected. Call when the app comes to the foreground.
    public func connect() {
        guard let code else { return }
        if case .connected = state { return }
        if case .connecting = state { return }
        work?.cancel()
        link?.close()
        let link = BridgeLink(code: code, phoneName: phoneName)
        self.link = link
        state = .connecting
        work = Task { [weak self] in
            do {
                let status = try await link.connect()
                guard !Task.isCancelled else { return link.close() }
                self?.connected(status)
                for await event in link.events {
                    switch event {
                    case .status(let status): self?.state = .connected(status)
                    case .disconnected(let reason): self?.lost(reason)
                    }
                }
            } catch {
                self?.lost("\(error)")
            }
        }
    }

    /// Stops connecting. Call when the app goes to the background.
    public func stop() {
        work?.cancel()
        work = nil
        link?.close()
        link = nil
        if code != nil { state = .offline("Not connected.") }
    }

    /// Asks Div something through the bridge. Syncs first, so Div reads the latest. A session review needs the workout
    /// on the bridge, so it fails if that sync does.
    public func ask(_ job: Job) async throws -> Outcome {
        switch job {
        case .sync, .estimateMeal, .reviseMeal: break
        case .sessionReview: try await sync()
        case .chat: try? await sync()
        }
        return try await send(job)
    }

    /// Sends the phone's new rows to the bridge and brings back the bridge's (Div's changes), until both are caught up.
    public func sync() async throws {
        guard let store, let person = try store.profile()?.id else { return }
        var more = true
        while more {
            let batch = try store.changes(after: try store.acknowledgedSeq(by: Self.bridgePeer))
            let since = try store.receivedSeq(from: Self.bridgePeer)
            guard case .synced(let pull) = try await send(.sync(SyncPush(batch: batch, since: since)), person: person) else {
                throw BridgeLink.Failure.disconnected("The bridge didn't sync.")
            }
            try store.apply(pull.batch, from: Self.bridgePeer)
            try store.setAcknowledged(pull.received, by: Self.bridgePeer)
            more = batch.more || pull.batch.more
        }
        lastSynced = .now
    }

    static let bridgePeer = "bridge"

    private func send(_ job: Job, person: UUID? = nil) async throws -> Outcome {
        guard let link, case .connected = state else {
            throw BridgeLink.Failure.disconnected(offlineReason ?? "Your Mac isn't connected.")
        }
        let person = try person ?? store?.profile()?.id
        return try await link.ask(job, person: person)
    }

    public var offlineReason: String? {
        if case .offline(let reason) = state { return reason }
        return nil
    }

    private func connected(_ status: BridgeStatus) {
        attempt = 0
        state = .connected(status)
        Task { try? await sync() }
    }

    private func lost(_ reason: String) {
        guard !Task.isCancelled, code != nil else { return }
        state = .offline(reason)
        let delay = retryDelays[min(attempt, retryDelays.count - 1)]
        attempt += 1
        work = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }
}
