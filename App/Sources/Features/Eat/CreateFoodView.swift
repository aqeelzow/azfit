import AZMath
import AZModel
import AZStore
import SwiftUI

/// Making a food from its label: per serving, kept in My foods. A barcode that wasn't found comes along, so
/// scanning the package finds this food next time.
struct CreateFoodView: View {
    let slot: Meal.Slot
    let barcode: String?

    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var name = ""
    @State private var brand = ""
    @State private var serving = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var problem: String?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name, brand, serving, kcal, protein, carbs, fat }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Create food", subtitle: barcode.map { "Barcode \($0)" }) {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    entry("Name", text: $name, prompt: "Chicken wrap", field: .name)
                    HStack(spacing: 10) {
                        entry("Brand (optional)", text: $brand, prompt: "Homemade", field: .brand)
                        entry("Serving", text: $serving, prompt: "1 serving", field: .serving)
                    }
                    SectionLabel(text: "Per serving").padding(.top, 6)
                    entry("Calories", text: $kcal, prompt: fromMacros.map { "\($0.grouped) from the macros" } ?? "kcal", field: .kcal)
                    HStack(spacing: 10) {
                        entry("Protein g", text: $protein, prompt: "0", field: .protein)
                        entry("Carbs g", text: $carbs, prompt: "0", field: .carbs)
                        entry("Fat g", text: $fat, prompt: "0", field: .fat)
                    }
                    if let problem {
                        Text(problem).font(.az(14)).foregroundStyle(AZColor.muted)
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
            PrimaryButton(title: "Save food") { save() }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
                .background(AZColor.background)
        }
        .azScreen()
        .onAppear { focus = .name }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var totals: MealTotals? {
        guard let kcal = DescribeMealView.number(kcal), let protein = DescribeMealView.number(protein),
            let carbs = DescribeMealView.number(carbs), let fat = DescribeMealView.number(fat)
        else { return nil }
        return MealMath.typed(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat)
    }

    private var fromMacros: Int? {
        guard DescribeMealView.number(kcal) == .some(nil) else { return nil }
        return totals?.kcal
    }

    private var canSave: Bool { !trimmedName.isEmpty && totals != nil }

    private func entry(_ label: String, text: Binding<String>, prompt: String, field: Field) -> some View {
        let isText = field == .name || field == .brand || field == .serving
        return VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: label)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(AZColor.faint))
                .font(.az(17, .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .keyboardType(isText ? .default : .decimalPad)
                .textInputAutocapitalization(isText ? .sentences : .never)
                .focused($focus, equals: field)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
                .onChange(of: text.wrappedValue) { problem = nil }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        guard let totals, !trimmedName.isEmpty else {
            problem = "Add a name and either calories or macros."
            return
        }
        let label = serving.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let food = CustomFood(
            name: trimmedName, brand: brand.isEmpty ? nil : brand, servingLabel: label.isEmpty ? "1 serving" : label,
            kcal: Double(totals.kcal), proteinG: totals.proteinG, carbsG: totals.carbsG, fatG: totals.fatG, barcode: barcode)
        do {
            try environment.store.saveCustomFood(food)
            router.replaceTop(with: .food(food.food, slot))
        } catch {
            problem = "Couldn't save it: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack { CreateFoodView(slot: .lunch, barcode: "0123456789012") }
        .environment(Router()).environment(AppEnvironment.preview())
}
