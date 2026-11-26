import AZModel
import AZStore
import SwiftUI

/// The scale's trend change each week as rounded bars against a dashed goal line (its number is in the section
/// note, `note(_:weightKg:units:)`), for the calorie target and
/// Progress. Bars grow toward the goal (down on a cut, up on a build); a week that went the other way is a short
/// faint bar with its signed number, and a week with no weigh-in is a dash. Weeks where Div changed the target carry
/// its mark.
struct WeeklyChangeChart: View {
    let weeks: [WeekChange]
    let profile: Profile?
    /// Trend weight now, for turning the goal rate (% a week) into kg.
    let weightKg: Double?
    let units: UnitSystem

    private let height: CGFloat = 112
    private let gap: CGFloat = 14

    /// "Weekly loss", "Weekly gain" or "Weekly change", with the unit for the section note.
    static func title(_ profile: Profile?) -> String {
        guard let rate = profile?.targetRatePctPerWeek else { return "Weekly change" }
        return rate < 0 ? "Weekly loss" : rate > 0 ? "Weekly gain" : "Weekly change"
    }

    static func unit(_ units: UnitSystem) -> String { units.bodyWeight == .kg ? "kg" : "lb" }

    /// The section note: "Goal 0.9 lb", or the unit alone when holding steady.
    static func note(_ profile: Profile?, weightKg: Double?, units: UnitSystem) -> String {
        guard let goal = goalKg(profile, weightKg: weightKg) else { return unit(units) }
        let number = units.bodyWeight == .kg ? goal : goal * UnitSystem.poundsPerKg
        return "Goal \(String(format: "%.1f", number)) \(unit(units))"
    }

    /// The planned weekly change in kg. Nil when holding steady or without a weight.
    static func goalKg(_ profile: Profile?, weightKg: Double?) -> Double? {
        guard let rate = profile?.targetRatePctPerWeek, rate != 0, let weightKg else { return nil }
        return abs(rate) / 100 * weightKg
    }

    /// -1 when the goal is to lose (or hold), +1 to gain.
    private var towardGoal: Double { (profile?.targetRatePctPerWeek ?? -1) > 0 ? 1 : -1 }

    var body: some View {
        let goal = Self.goalKg(profile, weightKg: weightKg)
        let progress = weeks.map { $0.kg.map { $0 * towardGoal } }
        let top = max(progress.compactMap { $0 }.max() ?? 0, goal ?? 0, 0.1)
        let scale = (height - 24) / top
        VStack(spacing: 8) {
            GeometryReader { geo in
                let count = CGFloat(max(weeks.count, 1))
                let barWidth = (geo.size.width - (count - 1) * gap) / count
                ZStack(alignment: .bottomLeading) {
                    ForEach(weeks.indices, id: \.self) { i in
                        bar(progress[i], goal: goal, scale: scale)
                            .frame(width: barWidth)
                            .offset(x: CGFloat(i) * (barWidth + gap))
                    }
                    if let goal {
                        DashedLine()
                            .stroke(AZColor.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(height: 1)
                            .offset(y: -goal * scale)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            }
            .frame(height: height)

            HStack(spacing: gap) {
                ForEach(weeks, id: \.weekStart) { week in
                    HStack(spacing: 3) {
                        if week.divChangedTarget { DivMark(size: 13) }
                        Text(Day.date(week.weekStart)?.formatted(.dateTime.month(.abbreviated).day()) ?? week.weekStart)
                            .font(.az(12, .semibold)).foregroundStyle(AZColor.faint).lineLimit(1).fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .monospacedDigit()
        .accessibilityElement()
        .accessibilityLabel(summary(progress, goal: goal))
    }

    @ViewBuilder
    private func bar(_ progress: Double?, goal: Double?, scale: CGFloat) -> some View {
        VStack(spacing: 4) {
            if let progress {
                let over = goal.map { progress > $0 } ?? false
                if over {
                    Text(value(progress)).font(.az(13, .bold))
                } else if progress <= 0 {
                    // The other way from the goal: its real sign, "+0.4" on a cut.
                    let actual = progress * towardGoal
                    Text(value(actual) == "0.0" ? "0" : "\(actual > 0 ? "+" : "-")\(value(actual))")
                        .font(.az(13, .bold)).foregroundStyle(AZColor.muted)
                }
                RoundedRectangle(cornerRadius: progress > 0 ? 8 : 3, style: .continuous)
                    .fill(progress <= 0 ? AZColor.hairline : over ? AZColor.accent : AZColor.accentSoft)
                    .frame(height: max(progress * scale, 6))
            } else {
                Text("-").font(.az(13, .bold)).foregroundStyle(AZColor.faint)
            }
        }
    }

    /// One week's number in the person's units, unsigned.
    private func value(_ kg: Double) -> String {
        let number = units.bodyWeight == .kg ? kg : kg * UnitSystem.poundsPerKg
        return String(format: "%.1f", abs(number))
    }

    private func summary(_ progress: [Double?], goal: Double?) -> String {
        let listed = progress.map { $0.map(value) ?? "no weigh-in" }.joined(separator: ", ")
        return "\(Self.title(profile)) in \(Self.unit(units)): \(listed)" + (goal.map { ", against a goal of \(value($0))" } ?? "")
    }

    private nonisolated struct DashedLine: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}
