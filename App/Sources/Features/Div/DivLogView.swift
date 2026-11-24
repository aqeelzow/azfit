import SwiftUI

/// Div's log: the question Div needs you for, then every change it made this week, each undoable for 7 days.
/// Design: design/source/src/Review.html
struct DivLogView: View {
    @Environment(Router.self) private var router
    @State private var undone: Set<Int> = []

    private let changes = [
        ("dumbbell.fill", "Set 3: 8 → 6 reps", "You got 6 on set 2 · Today"),
        ("calendar", "Upper A → Sunday", "You missed Friday · Sat"),
        ("arrow.left.arrow.right", "Overhead → landmine press", "Shoulder felt tight · Tue"),
        ("flame.fill", "Target 2,200 → 2,350 kcal", "Losing 0.7 kg a week · Mon"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Div's log") {
                BackButton()
            } trailing: {
                IconButton(systemImage: "brain", label: "What Div knows") { router.push(.memory) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Nov 16 - 22").monospacedDigit()
                        Text(headline).font(.az(34, .heavy)).tracking(-0.85).contentTransition(.numericText())
                    }
                    .padding(.top, 18)

                    SectionLabel(text: "Needs you").padding(.top, 24)
                    DivNote(
                        title: "Did Thursday's dinner slip through?",
                        message: "You logged 1,180 kcal, about half your usual, and your weight didn't move Friday."
                    ) {
                        PillButton(title: "Add it", style: .dark) { router.present(.snap) }
                        PillButton(title: "No, that's right") { router.show(.eat) }
                    }
                    .padding(.top, 10)

                    SectionLabel(text: "Changes").padding(.top, 24)
                    HairlineStack {
                        ForEach(changes.indices, id: \.self) { i in row(i) }
                    }
                    .padding(.top, 4)

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

    private var headline: String {
        let n = changes.count - undone.count
        return "\(n) \(n == 1 ? "change" : "changes"), 1 question"
    }

    private func row(_ i: Int) -> some View {
        let (icon, title, reason) = changes[i]
        let isOff = undone.contains(i)
        return HStack(spacing: 14) {
            IconTile(
                systemImage: icon, size: 44, foreground: isOff ? AZColor.faint : AZColor.divInk,
                background: isOff ? AZColor.fill : AZColor.divTint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.az(15.5, .bold))
                    .strikethrough(isOff, color: AZColor.muted)
                    .foregroundStyle(isOff ? AZColor.muted : AZColor.ink)
                    .monospacedDigit()
                Text(isOff ? "Undone · back to how it was" : reason).font(.az(13.5)).foregroundStyle(AZColor.muted)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            PillButton(title: isOff ? "Redo" : "Undo", style: .fill) {
                withAnimation(.snappy(duration: 0.2)) {
                    if isOff { undone.remove(i) } else { undone.insert(i) }
                }
            }
            .accessibilityLabel("\(isOff ? "Redo" : "Undo"): \(title)")
        }
        .frame(minHeight: 72)
    }
}

#Preview {
    NavigationStack { DivLogView() }.environment(Router())
}
