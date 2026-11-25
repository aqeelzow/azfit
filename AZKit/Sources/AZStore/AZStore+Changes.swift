import AZModel
import Foundation
import GRDB

/// Saving Div's changes, applying them to the plan, and Approve, Decline and Undo (D-008, D-009).
/// The policy (BridgeKit) has already decided each verdict; this only carries it out.
extension AZStore {
    public enum ChangeError: Error, Equatable {
        case notFound
        /// Not waiting for a tap, or past its 7 days for Undo.
        case notAllowed(String)
    }

    /// Saves what one Div job returned. Refused changes are dropped, applied ones change the plan now, proposed
    /// ones wait for Approve. Returns the saved changes.
    @discardableResult
    public func record(
        _ checked: [Checked<Proposal>], job: String, today: String, now: Date = .now, library: Library = .standard
    ) throws -> [DivChange] {
        try writer.write { db in
            var saved: [DivChange] = []
            for item in checked where item.verdict != .refuse {
                var change = DivChange(
                    createdAt: now, job: job, proposal: item.item, status: item.verdict == .apply ? .applied : .proposed,
                    notes: item.notes)
                if item.verdict == .apply {
                    do {
                        change.undo = try Self.encodeUndo(try Self.apply(item.item.change, changeID: change.id, today: today, db, library))
                        change.resolvedAt = now
                    } catch ChangeError.notAllowed(let why) {
                        // Couldn't be carried out here (an exercise the library doesn't have): the person decides.
                        change.status = .proposed
                        change.notes.append(why)
                    }
                }
                try change.insert(db)
                saved.append(change)
            }
            return saved
        }
    }

    public func divChange(_ id: UUID) throws -> DivChange? {
        try writer.read { db in try DivChange.fetchOne(db, key: id.uuidString.lowercased()) }
    }

    /// The person tapped Approve.
    public func approve(_ id: UUID, today: String, now: Date = .now, library: Library = .standard) throws {
        try writer.write { db in
            var change = try Self.change(id, db)
            guard change.status == .proposed else { throw ChangeError.notAllowed("It isn't waiting for you.") }
            change.undo = try Self.encodeUndo(try Self.apply(change.proposal.change, changeID: id, today: today, db, library))
            change.status = .approved
            change.resolvedAt = now
            try change.update(db)
        }
    }

    /// The person said no to a suggestion.
    public func decline(_ id: UUID, now: Date = .now) throws {
        try writer.write { db in
            var change = try Self.change(id, db)
            guard change.status == .proposed else { throw ChangeError.notAllowed("It isn't waiting for you.") }
            change.status = .declined
            change.resolvedAt = now
            try change.update(db)
        }
    }

    /// Puts the plan back the way it was before the change. Within 7 days.
    public func undo(_ id: UUID, now: Date = .now) throws {
        try writer.write { db in
            var change = try Self.change(id, db)
            guard change.canUndo(at: now) else { throw ChangeError.notAllowed("Changes can be undone for 7 days.") }
            if let undo = change.undo {
                try Self.write(try JSONDecoder().decode([SyncRow].self, from: Data(undo.utf8)), db)
            }
            change.status = .undone
            change.resolvedAt = now
            try change.update(db)
        }
    }

    /// Brings back exercises whose swap has run its weeks ("the original comes back on its own").
    public func endSwaps(today: String) throws {
        try writer.write { db in
            for var row in try PlannedExercise.filter(Column("swap_ends_day") != nil && Column("swap_ends_day") <= today).fetchAll(db) {
                guard let original = row.swappedFromID else { continue }
                row.exerciseID = original
                row.swappedFromID = nil
                row.swapEndsDay = nil
                row.loadKg = nil
                row.hitTopOfRangeSessions = 0
                try row.update(db)
            }
        }
    }

    // MARK: Applying

    static func change(_ id: UUID, _ db: Database) throws -> DivChange {
        guard let change = try DivChange.fetchOne(db, key: id.uuidString.lowercased()) else { throw ChangeError.notFound }
        return change
    }

    static func encodeUndo(_ rows: [SyncRow]) throws -> String? {
        rows.isEmpty ? nil : String(decoding: try JSONEncoder().encode(rows), as: UTF8.self)
    }

    /// Carries out one change and returns the rows as they were before it, for Undo.
    static func apply(_ change: PlanChange, changeID: UUID, today: String, _ db: Database, _ library: Library) throws -> [SyncRow] {
        func exerciseID(_ name: String) -> String { library.exercise(named: name)?.id ?? name.lowercased() }
        func before<R: StoredRecord & Identifiable>(_ records: [R]) throws -> [SyncRow] where R.ID == UUID {
            try records.map { try row(db, table: R.databaseTableName, id: $0.id.uuidString.lowercased()) }
        }

        switch change {
        case .setLoad(let exercise, let newLoadKg):
            let rows = try PlannedExercise.filter(Column("exercise_id") == exerciseID(exercise)).fetchAll(db)
            let undo = try before(rows)
            for var row in rows {
                row.loadKg = newLoadKg
                row.hitTopOfRangeSessions = 0
                try row.update(db)
            }
            return undo

        case .swapExercise(let from, let to, let weeks):
            guard let replacement = library.exercise(named: to) else {
                throw ChangeError.notAllowed("\(to) isn't in the exercise library yet.")
            }
            let rows = try PlannedExercise.filter(Column("exercise_id") == exerciseID(from)).fetchAll(db)
            let undo = try before(rows)
            for var row in rows {
                row.swappedFromID = row.swappedFromID ?? row.exerciseID
                row.exerciseID = replacement.id
                row.swapEndsDay = weeks > 0 ? Day.adding(7 * weeks, to: today) : nil
                row.loadKg = nil
                row.hitTopOfRangeSessions = 0
                try row.update(db)
            }
            return undo

        case .moveSession(let session, let toDay, let thisWeekOnly):
            guard let weekday = PlannedSession.weekdayNames.firstIndex(where: { $0.lowercased() == toDay.lowercased() }) else {
                throw ChangeError.notAllowed("\(toDay) isn't a day of the week.")
            }
            let rows = try PlannedSession.fetchAll(db).filter { $0.name.lowercased() == session.lowercased() }
            let undo = try before(rows)
            for var row in rows {
                if thisWeekOnly {
                    row.movedToWeekday = weekday + 1
                    row.movedUntilDay = Day.adding(7 - (Day.weekday(today) ?? 7), to: today)  // this Sunday
                } else {
                    row.weekday = weekday + 1
                    row.movedToWeekday = nil
                    row.movedUntilDay = nil
                }
                try row.update(db)
            }
            return undo

        case .setCalorieTarget(let kcal):
            return try setTarget(today: today, changeID: changeID, db) { $0.kcal = kcal }

        case .setProteinTarget(let gramsPerKg):
            return try setTarget(today: today, changeID: changeID, db) { $0.proteinGPerKg = gramsPerKg }

        case .changeVolume, .scheduleDeload:
            // TODO: add the sets to the plan, and a deload week, once the plan has per-muscle volume. For now the
            // change is recorded and Div's next review reads it.
            return []
        }
    }

    /// A new target from today, starting from the current one. Today's own target is changed in place.
    static func setTarget(today: String, changeID: UUID, _ db: Database, edit: (inout NutritionTarget) -> Void) throws -> [SyncRow] {
        let current = try NutritionTarget.filter(Column("start_day") <= today).order(Column("start_day").desc).fetchOne(db)
        var target =
            current.map {
                $0.startDay == today ? $0 : NutritionTarget(startDay: today, kcal: $0.kcal, proteinGPerKg: $0.proteinGPerKg, source: .div)
            }
            ?? NutritionTarget(startDay: today, kcal: 0, proteinGPerKg: 0, source: .div)
        let undo = [try row(db, table: NutritionTarget.databaseTableName, id: target.id.uuidString.lowercased())]
        edit(&target)
        target.source = .div
        target.divChangeID = changeID
        try target.save(db)
        return undo
    }
}
