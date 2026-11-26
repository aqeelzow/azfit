import AZModel
import AZStore
import SwiftUI

/// Div's log: changes waiting for you, then every change Div made this week, each undoable for 7 days.
/// Design: design/source/src/Review.html
struct DivLogView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var problem: String?

    var body: some View {
        let today = environment.today
        let changes = (try? environment.store.recentChanges(today: today)) ?? []
        let waiting = changes.filter { $0.status == .proposed }
        let made = changes.filter { $0.status != .proposed && $0.status != .declined }
        let review = environment.recentWeekReview
        VStack(spacing: 0) {
            TopBar(title: "Div's log") {
                BackButton()
            } trailing: {
                IconButton(systemImage: "brain", label: "What Div knows") { router.push(.memory) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Last 7 days")
                        Text(headline(made: made.filter { $0.status != .undone }.count, waiting: waiting.count))
                            .font(.az(34, .heavy)).tracking(-0.85).contentTransition(.numericText())
                    }
                    .padding(.top, 18)

                    if let problem {
                        Text(problem).font(.az(13.5)).foregroundStyle(AZColor.muted).padding(.top, 10)
                    }

                    if let review {
                        SectionLabel(text: "Sunday review · \(AppEnvironment.caption(review.weekEnding))").padding(.top, 24)
                        DivNote(title: "Your week", message: review.summary, tone: .settled).padding(.top, 10)
                        ForEach(review.questions, id: \.self) { question in
                            DivNote(title: question, message: "Tell Div in chat and it'll take it into account.") {
                                PillButton(title: "Answer", style: .dark) { router.push(.chat) }
                            }
                            .padding(.top, 10)
                        }
                    }

                    if !waiting.isEmpty {
                        SectionLabel(text: "Needs you").padding(.top, 24)
                        ForEach(waiting) { change in
                            let summary = change.proposal.change.summary
                            DivNote(title: summary.title, message: change.proposal.reason.isEmpty ? summary.detail : change.proposal.reason)
                            {
                                PillButton(title: "Approve", style: .dark) {
                                    act { try environment.store.approve(change.id, today: today) }
                                }
                                PillButton(title: "Not now") { act { try environment.store.decline(change.id) } }
                            }
                            .padding(.top, 10)
                        }
                    }

                    SectionLabel(text: "Changes").padding(.top, 24)
                    if made.isEmpty {
                        Text("Div hasn't changed anything yet. Changes show here with their reason and an Undo.")
                            .font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 8)
                    } else {
                        HairlineStack {
                            ForEach(made) { row($0) }
                        }
                        .padding(.top, 4)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 13, weight: .semibold))
                        Text("Every change can be undone for 7 days.").font(.az(13))
                    }
                    .foregroundStyle(AZColor.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    private func headline(made: Int, waiting: Int) -> String {
        let changes = "\(made) \(made == 1 ? "change" : "changes")"
        return waiting == 0 ? changes : "\(changes), \(waiting) to check"
    }

    /// Runs a store change, then refreshes every screen and syncs.
    private func act(_ change: () throws -> Void) {
        do {
            try change()
            problem = nil
        } catch {
            problem = "\(error)"
        }
        withAnimation(.snappy(duration: 0.2)) { environment.changed() }
    }

    private func icon(_ change: PlanChange) -> String {
        switch change {
        case .setCalorieTarget, .setProteinTarget: "flame.fill"
        case .setLoad, .changeVolume: "dumbbell.fill"
        case .swapExercise: "arrow.left.arrow.right"
        case .moveSession: "calendar"
        case .scheduleDeload: "arrow.down.right"
        }
    }

    private func row(_ change: DivChange) -> some View {
        let summary = change.proposal.change.summary
        let isOff = change.status == .undone
        let reason = change.proposal.reason.isEmpty ? summary.detail : change.proposal.reason
        let when = change.createdAt.formatted(.dateTime.weekday(.abbreviated))
        return HStack(spacing: 14) {
            IconTile(
                systemImage: icon(change.proposal.change), size: 44, foreground: isOff ? AZColor.faint : AZColor.divInk,
                background: isOff ? AZColor.fill : AZColor.divTint)
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.title)
                    .font(.az(15.5, .bold))
                    .strikethrough(isOff, color: AZColor.muted)
                    .foregroundStyle(isOff ? AZColor.muted : AZColor.ink)
                    .monospacedDigit()
                Text(isOff ? "Undone · back to how it was" : "\(reason) · \(when)").font(.az(13.5)).foregroundStyle(AZColor.muted)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            if change.canUndo(at: .now) {
                PillButton(title: "Undo", style: .fill) { act { try environment.store.undo(change.id) } }
                    .accessibilityLabel("Undo: \(summary.title)")
            }
        }
        .frame(minHeight: 72)
    }
}

#Preview {
    NavigationStack { DivLogView() }.environment(Router()).environment(AppEnvironment.preview())
}
