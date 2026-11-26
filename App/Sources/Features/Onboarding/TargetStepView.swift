import AZMath
import AZModel
import SwiftUI

/// Step 4: the starting calorie target with its working, from the answers so far. The same math is saved when
/// onboarding finishes (`Targets.startingBreakdown`, D-010), so what's shown is what the person gets. A binding, so
/// it always reads the latest answers rather than a copy taken when the step was built.
struct TargetStepView: View {
    @Binding var answers: OnboardingAnswers
    var onContinue: () -> Void = {}

    var body: some View {
        let profile = answers.profile
        let b = Targets.startingBreakdown(
            sex: answers.sex, weightKg: answers.weightKg, heightCm: answers.heightCm, age: answers.age, goal: answers.goal,
            ratePctPerWeek: profile.targetRatePctPerWeek)
        let macros = Targets.macroGrams(
            kcal: b.kcal, proteinGPerKg: Targets.startingProtein(goal: answers.goal), weightKg: answers.weightKg)
        VStack(spacing: 0) {
            StepHeader(progress: 0.8, trailing: "Skip", onTrailing: onContinue)
            StepTitle(step: 4, title: "Your starting\ntarget").padding(.top, 22)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(b.kcal.grouped).font(.az(64, .heavy)).tracking(-2.5).monospacedDigit()
                        Text("kcal a day").font(.az(17, .bold)).foregroundStyle(AZColor.muted)
                    }
                    .padding(.horizontal, 4)

                    HStack(spacing: 8) {
                        macro("Protein", macros.protein)
                        macro("Carbs", macros.carbs)
                        macro("Fat", macros.fat)
                    }
                    .padding(.top, 14)

                    SectionLabel(text: "How I got there").padding(.horizontal, 4).padding(.top, 26)
                    HairlineStack {
                        row(
                            "Resting burn", "\(b.bmr.grouped) kcal",
                            note: answers.sex == nil
                                ? "From your age, height and weight, between the male and female formulas"
                                : "From your age, height, weight and sex")
                        row("Daily life and training", "× 1.5", note: "Maintenance about \(b.maintenance.grouped) kcal")
                        row(goalTitle(b), signed(b.goalAdjustment), note: goalNote(b))
                        row(
                            b.heldAtFloor ? "Held at your floor" : "Rounded to the nearest 50", "\(b.kcal.grouped) kcal",
                            note: "I'll never set it below \(b.floor.grouped) kcal")
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                    DivNote(
                        title: "A starting point",
                        message: "Formulas guess. After two or three weeks of weigh-ins I'll check this against your scale and adjust it.",
                        tone: .settled
                    )
                    .padding(.top, 20)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(title: "Continue", trailingImage: "arrow.right", action: onContinue).padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
        .azScreen()
    }

    private func macro(_ name: String, _ grams: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.az(13, .semibold)).foregroundStyle(AZColor.muted)
            Text("\(grams) g").font(.az(18, .heavy)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func row(_ title: String, _ value: String, note: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.az(15.5, .bold))
                Text(note).font(.az(13.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(value).font(.az(16, .bold)).monospacedDigit()
        }
        .frame(minHeight: 64)
        .accessibilityElement(children: .combine)
    }

    private func goalTitle(_ b: Targets.StartingBreakdown) -> String {
        b.ratePctPerWeek < 0 ? "To lose weight" : b.ratePctPerWeek > 0 ? "To gain weight" : "To hold your weight"
    }

    /// "About 0.9 lb a week (0.5% of your weight)"
    private func goalNote(_ b: Targets.StartingBreakdown) -> String {
        guard b.ratePctPerWeek != 0 else { return "No change for a recomp: eat at maintenance" }
        let kg = abs(answers.weightKg * b.ratePctPerWeek / 100)
        let amount =
            answers.units.bodyWeight == .kg
            ? String(format: "%.1f kg", kg) : String(format: "%.1f lb", kg * UnitSystem.poundsPerKg)
        return "About \(amount) a week (\(String(format: "%g", abs(b.ratePctPerWeek)))% of your weight)"
    }

    private func signed(_ kcal: Int) -> String {
        kcal == 0 ? "0 kcal" : "\(kcal < 0 ? "-" : "+")\(abs(kcal).grouped) kcal"
    }
}
