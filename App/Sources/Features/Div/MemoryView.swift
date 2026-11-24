import SwiftUI

/// What Div knows: what it may do without asking (three switches, one always off) and what it remembers.
/// The switches are the user-facing side of D-009: code, not the prompt, decides what Div may do alone.
/// Design: design/source/src/Memory.html
struct MemoryView: View {
    @Environment(Router.self) private var router
    @State private var allowed = [true, true, true]

    private let tiers = [
        ("Reps, weight and rest", "During a workout, shown on the set"),
        ("Swap exercises, move sessions", "Logged, undo for 7 days"),
        ("Calorie target, up to 200 kcal", "Bigger changes ask you first"),
    ]

    private let memories = [
        ("Left shoulder tight overhead", "From chat · Tue, Nov 17"),
        ("Right knee: no deep lunges", "From onboarding"),
        ("Trains mornings, about 50 min", "Learned from 6 weeks of sessions"),
        ("Short answers, no pep talks", "You said so · Oct 3"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Div") {
                BackButton()
            } trailing: {
                IconButton(systemImage: "magnifyingglass", label: "Search memory") { router.push(.chat) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        DivAvatar(size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("What Div knows").font(.az(22, .heavy)).tracking(-0.44)
                            Text("Opus on your MacBook · 214 memories").font(.az(14)).foregroundStyle(AZColor.muted)
                        }
                    }
                    .padding(.top, 16)

                    SectionLabel(text: "Div can do without asking").padding(.top, 26)
                    HairlineStack {
                        ForEach(tiers.indices, id: \.self) { i in
                            item(tiers[i].0, allowed[i] ? tiers[i].1 : "Div suggests, you decide") {
                                SquareToggle(isOn: $allowed[i], label: tiers[i].0)
                            }
                        }
                        item("Fill in food you didn't log", "Never. Div asks you instead.") {
                            Image(systemName: "lock")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AZColor.faint)
                                .frame(width: 50, height: 30)
                                .background(AZColor.fill, in: .rect(cornerRadius: 10, style: .continuous))
                                .accessibilityLabel("Always off")
                        }
                    }
                    .padding(.top, 2)

                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel(text: "Remembers")
                        Spacer()
                        Button("Add") { router.push(.chat) }
                            .font(.az(14, .semibold)).foregroundStyle(AZColor.muted).buttonStyle(.plain)
                    }
                    .padding(.top, 26)
                    HairlineStack {
                        ForEach(memories, id: \.0) { memory in
                            item(memory.0, memory.1) {
                                Image(systemName: "pencil").font(.system(size: 16, weight: .medium)).foregroundStyle(AZColor.faint)
                                    .accessibilityLabel("Edit")
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    private func item<Trailing: View>(_ title: String, _ subtitle: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.az(15.5, .bold))
                Text(subtitle).font(.az(13.5)).foregroundStyle(AZColor.muted).contentTransition(.opacity)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: 60)
    }
}

#Preview {
    NavigationStack { MemoryView() }.environment(Router())
}
