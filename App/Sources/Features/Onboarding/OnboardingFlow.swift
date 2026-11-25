import AZMath
import AZModel
import SwiftUI

/// First run: Welcome, then four steps (goal, training days, about you, connect the Mac bridge). Finishing saves
/// the person, their starting targets and a plan from the template for their days (D-028).
/// Design: design/source/src/Welcome.html, Goal.html, Days.html, Connect.html. About you has no design yet.
struct OnboardingFlow: View {
    enum Step: Hashable { case goal, days, about, connect }

    var onFinish: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @State private var path: [Step] = []
    @State private var answers = OnboardingAnswers()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(onStart: { path.append(.goal) }, onSignIn: onFinish)
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .goal: GoalView(pick: $answers.goalPick) { path.append(.days) }
                    case .days: DaysView(days: $answers.days) { path.append(.about) }
                    case .about: AboutYouView(answers: $answers) { path.append(.connect) }
                    case .connect:
                        ConnectView {
                            environment.finishOnboarding(answers.profile, weightKg: answers.weightKg)
                            onFinish()
                        }
                    }
                }
        }
    }
}

/// What onboarding has asked so far. Stored metric, shown in the person's units.
struct OnboardingAnswers {
    var goalPick = 0
    var days = 4
    var units = UnitSystem.canadian
    var sex: Sex?
    var age = 30
    var heightCm = 175.26  // 5' 9"
    var weightKg = 77.0

    /// The Goal screen's four choices. Strength and health map onto the three goals Div plans for.
    var goal: Goal { [Goal.cut, .build, .build, .recomp][goalPick] }

    var profile: Profile {
        let year = Calendar.current.component(.year, from: .now)
        return Profile(
            sex: sex, birthYear: year - age, heightCm: heightCm, goal: goal, trainingDays: days, units: units)
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

/// Back button, progress bar and a trailing link, then the "Step n of 4" title block.
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
            Text("Step \(step) of 4").font(.az(14, .semibold)).foregroundStyle(AZColor.accent)
            Text(title).font(.az(34, .heavy)).tracking(-0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Goal

struct GoalView: View {
    @Binding var pick: Int
    var onContinue: () -> Void = {}

    private let options = [
        ("flame.fill", "Lose fat", "About 0.4 kg a week, keep muscle"),
        ("dumbbell", "Build muscle", "Lean gain with a small surplus"),
        ("dumbbell.fill", "Get stronger", "Bigger numbers on the main lifts"),
        ("heart.fill", "Feel healthier", "Move well, sleep well, eat well"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(progress: 0.25, trailing: "Skip", onTrailing: onContinue)
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
    @Binding var days: Int
    var onContinue: () -> Void = {}

    /// From the templates, so the screen shows the plan the person will get.
    private static let splits = PlanTemplate.splitNames
    private static let pattern = PlanTemplate.trainingWeekdays.mapValues { Set($0.map { $0 - 1 }) }

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(progress: 0.5, trailing: "Skip", onTrailing: onContinue)
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

// MARK: - About you

/// Units, and what the calorie floor and starting targets need: sex, age, height, weight.
struct AboutYouView: View {
    @Binding var answers: OnboardingAnswers
    var onContinue: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(progress: 0.75, trailing: "Skip", onTrailing: onContinue)
            StepTitle(step: 3, title: "About you").padding(.top, 22)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    choices("Units", UnitSystem.allCases, selection: answers.units, name: \.name) { answers.units = $0 }
                    choices("For your calorie target", Sex.allCases, selection: answers.sex, name: { $0 == .female ? "Female" : "Male" }) {
                        answers.sex = $0
                    }
                    HairlineStack {
                        stepper(
                            "Age", "\(answers.age)", minus: { answers.age = max(14, answers.age - 1) },
                            plus: { answers.age = min(99, answers.age + 1) })
                        stepper(
                            "Height", answers.units.height(answers.heightCm),
                            minus: { answers.heightCm = max(120, answers.heightCm - UnitSystem.cmPerInch) },
                            plus: { answers.heightCm = min(230, answers.heightCm + UnitSystem.cmPerInch) })
                        stepper(
                            "Weight", answers.units.bodyWeight(answers.weightKg),
                            minus: { answers.weightKg = max(35, answers.weightKg - weightStep) },
                            plus: { answers.weightKg = min(250, answers.weightKg + weightStep) })
                    }
                    HStack(spacing: 12) {
                        DivAvatar(size: 36)
                        Text("I use these for your first calorie target and the floor I'll never go below.")
                            .font(.az(14.5)).foregroundStyle(AZColor.muted).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.top, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(title: "Continue", trailingImage: "arrow.right", action: onContinue).padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
        .azScreen()
    }

    /// One pound, or half a kilogram.
    private var weightStep: Double {
        answers.units.bodyWeight == .kg ? 0.5 : 1 / UnitSystem.poundsPerKg
    }

    private func choices<T: Hashable>(
        _ title: String, _ options: [T], selection: T?, name: @escaping (T) -> String, choose: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title).padding(.horizontal, 4)
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isOn = option == selection
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { choose(option) }
                    } label: {
                        Text(name(option))
                            .font(.az(15, .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(isOn ? AZColor.buttonInk : AZColor.ink)
                            .background(isOn ? AZColor.button : AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    private func stepper(_ title: String, _ value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.az(15.5, .semibold))
            Spacer(minLength: 8)
            IconButton(systemImage: "minus", label: "Less \(title.lowercased())", size: 40, action: minus)
            Text(value).font(.az(16, .bold)).monospacedDigit().frame(minWidth: 92)
                .contentTransition(.numericText())
            IconButton(systemImage: "plus", label: "More \(title.lowercased())", size: 40, action: plus)
        }
        .frame(height: 60)
    }
}

// MARK: - Connect

struct ConnectView: View {
    @Environment(AppEnvironment.self) private var environment
    var onFinish: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(progress: 1, trailing: "4 / 4", trailingIsLink: false)
            VStack(alignment: .leading, spacing: 8) {
                StepTitle(step: 4, title: "Connect Div")
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
                device("laptopcomputer", environment.bridge.bridgeName ?? "Your Mac")
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)

            MacPairingPanel()
                .padding(.top, 22)

            HStack(spacing: 8) {
                Image(systemName: "lock").font(.system(size: 13, weight: .semibold)).foregroundStyle(AZColor.faint)
                Text("Your logs and photos stay on your Mac.").font(.az(13.5)).foregroundStyle(AZColor.muted)
            }
            .padding(.horizontal, 4)
            .padding(.top, 16)

            Spacer(minLength: 16)
            PrimaryButton(
                title: environment.bridge.code == nil ? "Skip for now" : "Start training", trailingImage: "arrow.right",
                style: environment.bridge.code == nil ? .soft : .dark, action: onFinish
            )
            .padding(.bottom, 8)
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

    private struct DashedLink: View {
        var body: some View {
            Line()
                .stroke(AZColor.accentSoft, style: StrokeStyle(lineWidth: 2, lineCap: .butt, dash: [6, 6]))
                .frame(height: 2)
                .padding(.horizontal, 8)
        }

        nonisolated struct Line: Shape {
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
#Preview("Goal") { NavigationStack { GoalView(pick: .constant(0)) } }
#Preview("Days") { NavigationStack { DaysView(days: .constant(4)) } }
#Preview("About you") { NavigationStack { AboutYouView(answers: .constant(OnboardingAnswers())) } }
#Preview("Connect") { NavigationStack { ConnectView() }.environment(AppEnvironment.preview()) }
