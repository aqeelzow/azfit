import AZModel
import AZStore
import SwiftUI

/// What Div knows: what it may do without asking (three switches, two always off) and what it remembers.
/// The switches are the user-facing side of D-009: code, not the prompt, decides what Div may do alone. They save
/// to the profile's `Autonomy`, which the bridge reads on every job. Design: design/source/src/Memory.html
struct MemoryView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var problem: String?

    private var lock: some View {
        Image(systemName: "lock")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AZColor.faint)
            .frame(width: 50, height: 30)
            .background(AZColor.fill, in: .rect(cornerRadius: 10, style: .continuous))
            .accessibilityLabel("Always off")
    }

    var body: some View {
        let memories = (try? environment.store.memories()) ?? []
        VStack(spacing: 0) {
            TopBar(title: "Div") {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        DivAvatar(size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("What Div knows").font(.az(22, .heavy)).tracking(-0.44)
                            Text(Self.subtitle(bridge: environment.bridge.bridgeName, memories: memories.count))
                                .font(.az(14)).foregroundStyle(AZColor.muted)
                        }
                    }
                    .padding(.top, 16)

                    SectionLabel(text: "Div can do without asking").padding(.top, 26)
                    HairlineStack {
                        tier("Reps, weight and rest", "During a workout and in the weekly review", \.workoutTweaks)
                        tier("Swap exercises", "Logged, undo for 7 days", \.swaps)
                        tier("Move sessions", "Logged, undo for 7 days", \.moves)
                        item("Calorie target", "Always asks you first") { lock }
                        item("Fill in food you didn't log", "Never. Div asks you instead.") { lock }
                    }
                    .padding(.top, 2)
                    if let problem {
                        Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 8)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel(text: "Remembers")
                        Spacer()
                        Button("Tell Div") { router.push(.chat) }
                            .font(.az(14, .semibold)).foregroundStyle(AZColor.muted).buttonStyle(.plain)
                    }
                    .padding(.top, 26)
                    if memories.isEmpty {
                        Text("Nothing yet. Tell Div about an injury, your schedule or how you like answers, and it keeps it here.")
                            .font(.az(14.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    } else {
                        HairlineStack {
                            ForEach(memories) { memory in
                                item(memory.text, Self.origin(memory)) {
                                    Menu {
                                        Button("Forget", systemImage: "trash", role: .destructive) { forget(memory) }
                                    } label: {
                                        Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(AZColor.faint)
                                            .frame(width: 44, height: 44)
                                            .contentShape(.rect)
                                    }
                                    .menuIndicator(.hidden)
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Options for \(memory.text)")
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    /// One switch, bound to the saved autonomy.
    private func tier(_ title: String, _ detail: String, _ key: WritableKeyPath<Autonomy, Bool>) -> some View {
        let autonomy = environment.profile?.autonomy ?? .standard
        let isOn = Binding(
            get: { autonomy[keyPath: key] },
            set: { value in
                var next = autonomy
                next[keyPath: key] = value
                save(next)
            })
        return item(title, isOn.wrappedValue ? detail : "Div suggests, you decide") {
            SquareToggle(isOn: isOn, label: title)
        }
    }

    private func item<Trailing: View>(_ title: String, _ subtitle: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.az(15.5, .bold)).lineLimit(2)
                Text(subtitle).font(.az(13.5)).foregroundStyle(AZColor.muted).lineLimit(1).contentTransition(.opacity)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: 60)
    }

    private func save(_ autonomy: Autonomy) {
        do {
            try environment.store.setAutonomy(autonomy)
            environment.changed()
            problem = nil
        } catch {
            problem = "Couldn't save that: \(error.localizedDescription)"
        }
    }

    private func forget(_ memory: Memory) {
        do {
            try environment.store.forget(memory.id)
            withAnimation(.snappy(duration: 0.2)) { environment.changed() }
        } catch {
            problem = "Couldn't forget it: \(error.localizedDescription)"
        }
    }

    /// "On Moiz's MacBook · 12 memories", or "No Mac connected · 1 memory".
    static func subtitle(bridge: String?, memories: Int) -> String {
        let place = bridge.map { "On \($0)" } ?? "No Mac connected"
        return "\(place) · \(memories == 1 ? "1 memory" : "\(memories) memories")"
    }

    /// "From chat · Tue, Nov 17", "From onboarding", "Learned · Oct 3".
    static func origin(_ memory: Memory) -> String {
        let date = memory.createdAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        switch memory.source {
        case .chat: return "From chat · \(date)"
        case .onboarding: return "From onboarding"
        case .learned: return "Learned · \(date)"
        }
    }
}

#Preview {
    NavigationStack { MemoryView() }.environment(Router()).environment(AppEnvironment.preview())
}
