import AZModel

/// The arithmetic behind the Sunday review, done in code so Div only has to judge.
public enum WeeklyMath {
    /// Energy in a kilogram of body-weight change.
    public static let kcalPerKg = 7700.0
    /// Fewer complete days than this and maintenance is unknown and calories don't move.
    public static let minCompleteDays = 10
    /// Weekly change, as % of body weight, below which the scale counts as flat.
    public static let scaleFlatPct = 0.15
    public static let waistFlatCm = 0.5
    public static let strengthFlatPct = 1.5
    /// Losing faster than this (% of body weight a week) skips the 14-day wait and blocks further cuts.
    public static let tooFastPct = -1.0
    public static let daysBetweenCalorieChanges = 14

    public static func derive(_ s: WeeklySnapshot) -> WeeklyDerived {
        let days = Double(s.intake.windowDays)
        let trendChange = s.weight.trendKgNow - s.weight.trendKgWindowStart
        let weeklyKg = trendChange / days * 7
        let weeklyPct = weeklyKg / s.weight.trendKgNow * 100

        let enough = s.intake.completeDays >= minCompleteDays
        let maintenance = enough ? s.intake.avgKcalCompleteDays - trendChange * kcalPerKg / days : nil

        let liftChanges = s.lifts.map {
            WeeklyDerived.LiftChange(name: $0.name, changePct: rounded(($0.e1rmNow - $0.e1rmWindowStart) / $0.e1rmWindowStart * 100))
        }
        let avgLift = liftChanges.isEmpty ? 0 : liftChanges.map(\.changePct).reduce(0, +) / Double(liftChanges.count)

        let waistChange = s.waistCm.map { $0.now - $0.windowStart }
        let daily = s.weight.dailyThisWeek
        let jump = daily.count >= 2 ? daily[daily.count - 1] - daily[0] : 0
        let tooFast = weeklyPct < tooFastPct

        return WeeklyDerived(
            weeklyRatePct: rounded(weeklyPct, 2),
            weeklyRateKg: rounded(weeklyKg, 2),
            impliedMaintenanceKcal: maintenance.map { Int(($0 / 10).rounded()) * 10 },
            enoughCompleteDays: enough,
            waistChangeCm: waistChange.map { rounded($0) },
            liftChangesPct: liftChanges,
            strengthDirection: direction(avgLift, flat: strengthFlatPct),
            scaleDirection: direction(weeklyPct, flat: scaleFlatPct),
            waistDirection: waistChange.map { direction($0, flat: waistFlatCm) } ?? .unknown,
            weightJumpKgThisWeek: rounded(jump),
            losingTooFast: tooFast,
            calorieChangeAllowedByTime: s.daysSinceLastCalorieChange >= daysBetweenCalorieChanges || tooFast,
            proteinTargetG: Int((s.targets.proteinGPerKg * s.weight.trendKgNow).rounded()),
            volumeStatus: s.volume.map {
                let status: WeeklyDerived.VolumeStatus.Status =
                    $0.setsThisWeek < $0.mev ? .belowMev : $0.setsThisWeek > $0.mrv ? .aboveMrv : .inRange
                return .init(muscle: $0.muscle, sets: $0.setsThisWeek, status: status)
            }
        )
    }

    /// Protein in g per kg of body weight that suits each goal.
    public static func proteinRange(for goal: Goal) -> ClosedRange<Double> {
        switch goal {
        case .cut: 2.0...2.2
        case .recomp: 1.8...2.2
        case .build: 1.6...2.0
        }
    }

    static func direction(_ value: Double, flat: Double) -> Direction {
        value > flat ? .up : value < -flat ? .down : .flat
    }
}
