import SwiftUI

/// First run: Welcome, then three steps (goal, training days, connect the Mac bridge).
/// Design: design/source/src/Welcome.html, Goal.html, Days.html, Connect.html
struct OnboardingFlow: View {
    enum Step: Hashable { case goal, days, connect }

    var onFinish: () -> Void
    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(onStart: { path.append(.goal) }, onSignIn: onFinish)
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .goal: GoalView { path.append(.days) }
                    case .days: DaysView { path.append(.connect) }
                    case .connect: ConnectView(onFinish: onFinish)
                    }
                }
        }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    var onStart: () -> Void = {}
    var onSignIn: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                DivAvatar(size: 34)
                Text("azfit").font(.az(26, .black)).tracking(-1.4)
            }
            .padding(.horizontal, 4)
            .padding(.top, 14)

            changesCard.padding(.top, 20)

            VStack(alignment: .leading, spacing: 12) {
                Text("A coach that\nactually adjusts.").font(.az(36, .heavy)).tracking(-0.9)
                Text("Div plans every set and meal, then tunes the plan as your body responds.")
                    .font(.az(15.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.top, 30)

            Spacer(minLength: 16)

            VStack(spacing: 6) {
                PrimaryButton(title: "Get started", trailingImage: "arrow.right", action: onStart)
                Button("I already have an account", action: onSignIn)
                    .font(.az(15, .semibold)).foregroundStyle(AZColor.muted).frame(height: 40).buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .azScreen()
    }

    private var changesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                DivAvatar(size: 56)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hi, I'm Div.").font(.az(17, .heavy))
                    Text("Your AI coach.").font(.az(14)).foregroundStyle(AZColor.divMuted)
                }
            }
            VStack(spacing: 10) {
                example("flame.fill", "Raised calories") {
                    HStack(spacing: 4) {
                        WasValue(value: "2,200")
                        Text("→ 2,350 kcal")
                    }.monospacedDigit()
                }
                example("arrow.left.arrow.right", "Swapped a lift") { Text("For your tight shoulder") }
                example("calendar", "Moved a session") { Text("Upper A, to Sunday") }
            }
            .padding(.top, 28)
            Spacer(minLength: 12)
            Text("Every change is marked, explained and undoable.").font(.az(13)).foregroundStyle(AZColor.divMuted)
        }
        .padding(EdgeInsets(top: 24, leading: 22, bottom: 20, trailing: 22))
        .frame(height: 372)
        .background(AZColor.divTint, in: .rect(cornerRadius: 36, style: .continuous))
    }

    private func example<Detail: View>(_ systemImage: String, _ title: String, @ViewBuilder detail: () -> Detail) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AZColor.accent)
                .frame(width: 36, height: 36)
                .background(AZColor.divTint, in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(title).font(.az(14.5, .bold))
                    DivMark(size: 16)
                }
                detail().font(.az(13)).foregroundStyle(AZColor.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("Undo").font(.az(13.5, .bold)).foregroundStyle(AZColor.divInk)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(AZColor.card, in: .rect(cornerRadius: 20, style: .continuous))
        .shadow(color: AZColor.navShadow, radius: 10, y: 6)
    }
}

// MARK: - Shared step chrome

/// Back button, progress bar and a trailing link, then the "Step n of 3" title block.
private struct StepHeader: View {
    var progress: Double
    var trailing: String
    var trailingIsLink = true
    var onTrailing: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            BackButton()
            ProgressBar(value: progress).padding(.horizontal, 6)
            Button(trailing, action: onTrailing)
                .font(.az(15, .semibold))
                .foregroundStyle(trailingIsLink ? AZColor.muted : AZColor.faint)
                .monospacedDigit()
                .padding(.horizontal, 4)
                .buttonStyle(.plain)
                .disabled(!trailingIsLink)
        }
        .frame(height: 44)
        .padding(.top, 6)
    }

    private struct ProgressBar: View {
        var value: Double
        var body: some View { MeterBar(value: value, height: 6) }
    }
}

private struct StepTitle: View {
    var step: Int
    var title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(step) of 3").font(.az(14, .semibold)).foregroundStyle(AZColor.accent)
            Text(title).font(.az(34, .heavy)).tracking(-0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Goal

struct GoalView: View {
    var onContinue: () -> Void = {}
    @State private var pick = 0

    private let options = [
        ("flame.fill", "Lose fat", "About 0.4 kg a week, keep muscle"),
        ("dumbbell", "Build muscle", "Lean gain with a small surplus"),
        ("dumbbell.fill", "Get stronger", "Bigger numbers on the main lifts"),
        ("heart.fill", "Feel healthier", "Move well, sleep well, eat well"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(progress: 0.33, trailing: "Skip", onTrailing: onContinue)
            StepTitle(step: 1, title: "What's your\nmain goal?").padding(.top, 22)
            VStack(spacing: 10) {
                ForEach(options.indices, id: \.self) { i in option(i) }
            }
            .padding(.top, 28)
            HStack(spacing: 12) {
                DivAvatar(size: 36)
                Text("I'll build your whole plan around this.\nYou can change it any time.")
                    .font(.az(14.5)).foregroundStyle(AZColor.muted).lineSpacing(1.5)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.top, 22)
            Spacer(minLength: 16)
            PrimaryButton(title: "Continue", trailingImage: "arrow.right", action: onContinue).padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .azScreen()
    }

    private func option(_ i: Int) -> some View {
        let isOn = pick == i
        let (icon, title, subtitle) = options[i]
        return Button {
            withAnimation(.snappy(duration: 0.2)) { pick = i }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? AZColor.accent : AZColor.ink)
                    .frame(width: 46, height: 46)
                    .background(AZColor.card, in: .rect(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.az(16.5, .bold))
                    Text(subtitle).font(.az(13.5)).foregroundStyle(isOn ? AZColor.divMuted : AZColor.muted)
                }
                Spacer(minLength: 0)
                CheckBox(isOn: isOn)
            }
            .padding(.leading, 14)
            .padding(.trailing, 18)
            .frame(height: 76)
            .background(isOn ? AZColor.divTint : AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay {
                if isOn { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(AZColor.accent, lineWidth: 2) }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A rounded-square check: empty outline, or purple with a white check. Never a radio circle (D-013).
struct CheckBox: View {
    var isOn: Bool
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size / 3, style: .continuous)
            .fill(isOn ? AZColor.accent : .clear)
            .strokeBorder(isOn ? .clear : AZColor.ghost, lineWidth: 2)
            .frame(width: size, height: size)
            .overlay {
                if isOn { Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .heavy)).foregroundStyle(.white) }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Days

struct DaysView: View {
    var onContinue: () -> Void = {}
    @State private var days = 4

    private static let splits = [
        2: "Full body, twice a week", 3: "Full body A, B and C", 4: "Push, Pull, Legs, Upper", 5: "Push, Pull, Legs, Upper, Lower",
        6: "Push, Pull, Legs, twice",
    ]
    private static let pattern: [Int: Set<Int>] = [
        2: [0, 3], 3: [0, 2, 4], 4: [0, 1, 3, 5], 5: [0, 1, 2, 4, 5], 6: [0, 1, 2, 3, 4, 5],
    ]

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(progress: 0.66, trailing: "Skip", onTrailing: onContinue)
            StepTitle(step: 2, title: "How often can\nyou train?").padding(.top, 22)
            Text("\(days)")
                .font(.az(150, .heavy)).tracking(-9).monospacedDigit()
                .contentTransition(.numericText(value: Double(days)))
                .frame(height: 150)
                .padding(.top, 12)
            Text("days a week").font(.az(15.5, .semibold)).foregroundStyle(AZColor.muted).padding(.top, 6)
            HStack(spacing: 8) {
                ForEach(2...6, id: \.self) { n in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { days = n }
                    } label: {
                        Text("\(n)")
                            .font(.az(20, .heavy))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .foregroundStyle(n == days ? AZColor.buttonInk : AZColor.ink)
                            .background(n == days ? AZColor.button : AZColor.fill, in: .rect(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n) days a week")
                    .accessibilityAddTraits(n == days ? .isSelected : [])
                }
            }
            .padding(.top, 24)
            splitCard.padding(.top, 26)
            Spacer(minLength: 16)
            PrimaryButton(title: "Continue", trailingImage: "arrow.right", action: onContinue).padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .azScreen()
    }

    private var splitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                DivAvatar(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.splits[days] ?? "").font(.az(15, .bold))
                    Text("About 50 min each. Miss a day and I'll move it for you.")
                        .font(.az(14)).foregroundStyle(AZColor.divMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 6) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { i, letter in
                    let isOn = Self.pattern[days]?.contains(i) ?? false
                    Text(letter)
                        .font(.az(12, .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(isOn ? Color.white : AZColor.faint)
                        .background(isOn ? AZColor.accent : AZColor.card, in: .rect(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 16, trailing: 16))
        .background(AZColor.divTint, in: .rect(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Connect

struct ConnectView: View {
    var onFinish: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(progress: 1, trailing: "3 / 3", trailingIsLink: false)
            VStack(alignment: .leading, spacing: 8) {
                StepTitle(step: 3, title: "Connect Div")
                Text("Div runs on your Claude plan through AZfit Bridge, a free app on your Mac. No extra AI bill.")
                    .font(.az(15.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
            }
            .padding(.top, 22)

            HStack(alignment: .top, spacing: 0) {
                device("iphone", "This iPhone")
                HStack(spacing: 0) {
                    DashedLink()
                    DivAvatar(size: 40)
                    DashedLink()
                }
                .frame(height: 76)
                device("laptopcomputer", "MacBook Pro")
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)

            VStack(spacing: 0) {
                HairlineStack {
                    step("Install AZfit Bridge on your Mac")
                    step("Sign in to Claude Code")
                    step("Pair with the code on screen")
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 22)

            HStack(spacing: 12) {
                Image(systemName: "wifi")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AZColor.accent, in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Connected · Claude Opus").font(.az(15, .bold))
                    Text("Div replies in about 2 seconds").font(.az(13.5)).foregroundStyle(AZColor.divMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
            .background(AZColor.divTint, in: .rect(cornerRadius: 22, style: .continuous))
            .padding(.top, 20)

            HStack(spacing: 8) {
                Image(systemName: "lock").font(.system(size: 13, weight: .semibold)).foregroundStyle(AZColor.faint)
                Text("Your logs and photos stay on your Mac.").font(.az(13.5)).foregroundStyle(AZColor.muted)
            }
            .padding(.horizontal, 4)
            .padding(.top, 16)

            Spacer(minLength: 16)
            PrimaryButton(title: "Start training", trailingImage: "arrow.right", action: onFinish).padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .azScreen()
    }

    private func device(_ systemImage: String, _ name: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .frame(width: 76, height: 76)
                .background(AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
            Text(name).font(.az(13, .semibold)).fixedSize()
        }
        .frame(width: 76)
    }

    private func step(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(AZColor.accent)
                .frame(width: 26, height: 26)
                .background(AZColor.divTint, in: .rect(cornerRadius: 9, style: .continuous))
            Text(text).font(.az(15, .semibold))
            Spacer(minLength: 0)
        }
        .frame(height: 54)
    }

    private struct DashedLink: View {
        var body: some View {
            Line()
                .stroke(AZColor.accentSoft, style: StrokeStyle(lineWidth: 2, lineCap: .butt, dash: [6, 6]))
                .frame(height: 2)
                .padding(.horizontal, 8)
        }

        struct Line: Shape {
            func path(in rect: CGRect) -> Path {
                Path { p in
                    p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                }
            }
        }
    }
}

#Preview("Welcome") { WelcomeView() }
#Preview("Goal") { NavigationStack { GoalView() } }
#Preview("Days") { NavigationStack { DaysView() } }
#Preview("Connect") { NavigationStack { ConnectView() } }
