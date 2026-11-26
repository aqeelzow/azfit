import AZMath
import AZModel
import AZStore
import SwiftUI

/// The daily targets and why they are what they are: calories with who set them and when, the macros and water,
/// the change Div made (with a way back), five weeks of the scale against the goal, the numbers the Sunday review
/// reads, and the micronutrient daily values. The person can change the targets themselves (`EditTargetsView`). The math is AZMath's; Div only explains it (D-010).
/// Design: design/source/src/Calibrate.html
struct CalorieTargetView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var problem: String?

    var body: some View {
        let store = environment.store
        let today = environment.today
        let history = try? store.targetHistory(today: today)
        let weeks = (try? store.weeklyChanges(today: today, weeks: 5)) ?? []
        let snapshot = try? store.weeklySnapshot(weekEnding: today)
        let undoable = history?.change.flatMap { $0.canUndo(at: .now) ? $0 : nil }
        let targets = try? store.dailyTargets(on: today)
        VStack(spacing: 0) {
            TopBar(title: "Daily targets") {
                BackButton()
            } trailing: {
                Button {
                    router.push(.chat)
                } label: {
                    DivAvatar(size: 26)
                        .frame(width: 44, height: 44)
                        .background(AZColor.fill, in: .rect(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask Div")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let history {
                        header(history).padding(.top, 16)
                        if let targets { macros(targets).padding(.top, 18) }
                        if let change = history.change, !change.proposal.reason.isEmpty {
                            DivNote(title: Self.noteTitle(history), message: change.proposal.reason).padding(.top, 20)
                        }
                        if let problem {
                            Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 10)
                        }
                    } else {
                        Text("No target yet. It's set when you finish onboarding.")
                            .font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 16)
                    }

                    if weeks.contains(where: { $0.kg != nil }) {
                        let weightKg = snapshot?.weight.trendKgNow ?? (try? store.latestWeighIn())?.kg
                        SectionHeader(
                            title: WeeklyChangeChart.title(environment.profile),
                            note: WeeklyChangeChart.note(environment.profile, weightKg: weightKg, units: environment.units)
                        )
                        .padding(.top, 26)
                        WeeklyChangeChart(weeks: weeks, profile: environment.profile, weightKg: weightKg, units: environment.units)
                            .padding(.top, 6)

                        SectionLabel(text: "What Div looks at").padding(.top, 26)
                        facts(snapshot).padding(.top, 12)
                    } else if history != nil {
                        Text(
                            "Weigh in a few mornings a week and log your meals. After a couple of weeks Div can tell whether this target is working."
                        )
                        .font(.az(14.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 26)
                    }

                    if history != nil { micronutrientGoals.padding(.top, 30) }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                if let undoable, let history, let previous = history.previous {
                    HStack(spacing: 10) {
                        PrimaryButton(title: "Go back to \(previous.kcal.grouped)", style: .soft) { undo(undoable) }
                        PrimaryButton(title: "Keep \(history.current.kcal.grouped)") { router.pop() }
                    }
                }
                HStack(spacing: 4) {
                    Text("Div asks before changing calories. You can change them anytime.").foregroundStyle(AZColor.faint)
                    Button("Settings") { router.push(.memory) }.fontWeight(.semibold).foregroundStyle(AZColor.muted).buttonStyle(.plain)
                }
                .font(.az(12.5))
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.bottom, 8)
        }
        .azScreen()
    }

    private func header(_ history: TargetHistory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if history.current.source == .div { DivMark() }
                SectionLabel(text: Self.caption(history))
                Spacer()
                PillButton(title: "Change", systemImage: "slider.horizontal.3", style: .fill) { router.push(.editTargets) }
            }
            HStack(alignment: .bottom, spacing: 14) {
                Text(history.current.kcal.grouped)
                    .font(.az(64, .heavy)).tracking(-2.9).monospacedDigit()
                    .contentTransition(.numericText(value: Double(history.current.kcal)))
                VStack(alignment: .leading, spacing: 2) {
                    if history.current.source == .div, let previous = history.previous {
                        WasValue(value: previous.kcal.grouped).font(.az(17)).monospacedDigit()
                    }
                    SectionLabel(text: "kcal a day")
                }
                .padding(.bottom, 6)
            }
        }
    }

    /// Protein, carbs and fat in grams, and water.
    private func macros(_ t: DailyTargets) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                tile("Protein", t.proteinG.map { "\($0) g" }, color: AZColor.accent)
                tile("Carbs", t.carbsG.map { "\($0) g" }, color: AZColor.carbs)
                tile("Fat", t.fatG.map { "\($0) g" }, color: AZColor.fat)
            }
            HStack {
                Rectangle().fill(AZColor.water).frame(width: 4, height: 22).clipShape(.capsule)
                Text("Water").font(.az(15.5, .bold))
                Spacer()
                Text("\(EditTargetsView.litres(t.waterMl)) L").font(.az(17, .heavy)).monospacedDigit()
                Text("\(t.waterMl / Int(WaterLog.glassMl)) glasses").font(.az(13.5)).foregroundStyle(AZColor.muted)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
            if t.proteinG == nil {
                Text("Weigh in once to see protein, carbs and fat in grams: protein is set per kg.")
                    .font(.az(13.5)).foregroundStyle(AZColor.muted).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func tile(_ name: String, _ value: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(color).frame(width: 18, height: 4).clipShape(.capsule)
            Text(name).font(.az(13, .semibold)).foregroundStyle(AZColor.muted)
            Text(value ?? "-").font(.az(19, .heavy)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// The daily values Eat measures micronutrients against.
    private var micronutrientGoals: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Micronutrients", note: "Daily values")
            HairlineStack {
                ForEach(Micronutrient.allCases) { micro in
                    HStack {
                        Text(micro.title).font(.az(15, .semibold))
                        if micro.isLimit { Text("limit").font(.az(12.5, .semibold)).foregroundStyle(AZColor.faint) }
                        Spacer()
                        Text("\(micro.isLimit ? "under " : "")\(Int(micro.dailyValue).grouped) \(micro.unit)")
                            .font(.az(15)).foregroundStyle(AZColor.muted).monospacedDigit()
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 4)
            Text("US daily values for adults. They're the same for everyone and don't change with your plan.")
                .font(.az(13)).foregroundStyle(AZColor.faint).padding(.top, 8)
        }
    }

    @ViewBuilder
    private func facts(_ snapshot: WeeklySnapshot?) -> some View {
        if let snapshot {
            let derived = WeeklyMath.derive(snapshot)
            let units = environment.units
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    fact(WeighInView.signed(derived.weeklyRateKg, units), "a week, over \(snapshot.intake.windowDays) days")
                    fact(
                        snapshot.intake.completeDays > 0 ? Int(snapshot.intake.avgKcalCompleteDays.rounded()).grouped : "-",
                        "average on full days")
                }
                GridRow {
                    fact("\(snapshot.intake.completeDays) of \(snapshot.intake.windowDays)", "days fully logged")
                    fact(
                        derived.impliedMaintenanceKcal.map { "~\($0.grouped)" } ?? "-",
                        derived.enoughCompleteDays ? "your maintenance" : "maintenance, after \(WeeklyMath.minCompleteDays) full days")
                }
            }
        } else {
            Text("Div needs a couple of weeks of weigh-ins and logged meals before it judges the target.")
                .font(.az(14.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.az(18, .heavy)).tracking(-0.36).monospacedDigit()
            Text(label).font(.az(13.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func undo(_ change: DivChange) {
        do {
            try environment.store.undo(change.id)
            withAnimation(.snappy(duration: 0.25)) { environment.changed() }
        } catch {
            problem = "Couldn't undo it: \(error.localizedDescription)"
        }
    }

    /// "Raised by Div · Monday, Nov 16", "You set this · ...", "Set at the start · ...".
    static func caption(_ history: TargetHistory) -> String {
        let who =
            switch history.current.source {
            case .div:
                history.previous.map { $0.kcal > history.current.kcal ? "Lowered by Div" : "Raised by Div" } ?? "Set by Div"
            case .person: "You set this"
            case .onboarding: "Set at the start"
            }
        return "\(who) · \(AppEnvironment.caption(history.current.startDay))"
    }

    static func noteTitle(_ history: TargetHistory) -> String {
        guard let previous = history.previous else { return "Why Div set it" }
        let delta = history.current.kcal - previous.kcal
        return delta > 0 ? "Div added \(delta.grouped) kcal" : "Div took off \((-delta).grouped) kcal"
    }
}

#Preview {
    NavigationStack { CalorieTargetView() }.environment(Router()).environment(AppEnvironment.preview())
}
