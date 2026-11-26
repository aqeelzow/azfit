import AZModel
import AZStore
import SwiftUI

/// The panel behind the purple plus: the meal you log most, one tap away, then six ways to log.
/// Design: design/source/src/QuickAdd.html
struct QuickAddOverlay: View {
    @Bindable var router: Router
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ZStack(alignment: .bottom) {
            if router.isQuickAddOpen {
                AZColor.Camera.scrim
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                panel.transition(.move(edge: .bottom))
            }
        }
    }

    private var panel: some View {
        let usual = try? environment.store.recentMeals(limit: 1).first
        let session = try? environment.store.todaySession(today: environment.today)
        return VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(AZColor.track).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
            Text("What are we logging?")
                .font(.az(24, .heavy)).tracking(-0.48)
                .padding(.top, 19).padding(.horizontal, 4)
            if let usual {
                Button {
                    logAgain(usual.meal)
                } label: {
                    DivNote(
                        title: "Log \(usual.meal.name) again?",
                        message:
                            "\(Int(usual.meal.kcal.rounded()).grouped) kcal, the way you logged it \(usual.times == 1 ? "last time" : "\(usual.times) times").",
                        actionsOnRight: true
                    ) {
                        Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(AZColor.divMuted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Adds it to today")
                .padding(.top, 22)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                option("Snap a meal", "camera", isDiv: true) { router.present(.snap) }
                option("Describe food", "text.alignleft") { router.push(.describeMeal) }
                option("Say it", "mic") { router.present(.voice) }
                if let session {
                    option("Start \(session.session.name)", "dumbbell") { router.push(.workout) }
                } else {
                    option("Exercises", "dumbbell") { router.push(.swapExercise(nil)) }
                }
                option("Weigh in", "scalemass") { router.push(.weighIn) }
                Button {
                    router.push(.chat)
                } label: {
                    row(title: "Ask Div", tint: false) { DivAvatar(size: 38, cornerRatio: 0.32) }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        // Clear of the tab bar, which sits on top of this panel.
        .padding(.bottom, TabBar.height - 34 + 14)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous)
                .fill(AZColor.background)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// One tap: the same meal, now, on today.
    private func logAgain(_ meal: Meal) {
        guard (try? environment.store.logMeal(meal.again(day: environment.today))) != nil else { return }
        environment.changed()
        router.show(.eat)
    }

    private func option(_ title: String, _ systemImage: String, isDiv: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            row(title: title, tint: isDiv) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(isDiv ? Color.white : AZColor.ink)
                    .background(isDiv ? AZColor.accent : AZColor.card, in: .rect(cornerRadius: 12, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    private func row<Icon: View>(title: String, tint: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 12) {
            icon()
            Text(title).font(.az(15, .bold)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(tint ? AZColor.divTint : AZColor.fill, in: .rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect)
    }

    private func close() {
        withAnimation(.snappy(duration: 0.28)) { router.isQuickAddOpen = false }
    }
}
