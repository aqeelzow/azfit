import AZSync
import Foundation
import Synchronization

/// The bridge's ID and the phones paired with it, saved in a file only this user can read.
/// The keys are what let a phone in, so they never leave this file except inside a pairing code.
public final class PairingStore: Sendable {
    public struct Pairing: Codable, Sendable, Equatable, Identifiable {
        public var id: UUID
        public var key: Data
        public var createdAt: Date
        /// Set when the phone first connects. Until then the pairing is waiting for its code to be scanned.
        public var phoneName: String?
        public var lastSeen: Date?
    }

    struct Contents: Codable, Equatable {
        var bridgeID = UUID()
        var pairings: [Pairing] = []
    }

    /// Unscanned codes stop working after this long.
    public static let codeLifetime: TimeInterval = 15 * 60

    public let url: URL
    private let contents: Mutex<Contents>

    public init(url: URL) {
        self.url = url
        let saved = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
        contents = Mutex(saved ?? Contents())
        if saved == nil { save() }
    }

    /// ~/Library/Application Support/AZfit Bridge/pairings.json
    public static func standard() -> PairingStore {
        PairingStore(url: supportFolder.appending(path: "pairings.json"))
    }

    /// ~/Library/Application Support/AZfit Bridge
    public static var supportFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "AZfit Bridge")
    }

    public var bridgeID: UUID { contents.withLock { $0.bridgeID } }
    public var pairings: [Pairing] { contents.withLock { $0.pairings } }

    /// Keys a phone may connect with: every paired phone, and codes shown in the last 15 minutes.
    public func keys(now: Date = .now) -> [ChannelSecurity.Key] {
        pairings.filter { $0.phoneName != nil || now.timeIntervalSince($0.createdAt) < Self.codeLifetime }
            .map { ChannelSecurity.Key(identity: $0.id.uuidString.lowercased(), secret: $0.key) }
    }

    /// A new pairing code to show. Codes that were never scanned are dropped.
    public func newCode(bridgeName: String, hosts: [String], port: UInt16, now: Date = .now) -> PairingCode {
        let code = PairingCode(bridgeID: bridgeID, bridgeName: bridgeName, hosts: hosts, port: port)
        contents.withLock { contents in
            contents.pairings.removeAll { $0.phoneName == nil }
            contents.pairings.append(Pairing(id: code.pairingID, key: code.key, createdAt: now))
        }
        save()
        return code
    }

    /// Records that a phone connected with a pairing.
    public func seen(_ id: UUID, phoneName: String, at date: Date = .now) {
        let changed = contents.withLock { contents in
            guard let index = contents.pairings.firstIndex(where: { $0.id == id }) else { return false }
            contents.pairings[index].phoneName = phoneName
            contents.pairings[index].lastSeen = date
            return true
        }
        if changed { save() }
    }

    public func forget(_ id: UUID) {
        contents.withLock { $0.pairings.removeAll { $0.id == id } }
        save()
    }

    private func save() {
        let data = contents.withLock { try? JSONEncoder().encode($0) }
        guard let data else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
