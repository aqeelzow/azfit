// The Sunday review (Div/prompts/jobs/weekly-review.md). The phone or the bridge's own copy of the data builds a
// WeeklySnapshot, AZMath derives the numbers, Div reads both, and the bridge checks Div's changes.

public struct WeeklySnapshot: Codable, Sendable, Equatable {
    /// YYYY-MM-DD, the Sunday the review covers.
    public var weekEnding: String
    public var user: User
    public var targets: Targets
    public var weight: Weight
    public var intake: Intake
    public var waistCm: Waist?
    public var lifts: [Lift]
    public var volume: [MuscleVolume]
    /// Sleep, HRV and steps, once the phone reads them from Health. Without it Div never deloads for recovery.
    public var recovery: Recovery?
    public var waterEvents: [WaterEvent]
    public var recentChanges: [RecentChange]
    public var daysSinceLastCalorieChange: Int
    public var currentLoads: [CurrentLoad]
    /// What Div remembers about the person ("Right knee: no deep lunges").
    public var memories: [String]?

    public struct User: Codable, Sendable, Equatable {
        public var age: Int
        public var heightCm: Double
        public var goal: Goal
        /// Target change in body weight per week, as % of body weight. Negative for a cut.
        public var targetRatePctPerWeek: Double
        public var calorieFloorKcal: Int
        /// If true, protein is set by the person's doctor and Div never changes it.
        public var kidneyDisease: Bool

        public init(age: Int, heightCm: Double, goal: Goal, targetRatePctPerWeek: Double, calorieFloorKcal: Int, kidneyDisease: Bool) {
            self.age = age
            self.heightCm = heightCm
            self.goal = goal
            self.targetRatePctPerWeek = targetRatePctPerWeek
            self.calorieFloorKcal = calorieFloorKcal
            self.kidneyDisease = kidneyDisease
        }
    }

    public struct Targets: Codable, Sendable, Equatable {
        public var caloriesKcal: Int
        public var proteinGPerKg: Double

        public init(caloriesKcal: Int, proteinGPerKg: Double) {
            self.caloriesKcal = caloriesKcal
            self.proteinGPerKg = proteinGPerKg
        }
    }

    public struct Weight: Codable, Sendable, Equatable {
        /// Smoothed trend weight (each weigh-in counts about 10%).
        public var trendKgNow: Double
        public var trendKgWeekAgo: Double
        public var trendKgWindowStart: Double
        /// Raw weigh-ins for the last 7 days, oldest first.
        public var dailyThisWeek: [Double]

        public init(trendKgNow: Double, trendKgWeekAgo: Double, trendKgWindowStart: Double, dailyThisWeek: [Double]) {
            self.trendKgNow = trendKgNow
            self.trendKgWeekAgo = trendKgWeekAgo
            self.trendKgWindowStart = trendKgWindowStart
            self.dailyThisWeek = dailyThisWeek
        }
    }

    public struct Intake: Codable, Sendable, Equatable {
        /// 14 to 21.
        public var windowDays: Int
        public var completeDays: Int
        public var avgKcalCompleteDays: Double
        public var proteinHitDaysThisWeek: Int

        public init(windowDays: Int, completeDays: Int, avgKcalCompleteDays: Double, proteinHitDaysThisWeek: Int) {
            self.windowDays = windowDays
            self.completeDays = completeDays
            self.avgKcalCompleteDays = avgKcalCompleteDays
            self.proteinHitDaysThisWeek = proteinHitDaysThisWeek
        }
    }

    public struct Waist: Codable, Sendable, Equatable {
        public var now: Double
        public var windowStart: Double

        public init(now: Double, windowStart: Double) {
            self.now = now
            self.windowStart = windowStart
        }
    }

    public struct Lift: Codable, Sendable, Equatable {
        public var name: String
        public var e1rmNow: Double
        public var e1rmWindowStart: Double
        public var avgRir: Double

        public init(name: String, e1rmNow: Double, e1rmWindowStart: Double, avgRir: Double) {
            self.name = name
            self.e1rmNow = e1rmNow
            self.e1rmWindowStart = e1rmWindowStart
            self.avgRir = avgRir
        }
    }

    public struct MuscleVolume: Codable, Sendable, Equatable {
        public var muscle: String
        public var setsThisWeek: Int
        /// Minimum effective volume and maximum recoverable volume, in sets per week.
        public var mev: Int
        public var mrv: Int

        public init(muscle: String, setsThisWeek: Int, mev: Int, mrv: Int) {
            self.muscle = muscle
            self.setsThisWeek = setsThisWeek
            self.mev = mev
            self.mrv = mrv
        }
    }

    public struct Recovery: Codable, Sendable, Equatable {
        public var sleepAvgH: Double
        public var sleepBaselineH: Double
        public var hrvVsBaselinePct: Double
        public var stepsAvg: Double
        public var stepsBaseline: Double

        public init(sleepAvgH: Double, sleepBaselineH: Double, hrvVsBaselinePct: Double, stepsAvg: Double, stepsBaseline: Double) {
            self.sleepAvgH = sleepAvgH
            self.sleepBaselineH = sleepBaselineH
            self.hrvVsBaselinePct = hrvVsBaselinePct
            self.stepsAvg = stepsAvg
            self.stepsBaseline = stepsBaseline
        }
    }

    /// Something that moves water weight: a high-salt day, a new creatine dose, illness, travel.
    public struct WaterEvent: Codable, Sendable, Equatable {
        public var type: String
        public var started: String

        public init(type: String, started: String) {
            self.type = type
            self.started = started
        }
    }

    public struct RecentChange: Codable, Sendable, Equatable {
        public var date: String
        public var type: String
        public var detail: String
        public var reason: String

        public init(date: String, type: String, detail: String, reason: String) {
            self.date = date
            self.type = type
            self.detail = detail
            self.reason = reason
        }
    }

    public struct CurrentLoad: Codable, Sendable, Equatable {
        public var exercise: String
        public var loadKg: Double
        /// e.g. "6-10".
        public var repRange: String
        /// Sessions in a row where every set reached the top of the range.
        public var hitTopOfRangeSessions: Int

        public init(exercise: String, loadKg: Double, repRange: String, hitTopOfRangeSessions: Int) {
            self.exercise = exercise
            self.loadKg = loadKg
            self.repRange = repRange
            self.hitTopOfRangeSessions = hitTopOfRangeSessions
        }
    }

    public init(
        weekEnding: String, user: User, targets: Targets, weight: Weight, intake: Intake, waistCm: Waist? = nil, lifts: [Lift],
        volume: [MuscleVolume], recovery: Recovery? = nil, waterEvents: [WaterEvent], recentChanges: [RecentChange],
        daysSinceLastCalorieChange: Int, currentLoads: [CurrentLoad], memories: [String]? = nil
    ) {
        self.weekEnding = weekEnding
        self.user = user
        self.targets = targets
        self.weight = weight
        self.intake = intake
        self.waistCm = waistCm
        self.lifts = lifts
        self.volume = volume
        self.recovery = recovery
        self.waterEvents = waterEvents
        self.recentChanges = recentChanges
        self.daysSinceLastCalorieChange = daysSinceLastCalorieChange
        self.currentLoads = currentLoads
        self.memories = memories
    }
}

/// Numbers computed by AZMath from a WeeklySnapshot, so Div never does arithmetic (D-010).
public struct WeeklyDerived: Codable, Sendable, Equatable {
    public var weeklyRatePct: Double
    public var weeklyRateKg: Double
    /// Average intake on complete days minus the energy in the trend change. Nil with fewer than 10 complete days.
    public var impliedMaintenanceKcal: Int?
    public var enoughCompleteDays: Bool
    public var waistChangeCm: Double?
    public var liftChangesPct: [LiftChange]
    public var strengthDirection: Direction
    public var scaleDirection: Direction
    public var waistDirection: Direction
    /// Last raw weigh-in minus the first one this week.
    public var weightJumpKgThisWeek: Double
    /// Losing more than 1% of body weight a week.
    public var losingTooFast: Bool
    /// 14 days since the last calorie change, or losing too fast.
    public var calorieChangeAllowedByTime: Bool
    public var proteinTargetG: Int
    public var volumeStatus: [VolumeStatus]

    public struct LiftChange: Codable, Sendable, Equatable {
        public var name: String
        public var changePct: Double

        public init(name: String, changePct: Double) {
            self.name = name
            self.changePct = changePct
        }
    }

    public struct VolumeStatus: Codable, Sendable, Equatable {
        public enum Status: String, Codable, Sendable {
            case belowMev = "below_mev"
            case inRange = "in_range"
            case aboveMrv = "above_mrv"
        }

        public var muscle: String
        public var sets: Int
        public var status: Status

        public init(muscle: String, sets: Int, status: Status) {
            self.muscle = muscle
            self.sets = sets
            self.status = status
        }
    }

    public init(
        weeklyRatePct: Double, weeklyRateKg: Double, impliedMaintenanceKcal: Int?, enoughCompleteDays: Bool, waistChangeCm: Double?,
        liftChangesPct: [LiftChange], strengthDirection: Direction, scaleDirection: Direction, waistDirection: Direction,
        weightJumpKgThisWeek: Double, losingTooFast: Bool, calorieChangeAllowedByTime: Bool, proteinTargetG: Int,
        volumeStatus: [VolumeStatus]
    ) {
        self.weeklyRatePct = weeklyRatePct
        self.weeklyRateKg = weeklyRateKg
        self.impliedMaintenanceKcal = impliedMaintenanceKcal
        self.enoughCompleteDays = enoughCompleteDays
        self.waistChangeCm = waistChangeCm
        self.liftChangesPct = liftChangesPct
        self.strengthDirection = strengthDirection
        self.scaleDirection = scaleDirection
        self.waistDirection = waistDirection
        self.weightJumpKgThisWeek = weightJumpKgThisWeek
        self.losingTooFast = losingTooFast
        self.calorieChangeAllowedByTime = calorieChangeAllowedByTime
        self.proteinTargetG = proteinTargetG
        self.volumeStatus = volumeStatus
    }
}

/// What Div returns for the weekly review (Div/schemas/weekly-review.json).
public struct WeeklyReviewOutput: Codable, Sendable, Equatable {
    public enum CalorieReading: String, Codable, Sendable {
        case recomposition
        case surplusTooBig = "surplus_too_big"
        case leanGain = "lean_gain"
        case deficitTooSteep = "deficit_too_steep"
        case water
        case onTrack = "on_track"
        case offTrackWatching = "off_track_watching"
        case insufficientData = "insufficient_data"
    }

    public enum CalorieAction: String, Codable, Sendable {
        case hold
        case decrease
        case increase
    }

    public var summary: String
    public var calorieReading: CalorieReading
    public var calorieAction: CalorieAction
    public var calorieReasoning: String
    public var changes: [Proposal]
    /// Questions instead of guesses ("Did Thursday's dinner slip through?").
    public var questions: [String]

    public init(
        summary: String = "", calorieReading: CalorieReading = .onTrack, calorieAction: CalorieAction = .hold,
        calorieReasoning: String = "", changes: [Proposal] = [], questions: [String] = []
    ) {
        self.summary = summary
        self.calorieReading = calorieReading
        self.calorieAction = calorieAction
        self.calorieReasoning = calorieReasoning
        self.changes = changes
        self.questions = questions
    }
}
