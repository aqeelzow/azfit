import SwiftUI

/// Div's note card: avatar, a bold one-line title, one sentence of evidence, and up to two actions.
/// Used for every change and every question. Lavender when Div changed something; neutral fill once undone.
struct DivNote<Actions: View>: View {
    var title: String
    var message: String
    var undone = false
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DivAvatar(size: 36, mood: undone ? .side : .curious)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AZFont.title).foregroundStyle(undone ? AZColor.ink : AZColor.divInk)
                Text(message).font(AZFont.body).foregroundStyle(undone ? AZColor.muted : AZColor.divMuted)
                HStack(spacing: 8) { actions }.padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(undone ? AZColor.fill : AZColor.divTint, in: .rect(cornerRadius: AZRadius.card, style: .continuous))
    }
}

/// The old value, struck through, next to the new one: "~~2,200~~ 2,350".
struct WasValue: View {
    var value: String
    var body: some View {
        Text(value)
            .strikethrough(true, color: AZColor.faint)
            .foregroundStyle(AZColor.faint)
            .accessibilityLabel("was \(value)")
    }
}

/// Small pill button used inside notes. `.primary` is the filled one ("Keep 8 reps"), `.quiet` the white one ("Undo").
struct PillButton: View {
    enum Style { case primary, quiet }
    var title: String
    var style: Style = .quiet
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(AZFont.label)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(style == .primary ? AZColor.buttonInk : AZColor.ink)
            .background(style == .primary ? AZColor.button : AZColor.card, in: .capsule)
            .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        DivNote(title: "Set 3: 8 → 6 reps", message: "You got 6 on set 2, so I lowered the target.") {
            PillButton(title: "Keep 8 reps", style: .primary) {}
            PillButton(title: "Why?") {}
        }
        DivNote(title: "Back to 8. Your call.", message: "I'll check again next session.", undone: true) {}
    }
    .padding(24)
}
