import Foundation

// What the app records (brief, Pillars 1 to 3). One struct per database table (AZStore). Every record has a UUID
// `id` (D-019) so the phone and the bridge can sync rows without clashing, and days are local calendar days as
// "YYYY-MM-DD", the same strings Div reads. Weights are kilograms and lengths centimetres; `UnitSystem` converts.
//
// One database holds one person (D-024): the bridge keeps a separate file per person, so no record says whose it is.
// Never delete what the person logged (CLAUDE.md): a skipped workout is a gap and an undone change is a status.

public enum Sex: String, Codable, Sendable, CaseIterable {
    case female
    case male
}

/// The person. One row.
public struct Profile: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String?
    /// For the calorie floor (BMR) and protein. Nil until onboarding asks.
    public var sex: Sex?
    public var birthYear: Int?
    public var heightCm: Double?
    public var goal: Goal
    public var trainingDays: Int
    public var units: UnitSystem
    /// Protein is then set by their doctor and Div never changes it.
    public var kidneyDisease: Bool
    /// Weigh-ins are compared at the same cycle phase.
    public var tracksCycle: Bool
    /// The weekly weight change aimed for, in % of body weight: negative to lose.
    public var targetRatePctPerWeek: Double
    public var autonomy: Autonomy
    public var createdAt: Date

    public init(
        id: UUID = UUID(), name: String? = nil, sex: Sex? = nil, birthYear: Int? = nil, heightCm: Double? = nil, goal: Goal,
        trainingDays: Int, units: UnitSystem = .canadian, kidneyDisease: Bool = false, tracksCycle: Bool = false,
        targetRatePctPerWeek: Double? = nil, autonomy: Autonomy = .standard, createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.sex = sex
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.goal = goal
        self.trainingDays = trainingDays
        self.units = units
        self.kidneyDisease = kidneyDisease
        self.tracksCycle = tracksCycle
        self.targetRatePctPerWeek = targetRatePctPerWeek ?? goal.defaultRatePctPerWeek
        self.autonomy = autonomy
        self.createdAt = createdAt
    }

    public func age(on day: String) -> Int? {
        guard let birthYear, let year = Int(day.prefix(4)) else { return nil }
        return year - birthYear
    }
}

extension Goal {
    /// The brief's default pace: about 0.5% a week down on a cut, a slow gain when building.
    public var defaultRatePctPerWeek: Double {
        switch self {
        case .cut: -0.5
        case .recomp: 0
        case .build: 0.25
        }
    }
}

/// The daily calorie and protein targets from `startDay` on. The latest row is the current one; older rows are
/// the history the Progress chart and "Why 2,350?" read.
public struct NutritionTarget: Codable, Sendable, Equatable, Identifiable {
    public enum Source: String, Codable, Sendable {
        case onboarding
        case div
        case person
    }

    public var id: UUID
    public var startDay: String
    public var kcal: Int
    public var proteinGPerKg: Double
    public var source: Source
    /// The Div change that set it, for its reason and its undo.
    public var divChangeID: UUID?
    /// Fat the person chose, in grams a day. Nil: a quarter of the calories (`Targets.macroGrams`).
    public var fatG: Int?
    /// Water the person chose, in ml a day. Nil: from body weight (`Targets.waterMl`).
    public var waterMl: Int?

    public init(
        id: UUID = UUID(), startDay: String, kcal: Int, proteinGPerKg: Double, source: Source, divChangeID: UUID? = nil,
        fatG: Int? = nil, waterMl: Int? = nil
    ) {
        self.id = id
        self.startDay = startDay
        self.kcal = kcal
        self.proteinGPerKg = proteinGPerKg
        self.source = source
        self.divChangeID = divChangeID
        self.fatG = fatG
        self.waterMl = waterMl
    }
}

// MARK: - Training

/// A session in the weekly plan ("Push" on Monday).
public struct PlannedSession: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    /// 1 is Monday, 7 is Sunday.
    public var weekday: Int
    public var position: Int
    /// Moved for one week only: the weekday it's on instead, until the end of `movedUntilDay`.
    public var movedToWeekday: Int?
    public var movedUntilDay: String?

    public init(
        id: UUID = UUID(), name: String, weekday: Int, position: Int = 0, movedToWeekday: Int? = nil, movedUntilDay: String? = nil
    ) {
        self.id = id
        self.name = name
        self.weekday = weekday
        self.position = position
        self.movedToWeekday = movedToWeekday
        self.movedUntilDay = movedUntilDay
    }

    /// The weekday it happens on in the week of `day`. A move lasts only the week ending `movedUntilDay`.
    public func weekday(on day: String) -> Int {
        if let movedToWeekday, let movedUntilDay, day <= movedUntilDay, day > Day.adding(-7, to: movedUntilDay) {
            return movedToWeekday
        }
        return weekday
    }

    public static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    public var weekdayName: String { Self.weekdayNames[(weekday - 1 + 7) % 7] }
}

/// An exercise in a planned session, with its prescription.
public struct PlannedExercise: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var sessionID: UUID
    /// A `Library` exercise ID.
    public var exerciseID: String
    public var position: Int
    public var sets: Int
    public var repMin: Int
    public var repMax: Int
    /// Nil until the first workout sets it.
    public var loadKg: Double?
    /// Sessions in a row that every set reached `repMax`: what makes a load increase routine.
    public var hitTopOfRangeSessions: Int
    /// When Div swapped this in: what it replaced, and the day the original comes back (nil keeps the swap).
    public var swappedFromID: String?
    public var swapEndsDay: String?

    public init(
        id: UUID = UUID(), sessionID: UUID, exerciseID: String, position: Int, sets: Int, repMin: Int, repMax: Int,
        loadKg: Double? = nil, hitTopOfRangeSessions: Int = 0, swappedFromID: String? = nil, swapEndsDay: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.position = position
        self.sets = sets
        self.repMin = repMin
        self.repMax = repMax
        self.loadKg = loadKg
        self.hitTopOfRangeSessions = hitTopOfRangeSessions
        self.swappedFromID = swappedFromID
        self.swapEndsDay = swapEndsDay
    }
}

/// A workout that happened, or a planned one that was skipped (a gap, never a deletion).
public struct Workout: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var plannedSessionID: UUID?
    public var name: String
    public var day: String
    public var startedAt: Date
    public var endedAt: Date?
    public var skipped: Bool
    /// Div's note after the session review, once it has run.
    public var divNote: String?

    public init(
        id: UUID = UUID(), plannedSessionID: UUID? = nil, name: String, day: String, startedAt: Date = .now,
        endedAt: Date? = nil, skipped: Bool = false, divNote: String? = nil
    ) {
        self.id = id
        self.plannedSessionID = plannedSessionID
        self.name = name
        self.day = day
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.skipped = skipped
        self.divNote = divNote
    }
}

/// One set as lifted.
public struct LoggedSet: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var workoutID: UUID
    public var exerciseID: String
    public var position: Int
    public var loadKg: Double
    public var reps: Int
    /// Reps in reserve: the most important input in the app (brief). Nil if not given.
    public var rir: Double?
    public var at: Date

    public init(
        id: UUID = UUID(), workoutID: UUID, exerciseID: String, position: Int, loadKg: Double, reps: Int, rir: Double?,
        at: Date = .now
    ) {
        self.id = id
        self.workoutID = workoutID
        self.exerciseID = exerciseID
        self.position = position
        self.loadKg = loadKg
        self.reps = reps
        self.rir = rir
        self.at = at
    }
}

// MARK: - Food

public struct Meal: Codable, Sendable, Equatable, Identifiable {
    public enum Source: String, Codable, Sendable {
        case photo
        case barcode
        case typed
        case favorite
    }

    public var id: UUID
    public var day: String
    public var at: Date
    public var name: String
    public var kcal: Double
    /// The estimate's range, when it came from a photo.
    public var kcalLow: Double?
    public var kcalHigh: Double?
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var source: Source
    public var barcode: String?
    /// Kept for one-tap logging: the same meal logged the same way each time (brief, Pillar 2).
    public var isFavorite: Bool
    /// The person removed it. Kept, never deleted, and left out of every total.
    public var removed: Bool
    /// Breakfast, lunch, dinner or snacks. Nil on meals logged before meals had one (`mealSlot` uses the time).
    public var slot: Slot?
    /// Micronutrients from the food's label, keyed by `Micronutrient.rawValue`. Nil when unknown (typed, photo).
    public var micros: [String: Double]?

    public init(
        id: UUID = UUID(), day: String, at: Date = .now, name: String, kcal: Double, kcalLow: Double? = nil,
        kcalHigh: Double? = nil, proteinG: Double, carbsG: Double, fatG: Double, source: Source, barcode: String? = nil,
        isFavorite: Bool = false, removed: Bool = false, slot: Slot? = nil,
        micros: [String: Double]? = nil
    ) {
        self.id = id
        self.day = day
        self.at = at
        self.name = name
        self.kcal = kcal
        self.kcalLow = kcalLow
        self.kcalHigh = kcalHigh
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.source = source
        self.barcode = barcode
        self.isFavorite = isFavorite
        self.removed = removed
        self.slot = slot
        self.micros = micros
    }
}

/// Whether a day's food log is the whole day. Only complete days go into the maintenance math (brief).
/// The ID is the day itself, so each day has one row.
public struct FoodDay: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// Nil until the person says ("Done for today", or the next morning's question).
    public var complete: Bool?

    public init(day: String, complete: Bool?) {
        id = day
        self.complete = complete
    }

    public var day: String { id }
}

// MARK: - Body

extension Meal {
    /// "Breakfast", "Lunch", "Dinner" or "Snack", from the hour it was eaten.
    public static func mealTime(at date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 4..<11: "Breakfast"
        case 11..<15: "Lunch"
        case 17..<22: "Dinner"
        default: "Snack"
        }
    }

    /// The same food logged again now, as a new row: one-tap repeat logging. The estimate's range comes along; the
    /// barcode, favorite flag and removal don't.
    public func again(day: String, at: Date = .now, slot: Slot? = nil) -> Meal {
        Meal(
            day: day, at: at, name: name, kcal: kcal, kcalLow: kcalLow, kcalHigh: kcalHigh, proteinG: proteinG, carbsG: carbsG,
            fatG: fatG, source: .favorite, slot: slot ?? .at(at), micros: micros)
    }
}

public struct WeighIn: Codable, Sendable, Equatable, Identifiable {
    public enum Source: String, Codable, Sendable {
        case manual
        case health
    }

    public var id: UUID
    public var day: String
    public var at: Date
    public var kg: Double
    public var source: Source

    public init(id: UUID = UUID(), day: String, at: Date = .now, kg: Double, source: Source = .manual) {
        self.id = id
        self.day = day
        self.at = at
        self.kg = kg
        self.source = source
    }
}

/// A tape measurement, or one read from a scan.
public struct BodyMeasurement: Codable, Sendable, Equatable, Identifiable {
    public enum Site: String, Codable, Sendable, CaseIterable {
        case waist, chest, hips, neck, armLeft, armRight, thighLeft, thighRight
    }

    public enum Source: String, Codable, Sendable {
        case tape
        case scan
    }

    public var id: UUID
    public var day: String
    public var site: Site
    public var cm: Double
    public var source: Source

    public init(id: UUID = UUID(), day: String, site: Site, cm: Double, source: Source = .tape) {
        self.id = id
        self.day = day
        self.site = site
        self.cm = cm
        self.source = source
    }
}

// MARK: - Div

/// One change Div made or suggested, with the bridge's verdict: what "Div's log" lists and what Undo flips.
public struct DivChange: Codable, Sendable, Equatable, Identifiable {
    public enum Status: String, Codable, Sendable {
        /// Applied on its own; undoable for 7 days.
        case applied
        /// Waiting for the person's tap.
        case proposed
        /// The person approved it.
        case approved
        /// The person said no.
        case declined
        case undone
    }

    public var id: UUID
    public var createdAt: Date
    /// The job that made it: "weekly-review", "session-review", "chat".
    public var job: String
    public var proposal: Proposal
    public var status: Status
    /// The policy's notes (why it asked).
    public var notes: [String]
    public var resolvedAt: Date?
    /// What Undo writes back: the rows as they were before the change (stored by AZStore).
    public var undo: String?

    public init(
        id: UUID = UUID(), createdAt: Date = .now, job: String, proposal: Proposal, status: Status, notes: [String] = [],
        resolvedAt: Date? = nil, undo: String? = nil
    ) {
        self.undo = undo
        self.id = id
        self.createdAt = createdAt
        self.job = job
        self.proposal = proposal
        self.status = status
        self.notes = notes
        self.resolvedAt = resolvedAt
    }

    /// Applied changes can be undone for 7 days.
    public func canUndo(at now: Date) -> Bool {
        (status == .applied || status == .approved) && now.timeIntervalSince(resolvedAt ?? createdAt) < 7 * 86_400
    }
}

/// Div's Sunday review of a week: what it read and its questions. Its changes are `DivChange`s with job
/// "weekly_review".
public struct WeekReview: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// The Sunday the review covers.
    public var weekEnding: String
    public var summary: String
    public var calorieReasoning: String
    public var questions: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(), weekEnding: String, summary: String, calorieReasoning: String = "", questions: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekEnding = weekEnding
        self.summary = summary
        self.calorieReasoning = calorieReasoning
        self.questions = questions
        self.createdAt = createdAt
    }
}

/// Something Div remembers about the person ("Left shoulder tight overhead").
public struct Memory: Codable, Sendable, Equatable, Identifiable {
    public enum Source: String, Codable, Sendable {
        case onboarding
        case chat
        case learned
    }

    public var id: UUID
    public var text: String
    public var source: Source
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, source: Source, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.source = source
        self.createdAt = createdAt
    }
}

// MARK: - Days

/// Local calendar days as "YYYY-MM-DD", the format Div and the database use.
public enum Day {
    public static func string(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func date(_ day: String, calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public static func adding(_ days: Int, to day: String, calendar: Calendar = .current) -> String {
        guard let date = date(day, calendar: calendar), let moved = calendar.date(byAdding: .day, value: days, to: date) else {
            return day
        }
        return string(moved, calendar: calendar)
    }

    /// 1 is Monday, 7 is Sunday.
    public static func weekday(_ day: String, calendar: Calendar = .current) -> Int? {
        guard let date = date(day, calendar: calendar) else { return nil }
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
}
