import AZMath
import AZModel
import AZStore
import SwiftUI

/// Typing a meal in: a name, calories and macros. Calories come from the macros when left empty, and a meal logged
/// before fills everything in with one tap.
struct DescribeMealView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var problem: String?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name, kcal, protein, carbs, fat }

    var body: some View {
        let recent = (try? environment.store.recentMeals()) ?? []
        VStack(spacing: 0) {
            TopBar(title: "Describe a meal", subtitle: mealTime) {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    entry("What was it", text: $name, prompt: "Chicken wrap", field: .name)
                    entry("Calories", text: $kcal, prompt: fromMacros.map { "\($0.grouped) from the macros" } ?? "kcal", field: .kcal)
                        .padding(.top, 16)
                    HStack(spacing: 10) {
                        entry("Protein g", text: $protein, prompt: "0", field: .protein)
                        entry("Carbs g", text: $carbs, prompt: "0", field: .carbs)
                        entry("Fat g", text: $fat, prompt: "0", field: .fat)
                    }
                    .padding(.top, 16)
                    if let problem {
                        Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 12)
                    }
                    if !recent.isEmpty {
                        SectionHeader(title: "Logged before", note: "Tap to fill in").padding(.top, 30)
                        HairlineStack {
                            ForEach(recent, id: \.meal.id) { recentRow($0) }
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: totals.map { "Log \($0.kcal.grouped) kcal" } ?? "Log meal") { log() }
                .disabled(!canLog)
                .opacity(canLog ? 1 : 0.4)
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
                .background(AZColor.background)
        }
        .azScreen()
        .onAppear { focus = .name }
    }

    /// "Lunch", from the time of day.
    private var mealTime: String { Meal.mealTime(at: .now) }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The meal's totals, when every field reads as a number (D-010: the math is `MealMath`'s).
    private var totals: MealTotals? {
        guard let kcal = Self.number(kcal), let protein = Self.number(protein), let carbs = Self.number(carbs),
            let fat = Self.number(fat)
        else { return nil }
        return MealMath.typed(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat)
    }

    /// What the macros add up to, shown in the empty calories field.
    private var fromMacros: Int? {
        guard Self.number(kcal) == .some(nil) else { return nil }
        return totals?.kcal
    }

    private var canLog: Bool { !trimmedName.isEmpty && totals != nil }

    private func entry(_ label: String, text: Binding<String>, prompt: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: label)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(AZColor.faint))
                .font(.az(17, .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .keyboardType(field == .name ? .default : .decimalPad)
                .textInputAutocapitalization(field == .name ? .sentences : .never)
                .focused($focus, equals: field)
                .submitLabel(.next)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
                .onChange(of: text.wrappedValue) { problem = nil }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recentRow(_ recent: RecentMeal) -> some View {
        Button {
            fill(recent.meal)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(recent.meal.name).font(.az(16, .bold)).lineLimit(1)
                    Text(Self.macros(recent.meal)).font(.az(14)).foregroundStyle(AZColor.muted).monospacedDigit()
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Int(recent.meal.kcal.rounded()).grouped).font(.az(16, .bold)).monospacedDigit()
                    if recent.times > 1 {
                        Text("\(recent.times) times").font(.az(13)).foregroundStyle(AZColor.muted)
                    }
                }
            }
            .frame(minHeight: 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func fill(_ meal: Meal) {
        name = meal.name
        kcal = "\(Int(meal.kcal.rounded()))"
        protein = Self.trimmed(meal.proteinG)
        carbs = Self.trimmed(meal.carbsG)
        fat = Self.trimmed(meal.fatG)
        focus = nil
    }

    private func log() {
        guard let totals, !trimmedName.isEmpty else {
            problem = "Add a name and either calories or macros."
            return
        }
        let meal = Meal(
            day: environment.today, name: trimmedName, kcal: Double(totals.kcal), proteinG: totals.proteinG, carbsG: totals.carbsG,
            fatG: totals.fatG, source: .typed)
        do {
            try environment.store.logMeal(meal)
            environment.changed()
            router.show(.eat)
        } catch {
            problem = "Couldn't save it: \(error.localizedDescription)"
        }
    }

    /// A typed number: `.some(nil)` when empty, nil when it isn't a number.
    private static func number(_ text: String) -> Double?? {
        let text = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if text.isEmpty { return .some(nil) }
        return Double(text).map { .some($0) } ?? nil
    }

    /// "P 35 · C 50 · F 20"
    static func macros(_ meal: Meal) -> String {
        "P \(trimmed(meal.proteinG)) · C \(trimmed(meal.carbsG)) · F \(trimmed(meal.fatG))"
    }

    private static func trimmed(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack { DescribeMealView() }.environment(Router()).environment(AppEnvironment.preview())
}
