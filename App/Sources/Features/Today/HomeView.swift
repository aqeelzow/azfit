import AZModel
import AZStore
import SwiftUI

/// Home: the week, today's session, what Div changed, and food and weight at a glance.
/// Design: design/source/src/Home.html
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment

    private var store: AZStore { environment.store }
    private var today: String { environment.today }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LargeTitle(caption: AppEnvironment.caption(today), title: environment.greeting)
                    Spacer()
                    Button {
                        router.push(.memory)
                    } label: {
                        PhotoTile(name: "avatar", size: 44, radius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile")
                }
                WeekStrip((try? store.week(today: today)) ?? []) { day in
                    router.showTrain(on: day.day)
                }
                .padding(.top, 16)
                if let session = try? store.todaySession(today: today) {
                    todayCard(session).padding(.top, 20)
                } else {
                    restCard.padding(.top, 20)
                }
                sessionNote.padding(.top, 16)
                divChanges.padding(.top, 16)
                HStack(spacing: 12) {
                    foodTile
                    weightTile
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// No session today: say what's next.
    private var restCard: some View {
        let next = (try? store.sessionsAhead(today: today))?.first { $0.day > today }
        return Button {
            router.show(.train)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today").font(.az(14, .semibold)).foregroundStyle(AZColor.divInk)
                Text("Rest day").font(.az(40, .heavy)).tracking(-1.4)
                Text(next.map { "Next: \($0.session.name), \(AppEnvironment.caption($0.day))" } ?? "Nothing else planned this week")
                    .font(.az(14.5)).foregroundStyle(AZColor.divMuted)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AZColor.divTint, in: .rect(cornerRadius: 32, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func todayCard(_ session: SessionPreview) -> some View {
        Button {
            router.push(.workout(session.session.id))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today · \(session.minutes) min").font(.az(14, .semibold)).foregroundStyle(AZColor.divInk)
                Text(session.session.name).font(.az(40, .heavy)).tracking(-1.4)
                VStack(spacing: 0) {
                    ForEach(session.lines.prefix(3), id: \.exerciseID) { line in
                        exerciseLine(line.name, line.prescription, changedByDiv: line.swappedFrom != nil)
                    }
                    if session.lines.count > 3 {
                        HStack {
                            Text("+\(session.lines.count - 3) more").foregroundStyle(AZColor.divMuted)
                            Spacer()
                        }
                        .frame(height: 26)
                    }
                }
                .font(.az(14.5))
                .padding(.top, 14)
                Spacer(minLength: 16)
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 13))
                    Text("Start")
                }
                .font(.az(16.5, .bold))
                .foregroundStyle(AZColor.buttonInk)
                .frame(width: 128, height: 50)
                .background(AZColor.button, in: .capsule)
            }
            .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 288)
            .background(AZColor.divTint, in: .rect(cornerRadius: 32, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func exerciseLine(_ name: String, _ sets: String, changedByDiv: Bool = false) -> some View {
        HStack {
            HStack(spacing: 5) {
                Text(name)
                if changedByDiv { DivMark(size: 16) }
            }
            Spacer()
            Text(sets).foregroundStyle(AZColor.divMuted).monospacedDigit()
        }
        .frame(height: 26)
    }

    /// Div's note on today's finished workout, or that it's still reviewing.
    @ViewBuilder
    private var sessionNote: some View {
        if !environment.reviewing.isEmpty {
            DivNote(title: "Reviewing your workout", message: "Div is looking at every set to plan next time.", tone: .settled) {
                EmptyView()
            }
        } else if let workout = try? store.reviewedWorkout(on: today), let note = workout.divNote {
            DivNote(title: "After \(workout.name)", message: note) {
                PillButton(title: "See changes") { router.push(.divLog) }
            }
        } else if let problem = environment.reviewProblem {
            DivNote(title: "Div couldn't review your workout", message: problem, tone: .settled) { EmptyView() }
        }
    }

    private var divChanges: some View {
        let changes = (try? store.recentChanges(today: today)) ?? []
        let made = changes.filter { $0.status == .applied || $0.status == .approved }.count
        let questions = changes.filter { $0.status == .proposed }.count + (environment.recentWeekReview?.questions.count ?? 0)
        // Div runs on the Mac: without it, "no changes" would read as Div looking and finding nothing.
        let state = environment.bridge.state
        let title: String
        let subtitle: String
        var goesTo = Router.Route.divLog
        switch state {
        case .unpaired where made == 0:
            title = "Div isn't connected"
            subtitle = "Pair your Mac so Div can coach you"
            goesTo = .connectMac
        case .offline where made == 0:
            title = "Div is offline"
            subtitle = "Open AZfit Bridge on your Mac to reconnect"
            goesTo = .connectMac
        default:
            title = made == 0 ? "No changes from Div this week" : "Div made \(made) \(made == 1 ? "change" : "changes") this week"
            subtitle =
                questions > 0
                ? "And has \(questions) \(questions == 1 ? "question" : "questions") for you" : "Ask Div anything about your plan"
        }
        return Button {
            router.push(goesTo)
        } label: {
            HStack(spacing: 12) {
                DivAvatar(size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.az(15, .bold))
                    Text(subtitle).font(.az(13.5)).foregroundStyle(AZColor.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(AZColor.faint)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: 68)
            .background(AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var foodTile: some View {
        let food = (try? store.food(on: today))
        return Button {
            router.show(.eat)
        } label: {
            tile {
                SectionLabel(text: "Food")
                Spacer(minLength: 0)
                Text(food?.leftKcal?.grouped ?? "-").font(.az(26, .heavy)).tracking(-0.5).monospacedDigit()
                Text(food?.targetKcal == nil ? "No target yet" : "kcal left").font(.az(13.5)).foregroundStyle(AZColor.muted).padding(
                    .bottom, 8)
                MeterBar(value: food?.fraction ?? 0, height: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private var weightTile: some View {
        let weight = (try? store.weight(today: today)) ?? WeightSummary()
        return Button {
            router.push(.progress)
        } label: {
            tile {
                HStack {
                    SectionLabel(text: "Weight")
                    Spacer()
                    Sparkline(values: weight.trend)
                        .stroke(AZColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 58, height: 24)
                }
                Spacer(minLength: 0)
                Text(weight.latestKg.map { environment.units.bodyWeight($0) } ?? "-")
                    .font(.az(24, .heavy)).tracking(-0.5).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(weightChange(weight)).font(.az(13.5)).foregroundStyle(AZColor.muted).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func weightChange(_ weight: WeightSummary) -> String {
        guard let change = weight.changeKg, weight.days > 0 else { return "Weigh in to see a trend" }
        let sign = change > 0 ? "+" : change < 0 ? "-" : ""
        let amount = environment.units.bodyWeight(abs(change))
        return weight.days < 7 ? "\(sign)\(amount) in \(weight.days) days" : "\(sign)\(amount) in \(weight.days / 7) weeks"
    }

    private func tile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 112)
            .background(AZColor.fill, in: .rect(cornerRadius: 26, style: .continuous))
            .contentShape(.rect)
    }
}

#Preview {
    MainView().environment(AppEnvironment.preview())
}
