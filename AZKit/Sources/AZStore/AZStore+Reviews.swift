import AZMath
import AZModel
import Foundation
import GRDB

// The inputs Div's reviews read, built from the database, and saving what they decide.

extension AZStore {
    /// The RIR the plan aims for, until it carries its own per exercise. A target, not a guess about any set.
    public static let targetRIR = 2.0

    /// A finished workout as the session review reads it: each exercise with its prescription, the sets as lifted,
    /// and its best e1RM from earlier workouts. Exercises are named as in the library. Nil if it has no sets.
    public func sessionReport(_ workoutID: UUID, library: Library = .standard) throws -> SessionReport? {
        try writer.read { db -> SessionReport? in
            let key = workoutID.uuidString.lowercased()
            guard let workout = try Workout.fetchOne(db, key: key) else { return nil }
            let sets = try LoggedSet.filter(Column("workout_id") == key).order(Column("position")).fetchAll(db)
            guard !sets.isEmpty else { return nil }
            let planned =
                try workout.plannedSessionID.map {
                    try PlannedExercise.filter(Column("session_id") == $0.uuidString.lowercased()).fetchAll(db)
                } ?? []
            let earlier = try Workout.filter(Column("day") < workout.day && Column("skipped") == false).order(Column("day"))
                .fetchAll(db)
            let earlierSets = try LoggedSet.filter(earlier.map { $0.id.uuidString.lowercased() }.contains(Column("workout_id")))
                .fetchAll(db)
            let order = earlier.map(\.id)

            var exerciseIDs: [String] = []
            for set in sets where !exerciseIDs.contains(set.exerciseID) { exerciseIDs.append(set.exerciseID) }

            let exercises = exerciseIDs.map { id -> SessionReport.Exercise in
                let done = sets.filter { $0.exerciseID == id }
                let plan = planned.first { $0.exerciseID == id }
                let heaviest = done.map(\.loadKg).max() ?? 0
                let prescription = SessionReport.Prescription(
                    sets: plan?.sets ?? done.count, repMin: plan?.repMin ?? done.map(\.reps).min() ?? 0,
                    repMax: plan?.repMax ?? done.map(\.reps).max() ?? 0, rir: Self.targetRIR, loadKg: plan?.loadKg ?? heaviest)
                let history = order.compactMap { workoutID -> Double? in
                    let theirs = earlierSets.filter { $0.workoutID == workoutID && $0.exerciseID == id }
                    return theirs.map { Strength.e1rm(loadKg: $0.loadKg, reps: $0.reps, rir: $0.rir) }.max()
                }
                return SessionReport.Exercise(
                    exercise: library.exercise(id)?.name ?? id, prescribed: prescription,
                    performed: done.map { .init(loadKg: $0.loadKg, reps: $0.reps, rir: $0.rir) },
                    e1rmHistory: Array(history.suffix(6)))
            }
            let memories = try Memory.order(Column("created_at")).fetchAll(db).map(\.text)
            return SessionReport(
                date: workout.day, sessionName: workout.name, exercises: exercises, memories: memories.isEmpty ? nil : memories)
        }
    }

    /// Finished workouts since `day` with sets but no review yet, oldest first.
    public func workoutsAwaitingReview(since day: String) throws -> [Workout] {
        try writer.read { db in
            try Workout.filter(
                Column("day") >= day && Column("ended_at") != nil && Column("skipped") == false && Column("div_note") == nil
            )
            .order(Column("day")).fetchAll(db)
            .filter { try LoggedSet.filter(Column("workout_id") == $0.id.uuidString.lowercased()).fetchCount(db) > 0 }
        }
    }

    /// The latest reviewed workout on `day`, for its note.
    public func reviewedWorkout(on day: String) throws -> Workout? {
        try writer.read { db in
            try Workout.filter(Column("day") == day && Column("div_note") != nil).order(Column("ended_at").desc).fetchOne(db)
        }
    }

    /// Saves a session review: the note on the workout, a starting load for exercises that had none (what was lifted),
    /// then next time's loads as Div changes, applied or waiting as the policy decided.
    public func saveSessionReview(
        _ workoutID: UUID, note: String, nextTime: [Checked<NextTime>], report: SessionReport, today: String,
        library: Library = .standard
    ) throws -> [DivChange] {
        try writer.write { db in
            let key = workoutID.uuidString.lowercased()
            guard var workout = try Workout.fetchOne(db, key: key) else { return }
            workout.divNote = note
            try workout.update(db)
            guard let sessionID = workout.plannedSessionID else { return }
            for var row in try PlannedExercise.filter(Column("session_id") == sessionID.uuidString.lowercased()).fetchAll(db)
            where row.loadKg == nil {
                let name = library.exercise(row.exerciseID)?.name ?? row.exerciseID
                guard let start = report.exercises.first(where: { $0.exercise == name })?.prescribed.loadKg, start > 0 else {
                    continue
                }
                row.loadKg = start
                try row.update(db)
            }
        }
        let changes = nextTime.compactMap { checked -> Checked<Proposal>? in
            let item = checked.item
            guard item.call != .repeat,
                let current = report.exercises.first(where: { $0.exercise.lowercased() == item.exercise.lowercased() })
            else { return nil }
            let proposal = Proposal(
                .setLoad(exercise: current.exercise, newLoadKg: item.nextLoadKg), reason: item.reason,
                evidence: ["\(item.call.rawValue) from \(current.prescribed.loadKg) kg"])
            return Checked(item: proposal, verdict: checked.verdict, notes: checked.notes)
        }
        return try record(changes, job: "session_review", today: today, library: library)
    }

    // MARK: Weekly review

    /// Days of data the weekly review reads, before the person has been here that long.
    public static let reviewWindowDays = 21
    /// The Sunday on or before `day`.
    public static func sunday(onOrBefore day: String) -> String {
        Day.adding(-((Day.weekday(day) ?? 7) % 7), to: day)
    }

    /// The week ending on `weekEnding` (a Sunday) as the weekly review reads it. Nil without a profile, a target or a
    /// weigh-in, since the numbers mean nothing without them.
    public func weeklySnapshot(weekEnding: String, library: Library = .standard) throws -> WeeklySnapshot? {
        guard let records = try records(), let target = records.target(on: weekEnding) else { return nil }
        let profile = records.profile
        let weighIns = records.weighIns.filter { $0.day <= weekEnding }.sorted { ($0.day, $0.at) < ($1.day, $1.at) }
        guard !weighIns.isEmpty else { return nil }

        let joined = Day.string(profile.createdAt)
        let daysHere =
            Calendar.current.dateComponents(
                [.day], from: Day.date(joined) ?? .now, to: Day.date(weekEnding) ?? .now
            ).day ?? 0
        let window = min(Self.reviewWindowDays, max(14, daysHere + 1))
        let windowStart = Day.adding(-(window - 1), to: weekEnding)
        let weekStart = Day.adding(-6, to: weekEnding)

        // Weight: one trend over every weigh-in, read at the end of the week, a week before, and the window start.
        let trend = WeightTrend.trend(weighIns.map(\.kg))
        func trendKg(onOrBefore day: String) -> Double {
            weighIns.lastIndex { $0.day <= day }.map { trend[$0] } ?? trend[0]
        }
        let weight = WeeklySnapshot.Weight(
            trendKgNow: trendKg(onOrBefore: weekEnding), trendKgWeekAgo: trendKg(onOrBefore: Day.adding(-7, to: weekEnding)),
            trendKgWindowStart: trendKg(onOrBefore: windowStart),
            dailyThisWeek: weighIns.filter { $0.day >= weekStart }.map(\.kg))

        // Intake over the window, on complete days only.
        let meals = records.meals.filter { !$0.removed && $0.day >= windowStart && $0.day <= weekEnding }
        let marked = Dictionary(records.foodDays.map { ($0.day, $0.complete) }, uniquingKeysWith: { _, last in last })
        let kcalByDay = Dictionary(grouping: meals, by: \.day).mapValues { $0.reduce(0) { $0 + $1.kcal } }
        // Only days the person marked "That's everything": a partly logged day would read as eating less.
        let complete = kcalByDay.filter { day, _ in marked[day] == .some(true) }
        let proteinTarget = target.proteinGPerKg * weight.trendKgNow
        let proteinByDay = Dictionary(grouping: meals.filter { $0.day >= weekStart }, by: \.day).mapValues {
            $0.reduce(0) { $0 + $1.proteinG }
        }
        let intake = WeeklySnapshot.Intake(
            windowDays: window, completeDays: complete.count,
            avgKcalCompleteDays: complete.isEmpty ? 0 : (complete.values.reduce(0, +) / Double(complete.count)).rounded(),
            proteinHitDaysThisWeek: proteinByDay.values.filter { $0 >= proteinTarget * 0.9 }.count)

        let waists = records.measurements.filter { $0.site == .waist && $0.day >= windowStart && $0.day <= weekEnding }
            .sorted { $0.day < $1.day }
        let waist = waists.count >= 2 ? WeeklySnapshot.Waist(now: waists.last!.cm, windowStart: waists.first!.cm) : nil

        // Lifts done this week with something to compare: best e1RM this week against the first session in the window.
        let workouts = records.workouts.filter { !$0.skipped && $0.day >= windowStart && $0.day <= weekEnding }
        let dayOf = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0.day) })
        let sets = records.sets.filter { dayOf[$0.workoutID] != nil }
        func e1rm(_ set: LoggedSet) -> Double { Strength.e1rm(loadKg: set.loadKg, reps: set.reps, rir: set.rir) }
        let lifts = Dictionary(grouping: sets, by: \.exerciseID).compactMap { id, sets -> WeeklySnapshot.Lift? in
            let thisWeek = sets.filter { (dayOf[$0.workoutID] ?? "") >= weekStart }
            guard let firstDay = sets.compactMap({ dayOf[$0.workoutID] }).min(), firstDay < weekStart, !thisWeek.isEmpty else {
                return nil
            }
            let first = sets.filter { dayOf[$0.workoutID] == firstDay }
            return WeeklySnapshot.Lift(
                name: library.exercise(id)?.name ?? id, e1rmNow: (thisWeek.map(e1rm).max() ?? 0).rounded(),
                e1rmWindowStart: (first.map(e1rm).max() ?? 0).rounded(),
                avgRir: Strength.averageRIR(thisWeek.map(\.rir)))
        }
        .sorted { $0.name < $1.name }

        let volume = try volume(today: weekEnding, library: library)
            .filter { $0.sets > 0 || $0.muscle.minSetsPerWeek > 0 }
            .map {
                WeeklySnapshot.MuscleVolume(
                    muscle: $0.muscle.name.components(separatedBy: " (")[0], setsThisWeek: Int($0.sets.rounded()),
                    mev: $0.muscle.minSetsPerWeek, mrv: $0.muscle.maxRecoverableSetsPerWeek)
            }

        let since = Day.date(Day.adding(-28, to: weekEnding)) ?? .distantPast
        let recent = records.changes.filter { ($0.status == .applied || $0.status == .approved) && $0.createdAt >= since }
            .sorted { $0.createdAt < $1.createdAt }
            .map { change in
                let summary = change.proposal.change.summary
                return WeeklySnapshot.RecentChange(
                    date: Day.string(change.createdAt), type: change.proposal.change.kind, detail: summary.title,
                    reason: change.proposal.reason)
            }
        let lastCalorieChange = Day.date(target.startDay) ?? .now
        let daysSinceCalories =
            Calendar.current.dateComponents([.day], from: lastCalorieChange, to: Day.date(weekEnding) ?? .now)
            .day ?? 0

        let loads = records.plannedExercises.compactMap { row -> WeeklySnapshot.CurrentLoad? in
            guard let load = row.loadKg else { return nil }
            return WeeklySnapshot.CurrentLoad(
                exercise: library.exercise(row.exerciseID)?.name ?? row.exerciseID, loadKg: load,
                repRange: row.repMin == row.repMax ? "\(row.repMin)" : "\(row.repMin)-\(row.repMax)",
                hitTopOfRangeSessions: row.hitTopOfRangeSessions)
        }

        let floor = Targets.calorieFloor(
            sex: profile.sex, weightKg: weight.trendKgNow, heightCm: profile.heightCm, age: profile.age(on: weekEnding))
        let memories = records.memories.sorted { $0.createdAt < $1.createdAt }.map(\.text)
        return WeeklySnapshot(
            weekEnding: weekEnding,
            user: .init(
                age: profile.age(on: weekEnding) ?? 0, heightCm: profile.heightCm ?? 0, goal: profile.goal,
                targetRatePctPerWeek: profile.targetRatePctPerWeek, calorieFloorKcal: floor, kidneyDisease: profile.kidneyDisease),
            targets: .init(caloriesKcal: target.kcal, proteinGPerKg: target.proteinGPerKg), weight: weight, intake: intake,
            waistCm: waist, lifts: lifts, volume: volume, recovery: nil, waterEvents: [], recentChanges: recent,
            daysSinceLastCalorieChange: daysSinceCalories, currentLoads: loads, memories: memories.isEmpty ? nil : memories)
    }

    public func weekReview(weekEnding: String) throws -> WeekReview? {
        try writer.read { db in try WeekReview.filter(Column("week_ending") == weekEnding).fetchOne(db) }
    }

    /// The latest weekly review, for the screens.
    public func latestWeekReview() throws -> WeekReview? {
        try writer.read { db in try WeekReview.order(Column("week_ending").desc).fetchOne(db) }
    }

    /// Saves a weekly review: its summary and questions, and its changes as the policy decided.
    public func saveWeeklyReview(
        weekEnding: String, output: WeeklyReviewOutput, checked: [Checked<Proposal>], today: String, library: Library = .standard
    ) throws -> [DivChange] {
        try save(
            WeekReview(
                weekEnding: weekEnding, summary: output.summary, calorieReasoning: output.calorieReasoning,
                questions: output.questions))
        return try record(checked, job: "weekly_review", today: today, library: library)
    }
}
