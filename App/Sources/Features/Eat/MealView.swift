import SwiftUI

/// A meal estimate with its uncertainty. Div asks the one question that narrows it most (was there dressing?), and
/// the answer tightens the range from ±18% to ±9%. Design: design/source/src/Meal.html
///
/// The numbers here are hard-coded samples. In the real app the estimate and range come from AZMath (D-010).
struct MealView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var answer: Answer?

    enum Answer: CaseIterable {
        case none, little, lots

        var title: String {
            switch self {
            case .none: "None"
            case .little: "A little"
            case .lots: "A lot"
            }
        }

        var kcal: Int {
            switch self {
            case .none: 560
            case .little: 625
            case .lots: 735
            }
        }

        var dressing: (amount: String, kcal: Int)? {
            switch self {
            case .none: nil
            case .little: ("1 tbsp", 85)
            case .lots: ("3 tbsp", 195)
            }
        }

        var reason: String {
            switch self {
            case .none: "No dressing, so I took out the 80 kcal I had guessed for it."
            case .little: "About a tablespoon of sesame dressing. It is in the breakdown now."
            case .lots: "About 3 tablespoons of sesame dressing. It is in the breakdown now."
            }
        }
    }

    private var kcal: Int { answer?.kcal ?? 640 }
    private var percent: Int { answer == nil ? 18 : 9 }
    private var low: Int { Self.roundTo5(Double(kcal) * (1 - Double(percent) / 100)) }
    private var high: Int { Self.roundTo5(Double(kcal) * (1 + Double(percent) / 100)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Salmon power bowl").font(.az(22, .heavy)).tracking(-0.44)
                        Text("Lunch · 1:12 PM").font(.az(14)).foregroundStyle(AZColor.muted)
                    }
                    .padding(.top, 18)
                    estimate.padding(.top, 14)
                    ladder.padding(.top, 20)
                    note.padding(.top, 18).animation(.snappy(duration: 0.22), value: answer)
                    breakdown.padding(.top, 18)
                }
                .padding(.horizontal, AZSpacing.gutter)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Log \(kcal.formatted()) kcal") { router.show(.eat) }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
                .background(AZColor.background)
        }
        .azScreen()
    }

    private var header: some View {
        Image("salmon")
            .resizable()
            .scaledToFill()
            .frame(height: 196)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [AZColor.Camera.shade.opacity(0.45), AZColor.Camera.shade.opacity(0)], startPoint: .top, endPoint: .bottom
                )
                .frame(height: 120)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
            .overlay(alignment: .bottom) {
                HStack {
                    darkButton("chevron.left", "Back") { dismiss() }
                    Spacer()
                    darkButton("ellipsis", "Ask Div about this meal") { router.push(.chat) }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 196 - 56 - 44)
            }
            .accessibilityLabel("Salmon power bowl")
    }

    private func darkButton(_ systemImage: String, _ label: String, action: @escaping () -> Void) -> some View {
        IconButton(systemImage: systemImage, label: label, background: AZColor.Camera.scrim, foreground: .white, action: action)
    }

    private var estimate: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(kcal.formatted()).font(.az(48, .heavy)).tracking(-1.9).contentTransition(.numericText(value: Double(kcal)))
                    Text(" kcal").font(.az(16, .semibold)).foregroundStyle(AZColor.muted)
                }
                Spacer()
                Text("± \(percent)%")
                    .font(.az(14, .bold)).foregroundStyle(AZColor.divInk)
                    .padding(.horizontal, 12).frame(height: 30)
                    .background(AZColor.divTint, in: .capsule)
                    .padding(.bottom, 6)
            }
            .monospacedDigit()
            RangeBar(low: low, high: high, value: kcal).padding(.top, 14)
            Text("Likely \(low) to \(high) kcal").font(.az(13, .semibold)).foregroundStyle(AZColor.muted).monospacedDigit().padding(.top, 7)
        }
        .animation(.snappy(duration: 0.3), value: kcal)
    }

    /// How sure the estimate is: photo, then your answer, then weighing it.
    private var ladder: some View {
        HStack(spacing: 8) {
            rung("Photo", 18, done: true)
            rung("Your answer", 9, done: answer != nil)
            rung("Weighed", 4, done: false)
        }
    }

    private func rung(_ label: String, _ percent: Int, done: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().fill(done ? AZColor.accent : AZColor.track).frame(height: 6)
            HStack(spacing: 5) {
                Text(label).foregroundStyle(done ? AZColor.ink : AZColor.faint)
                Text("± \(percent)%").foregroundStyle(AZColor.faint)
            }
            .font(.az(13, .semibold))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var note: some View {
        if let answer {
            HStack(alignment: .top, spacing: 12) {
                DivAvatar(size: 36, mood: .proud)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Updated to \(answer.kcal.formatted())").font(.az(15, .bold))
                        WasValue(value: "640").font(.az(15))
                    }
                    .monospacedDigit()
                    Text(answer.reason).font(.az(14)).foregroundStyle(AZColor.divMuted).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        PillButton(title: "Undo", systemImage: "arrow.uturn.backward") { self.answer = nil }
                        PillButton(title: "Weigh it for ± 4%", systemImage: "scalemass") {}
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
            .background(AZColor.divTint, in: .rect(cornerRadius: 24, style: .continuous))
            .transition(.opacity)
        } else {
            DivNote(title: "Was there dressing?", message: "It looks glossy, and dressing is the biggest unknown in a bowl like this.") {
                ForEach(Answer.allCases, id: \.self) { option in
                    PillButton(title: option.title) { answer = option }
                }
            }
            .transition(.opacity)
        }
    }

    private var breakdown: some View {
        HairlineStack {
            item("Seared salmon", "130 g", 270)
            item("Edamame, corn", "110 g", 150)
            item("Eggs, vegetables", "200 g", 120)
            if let answer {
                if let dressing = answer.dressing { item("Sesame dressing", dressing.amount, dressing.kcal, isNew: true) }
            } else {
                item("Dressing (guess)", "?", 100)
            }
        }
    }

    private func item(_ name: String, _ amount: String, _ kcal: Int, isNew: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(name).fontWeight(.semibold).foregroundStyle(isNew ? AZColor.divInk : AZColor.ink)
            Spacer()
            Text(amount).foregroundStyle(AZColor.muted).frame(width: 70, alignment: .trailing)
            Text("\(kcal)").fontWeight(.bold).foregroundStyle(isNew ? AZColor.divInk : AZColor.ink).frame(width: 52, alignment: .trailing)
        }
        .font(.az(15))
        .monospacedDigit()
        .frame(height: 36)
    }

    private static func roundTo5(_ value: Double) -> Int { Int((value / 5).rounded()) * 5 }
}

/// The likely range as a soft band on a 400 to 900 kcal track, with a tick at the estimate.
private struct RangeBar: View {
    var low: Int
    var high: Int
    var value: Int

    var body: some View {
        GeometryReader { geo in
            let x = { (kcal: Int) in geo.size.width * CGFloat(kcal - 400) / 500 }
            ZStack(alignment: .leading) {
                Capsule().fill(AZColor.track)
                Capsule().fill(AZColor.accentSoft.opacity(0.55)).frame(width: x(high) - x(low)).offset(x: x(low))
                RoundedRectangle(cornerRadius: 2).fill(AZColor.accent).frame(width: 4, height: 16).offset(x: x(value) - 2)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Likely \(low) to \(high) kcal")
    }
}

#Preview {
    NavigationStack { MealView() }.environment(Router())
}
