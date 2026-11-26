import AZModel
import AZStore
import SwiftUI

/// Progress: the trend weight over a range (with the day Div last changed the target), the week-by-week change
/// against the goal, and estimated one-rep maxes for the lifts done most. Named BodyProgressView so it does not clash
/// with SwiftUI's ProgressView. Design: design/source/src/Progress.html
struct BodyProgressView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var range = Range.threeMonths

    enum Range: String, CaseIterable, Identifiable {
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"
        var id: Self { self }
        /// Nil for every weigh-in.
        var days: Int? {
            switch self {
            case .month: 30
            case .threeMonths: 90
            case .sixMonths: 180
            case .year: 365
            case .all: nil
            }
        }
    }

    var body: some View {
        let store = environment.store
        let today = environment.today
        let weight = (try? store.weight(today: today, days: range.days)) ?? WeightSummary()
        let weeks = (try? store.weeklyChanges(today: today, weeks: 7)) ?? []
        let lifts = (try? store.liftTrends(today: today, days: range.days)) ?? []
        let history = try? store.targetHistory(today: today)
        VStack(spacing: 0) {
            TopBar(title: "Progress") {
                BackButton()
            } trailing: {
                IconButton(systemImage: "ruler", label: "Measurements") { router.push(.measurements) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(Range.allCases) { option in
                            Chip(title: option.rawValue, isOn: range == option) { range = option }
                        }
                    }
                    .padding(.top, 16)

                    if weight.trend.isEmpty {
                        Text("No weigh-ins yet. Weigh in a few mornings a week and the trend shows up here.")
                            .font(.az(15)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 20)
                    } else {
                        trend(weight, divTarget: history).padding(.top, 20)
                    }

                    if weeks.contains(where: { $0.kg != nil }) {
                        SectionHeader(
                            title: WeeklyChangeChart.title(environment.profile),
                            note: WeeklyChangeChart.note(environment.profile, weightKg: weight.trend.last, units: environment.units)
                        )
                        .padding(.top, 28)
                        WeeklyChangeChart(
                            weeks: weeks, profile: environment.profile, weightKg: weight.trend.last, units: environment.units
                        )
                        .padding(.top, 6)
                    }

                    SectionHeader(title: "Strength", note: "Estimated 1 rep max").padding(.top, 28)
                    if lifts.isEmpty {
                        Text("Log a workout with weights and your lifts show up here.")
                            .font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 8)
                    } else {
                        HairlineStack {
                            ForEach(lifts, id: \.exerciseID) { lift($0) }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Weigh in") { router.push(.weighIn) }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
                .background(AZColor.background)
        }
        .azScreen()
    }

    // MARK: Trend

    private func trend(_ weight: WeightSummary, divTarget history: TargetHistory?) -> some View {
        let units = environment.units
        let first = weight.trendDays.first.flatMap { Day.date($0) }
        let last = weight.trendDays.last.flatMap { Day.date($0) }
        let span = max(first.flatMap { f in last.map { $0.timeIntervalSince(f) } } ?? 0, 1)
        // Where each point sits along the range, by date, so gaps between weigh-ins show as gaps.
        let xs = weight.trendDays.map { day in Day.date(day).flatMap { d in first.map { d.timeIntervalSince($0) / span } } ?? 0 }
        let divChange: (x: Double, from: Int, to: Int)? = history.flatMap { history in
            guard history.current.source == .div, let previous = history.previous, let first,
                let start = Day.date(history.current.startDay),
                start >= first
            else { return nil }
            return (min(start.timeIntervalSince(first) / span, 1), previous.kcal, history.current.kcal)
        }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "Trend weight")
                    Text(units.bodyWeight(weight.trend.last ?? 0)).font(.az(34, .heavy)).tracking(-1)
                }
                Spacer()
                if let change = weight.changeKg, weight.days > 0 {
                    Text("\(WeighInView.signed(change, units)) in \(Self.duration(weight.days))")
                        .font(.az(14, .semibold)).foregroundStyle(AZColor.muted).padding(.bottom, 6)
                }
            }
            .monospacedDigit()

            ZStack(alignment: .topTrailing) {
                GeometryReader { geo in
                    let width = geo.size.width
                    ZStack(alignment: .topLeading) {
                        Grid3().stroke(AZColor.hairline, lineWidth: 1)
                        if let divChange {
                            Path { p in
                                p.move(to: CGPoint(x: divChange.x * width, y: 4))
                                p.addLine(to: CGPoint(x: divChange.x * width, y: geo.size.height - 2))
                            }
                            .stroke(AZColor.divInk, style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        }
                        TrendLine(xs: xs, values: weight.trend)
                            .stroke(AZColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(height: 130)
                .padding(.top, 20)

                if let divChange {
                    HStack(spacing: 0) {
                        Text("Target \(divChange.from.grouped) → \(divChange.to.grouped)")
                            .font(.az(12.5, .bold)).foregroundStyle(AZColor.divInk).monospacedDigit()
                        DivMark(size: 16).padding(.leading, 5)
                    }
                    .padding(.leading, 10).padding(.trailing, 4)
                    .frame(height: 26)
                    .background(AZColor.divTint, in: .rect(cornerRadius: 9, style: .continuous))
                }
            }
            .frame(height: 150)
            .padding(.top, 10)
            .accessibilityElement()
            .accessibilityLabel(accessibility(weight, units: units))

            if weight.trend.count == 1 {
                Text("One weigh-in so far. The line fills in as you weigh in.")
                    .font(.az(13.5)).foregroundStyle(AZColor.muted).padding(.top, 6)
            } else {
                axis(weight, first: first, last: last)
            }
        }
    }

    private func axis(_ weight: WeightSummary, first: Date?, last: Date?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(first.map(Self.axis) ?? "")
                Spacer()
                Text(weight.trendDays.last == environment.today ? "Today" : last.map(Self.axis) ?? "").foregroundStyle(AZColor.ink)
            }
            .font(.az(12, .semibold))
            .foregroundStyle(AZColor.faint)
            .monospacedDigit()
            .padding(.top, 4)
        }
    }

    private func accessibility(_ weight: WeightSummary, units: UnitSystem) -> String {
        guard let now = weight.trend.last, let start = weight.trend.first else { return "No trend yet" }
        return "Trend weight from \(units.bodyWeight(start)) to \(units.bodyWeight(now)) over \(Self.duration(weight.days))"
    }

    // MARK: Strength

    private func lift(_ lift: LiftTrend) -> some View {
        let units = environment.units
        let detail = "\(units.load(lift.best.loadKg)) × \(lift.best.reps) · \(Self.when(lift.bestDay, today: environment.today))"
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(lift.name).font(.az(16, .bold)).lineLimit(1)
                Text(detail).font(.az(13.5)).foregroundStyle(AZColor.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            if lift.points.count > 1 {
                Sparkline(values: lift.points)
                    .stroke(AZColor.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 64, height: 24)
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text(units.load(lift.e1rmKg)).font(.az(16, .heavy)).lineLimit(1).fixedSize()
                if let change = lift.changeKg {
                    Text(Self.signedLoad(change, units)).font(.az(12.5, .bold)).foregroundStyle(AZColor.muted).fixedSize()
                }
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
        .monospacedDigit()
        .frame(height: 56)
        .contentShape(.rect)
        .onTapGesture { router.push(.exercise(lift.exerciseID)) }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Words

    /// "3 weeks", "5 days", "4 months".
    static func duration(_ days: Int) -> String {
        if days < 14 { return days == 1 ? "1 day" : "\(days) days" }
        if days < 60 { return "\(Int((Double(days) / 7).rounded())) weeks" }
        return "\(Int((Double(days) / 30.4).rounded())) months"
    }

    /// "today", "Tue", or "Nov 3" for older than a week.
    static func when(_ day: String, today: String) -> String {
        guard day != today, let date = Day.date(day) else { return "today" }
        return day >= Day.adding(-6, to: today)
            ? date.formatted(.dateTime.weekday(.abbreviated)) : date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func axis(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day()) }

    /// "+11 lb", "-2.5 kg", in the person's load unit.
    static func signedLoad(_ kg: Double, _ units: UnitSystem) -> String {
        let value = units.loadValue(kg)
        let unit = units.liftLoad == .lb ? "lb" : "kg"
        let text = abs(value) >= 10 ? String(format: "%.0f", abs(value)) : String(format: "%.1f", abs(value))
        return Double(text) == 0 ? "0 \(unit)" : "\(value < 0 ? "-" : "+")\(text) \(unit)"
    }

    /// Three hairlines across the chart.
    private nonisolated struct Grid3: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                for fraction in [0.3, 0.6, 0.9] {
                    p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
                }
            }
        }
    }

    /// The trend through points placed at `xs` (0 to 1 along the range), highest at the top with some headroom.
    private nonisolated struct TrendLine: Shape {
        var xs: [Double]
        var values: [Double]

        func path(in rect: CGRect) -> Path {
            Path { p in
                guard let low = values.min(), let high = values.max(), values.count == xs.count else { return }
                if values.count == 1 {
                    p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                    return
                }
                let pad = max((high - low) * 0.15, 0.3)
                let top = high + pad
                let span = top - (low - pad)
                for (i, value) in values.enumerated() {
                    let x = rect.minX + rect.width * xs[i]
                    let y = rect.minY + rect.height * (top - value) / span
                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

#Preview {
    NavigationStack { BodyProgressView() }.environment(Router()).environment(AppEnvironment.preview())
}
