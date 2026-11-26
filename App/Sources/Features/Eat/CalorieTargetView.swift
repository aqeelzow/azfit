import AZMath
import AZModel
import AZStore
import SwiftUI

/// Why the daily target is what it is: who set it and when, the change Div made (with a way back), five weeks of the
/// scale against the goal, and the numbers the Sunday review reads. The math is AZMath's; Div only explains it (D-010).
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
        VStack(spacing: 0) {
            TopBar(title: "Daily target") {
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
                    Text("Div asks before changing calories.").foregroundStyle(AZColor.faint)
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
