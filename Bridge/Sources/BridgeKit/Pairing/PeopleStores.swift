import AZStore
import Foundation
import Synchronization

/// The bridge's copy of each person's database, one file per person (D-024), in
/// ~/Library/Application Support/AZfit Bridge/people/<person id>.sqlite.
public final class PeopleStores: Sendable {
    public let folder: URL
    private let open = Mutex<[UUID: AZStore]>([:])

    public init(folder: URL) {
        self.folder = folder
    }

    public static func standard() -> PeopleStores {
        PeopleStores(folder: PairingStore.supportFolder.appending(path: "people"))
    }

    /// The database for `person`, created on first use.
    public func store(for person: UUID) throws -> AZStore {
        try open.withLock { open in
            if let store = open[person] { return store }
            let store = try AZStore(url: folder.appending(path: "\(person.uuidString.lowercased()).sqlite"))
            open[person] = store
            return store
        }
    }
}
