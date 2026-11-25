import Foundation
import GRDB

/// A row as it travels between the phone and the bridge: its table, its ID, and its columns (nil when deleted).
public struct SyncRow: Codable, Sendable, Equatable {
    public var table: String
    public var id: String
    /// A list, not a dictionary, so JSON key conversion never touches column names.
    public var columns: [SyncColumn]?

    public init(table: String, id: String, columns: [SyncColumn]?) {
        self.table = table
        self.id = id
        self.columns = columns
    }
}

public struct SyncColumn: Codable, Sendable, Equatable {
    public var name: String
    public var value: SyncValue

    public init(_ name: String, _ value: SyncValue) {
        self.name = name
        self.value = value
    }
}

/// The rows written since `after`, and the sequence to ask from next time.
public struct SyncBatch: Codable, Sendable, Equatable {
    public var rows: [SyncRow]
    public var lastSeq: Int64
    /// More rows are waiting after `lastSeq`.
    public var more: Bool

    public init(rows: [SyncRow], lastSeq: Int64, more: Bool) {
        self.rows = rows
        self.lastSeq = lastSeq
        self.more = more
    }
}

/// A column value. Every column here is null, a number or text.
public enum SyncValue: Codable, Sendable, Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let int = try? c.decode(Int64.self) {
            self = .integer(int)
        } else if let double = try? c.decode(Double.self) {
            self = .real(double)
        } else {
            self = .text(try c.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .integer(let value): try c.encode(value)
        case .real(let value): try c.encode(value)
        case .text(let value): try c.encode(value)
        }
    }

    init(_ value: DatabaseValue) {
        switch value.storage {
        case .null, .blob: self = .null
        case .int64(let int): self = .integer(int)
        case .double(let double): self = .real(double)
        case .string(let string): self = .text(string)
        }
    }

    var databaseValue: DatabaseValue {
        switch self {
        case .null: .null
        case .integer(let value): value.databaseValue
        case .real(let value): value.databaseValue
        case .text(let value): value.databaseValue
        }
    }
}

extension AZStore {
    public enum SyncError: Error, Equatable {
        case unknownTable(String)
        case unknownColumn(table: String, column: String)
    }

    /// The latest sequence written here.
    public func lastSeq() throws -> Int64 {
        try writer.read { db in try Int64.fetchOne(db, sql: "SELECT MAX(seq) FROM sync_log") ?? 0 }
    }

    /// Rows written here after `seq`, each once in its latest state, oldest first.
    public func changes(after seq: Int64, limit: Int = 500) throws -> SyncBatch {
        try writer.read { db in
            let entries = try Row.fetchAll(
                db,
                sql: """
                    SELECT seq, table_name, row_id, deleted FROM sync_log
                    WHERE seq IN (SELECT MAX(seq) FROM sync_log WHERE seq > ? GROUP BY table_name, row_id)
                    ORDER BY seq LIMIT ?
                    """, arguments: [seq, limit + 1])
            var rows: [SyncRow] = []
            var last = seq
            for entry in entries.prefix(limit) {
                let table: String = entry["table_name"]
                let id: String = entry["row_id"]
                last = entry["seq"]
                guard Schema.tables.contains(table) else { continue }
                let deleted: Bool = entry["deleted"]
                rows.append(deleted ? SyncRow(table: table, id: id, columns: nil) : try Self.row(db, table: table, id: id))
            }
            return SyncBatch(rows: rows, lastSeq: last, more: entries.count > limit)
        }
    }

    /// Writes rows from `peer` without logging them for sync, and remembers how far that peer got.
    public func apply(_ batch: SyncBatch, from peer: String) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE sync_state SET applying = 1")
            try Self.write(batch.rows, db)
            try db.execute(sql: "UPDATE sync_state SET applying = 0")
            try db.execute(
                sql: """
                    INSERT INTO sync_peer (peer_id, received_seq, acknowledged_seq) VALUES (?, ?, 0)
                    ON CONFLICT(peer_id) DO UPDATE SET received_seq = MAX(received_seq, excluded.received_seq)
                    """, arguments: [peer, batch.lastSeq])
        }
    }

    /// A row as it is now, or as deleted when it doesn't exist.
    static func row(_ db: Database, table: String, id: String) throws -> SyncRow {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM \(table) WHERE id = ?", arguments: [id]) else {
            return SyncRow(table: table, id: id, columns: nil)
        }
        return SyncRow(table: table, id: id, columns: row.columnNames.map { SyncColumn($0, SyncValue(row[$0] as DatabaseValue)) })
    }

    /// Upserts or deletes rows. Only known tables and columns.
    static func write(_ rows: [SyncRow], _ db: Database) throws {
        for row in rows {
            guard Schema.tables.contains(row.table) else { throw SyncError.unknownTable(row.table) }
            guard let columns = row.columns else {
                try db.execute(sql: "DELETE FROM \(row.table) WHERE id = ?", arguments: [row.id])
                continue
            }
            let known = Set(try db.columns(in: row.table).map(\.name))
            if let unknown = columns.first(where: { !known.contains($0.name) }) {
                throw SyncError.unknownColumn(table: row.table, column: unknown.name)
            }
            let names = columns.map(\.name)
            let marks = Array(repeating: "?", count: names.count).joined(separator: ", ")
            let updates = names.filter { $0 != "id" }.map { "\($0) = excluded.\($0)" }.joined(separator: ", ")
            try db.execute(
                sql:
                    "INSERT INTO \(row.table) (\(names.joined(separator: ", "))) VALUES (\(marks)) ON CONFLICT(id) DO UPDATE SET \(updates)",
                arguments: StatementArguments(columns.map(\.value.databaseValue)))
        }
    }

    /// The last sequence of ours that `peer` confirmed it has: send it rows after this.
    public func acknowledgedSeq(by peer: String) throws -> Int64 {
        try writer.read { db in
            try Int64.fetchOne(db, sql: "SELECT acknowledged_seq FROM sync_peer WHERE peer_id = ?", arguments: [peer]) ?? 0
        }
    }

    public func setAcknowledged(_ seq: Int64, by peer: String) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO sync_peer (peer_id, received_seq, acknowledged_seq) VALUES (?, 0, ?)
                    ON CONFLICT(peer_id) DO UPDATE SET acknowledged_seq = MAX(acknowledged_seq, excluded.acknowledged_seq)
                    """, arguments: [peer, seq])
        }
    }

    /// The last sequence received from `peer`: ask it for changes after this.
    public func receivedSeq(from peer: String) throws -> Int64 {
        try writer.read { db in
            try Int64.fetchOne(db, sql: "SELECT received_seq FROM sync_peer WHERE peer_id = ?", arguments: [peer]) ?? 0
        }
    }
}
