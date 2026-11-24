import SwiftUI

/// Div's note: avatar, a bold title, one or two sentences of evidence, and up to two actions.
/// Used for every change Div makes and every question it asks.
/// `.change` is lavender (Div changed or is asking something). `.settled` is the neutral fill, used once you undo
/// or answer, so lavender always means "Div changed this and it still stands".
struct DivNote<Actions: View>: View {
    enum Tone { case change, settled }

    var title: String
    var message: String
    var tone: Tone = .change
    var mood: DivAvatar.Mood = .curious
    /// Put the actions on the right, centered, instead of under the text. Used by the short settled notes ("Use 6").
    var actionsOnRight = false
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: actionsOnRight ? .center : .top, spacing: 12) {
            DivAvatar(size: 36, mood: mood)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.az(15, .bold)).foregroundStyle(AZColor.ink)
                Text(message)
                    .font(.az(14))
                    .foregroundStyle(tone == .change ? AZColor.divMuted : AZColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if !actionsOnRight && Actions.self != EmptyView.self {
                    HStack(spacing: 8) { actions }.padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if actionsOnRight { actions }
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
        .background(tone == .change ? AZColor.divTint : AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
    }
}

extension DivNote where Actions == EmptyView {
    init(title: String, message: String, tone: Tone = .change, mood: DivAvatar.Mood = .curious) {
        self.init(title: title, message: message, tone: tone, mood: mood, actions: { EmptyView() })
    }
}

/// The old value, struck through, next to the new one: "~~2,200~~ 2,350".
struct WasValue: View {
    var value: String
    var body: some View {
        Text(value)
            .fontWeight(.medium)
            .strikethrough(true, color: AZColor.faint)
            .foregroundStyle(AZColor.faint)
            .accessibilityLabel("was \(value)")
    }
}

#Preview {
    VStack(spacing: 16) {
        DivNote(title: "I lowered set 3 to 6 reps", message: "You got 6 on set 2. Matching it keeps your form clean.") {
            PillButton(title: "Keep 8 reps", systemImage: "arrow.uturn.backward") {}
        }
        DivNote(
            title: "Back to 8. Your call.", message: "If set 3 stalls early, stop at 6.", tone: .settled, mood: .side, actionsOnRight: true
        ) {
            PillButton(title: "Use 6") {}
        }
    }
    .padding(24)
}
