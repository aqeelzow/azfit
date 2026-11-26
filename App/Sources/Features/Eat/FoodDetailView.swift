import AZModel
import AZStore
import SwiftUI

/// One food: how much, in servings or grams, and which meal it goes to. The totals update as you type.
struct FoodDetailView: View {
    let food: Food

    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var slot: Meal.Slot
    @State private var unit: Food.Unit
    @State private var amount: String
    @State private var problem: String?
    @FocusState private var amountFocused: Bool

    init(food: Food, slot: Meal.Slot) {
        self.food = food
        let unit = food.units.first ?? .grams
        _slot = State(initialValue: slot)
        _unit = State(initialValue: unit)
        _amount = State(initialValue: Food.trim(food.defaultAmount(in: unit)))
    }

    private var value: Double? {
        Double(amount.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private var nutrients: Nutrients? { value.flatMap { food.nutrients($0, unit) } }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "", subtitle: nil) {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !food.detail.isEmpty { SectionLabel(text: food.detail) }
                    Text(food.name).font(.az(30, .heavy)).tracking(-0.7).padding(.top, 2)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Int((nutrients?.kcal ?? 0).rounded()).grouped).font(.az(52, .heavy)).tracking(-2).monospacedDigit()
                        Text("kcal").font(.az(17, .bold)).foregroundStyle(AZColor.muted)
                    }
                    .padding(.top, 18)
                    HStack(spacing: 8) {
                        macro("Protein", nutrients?.proteinG)
                        macro("Carbs", nutrients?.carbsG)
                        macro("Fat", nutrients?.fatG)
                    }
                    .padding(.top, 10)

                    SectionLabel(text: "How much").padding(.top, 26)
                    HStack(spacing: 10) {
                        TextField("", text: $amount, prompt: Text("0").foregroundStyle(AZColor.faint))
                            .keyboardType(.decimalPad)
                            .font(.az(20, .heavy))
                            .monospacedDigit()
                            .focused($amountFocused)
                            .padding(.horizontal, 16)
                            .frame(width: 110, height: 54)
                            .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
                            .accessibilityLabel("Amount")
                        if food.units.count > 1 {
                            ForEach(food.units, id: \.self) { option in
                                Chip(title: option == .grams ? "grams" : servingName, isOn: option == unit) { switchUnit(to: option) }
                            }
                        } else {
                            Text(unit == .grams ? "grams" : servingName).font(.az(16, .bold)).foregroundStyle(AZColor.muted)
                        }
                    }
                    .padding(.top, 8)

                    SectionLabel(text: "Meal").padding(.top, 22)
                    SlotPicker(slot: $slot).padding(.top, 8)

                    let micros = Micronutrient.allCases.compactMap { m in nutrients?.micros[m.rawValue].map { (m, $0) } }
                    if !micros.isEmpty {
                        SectionHeader(title: "Micronutrients", note: "% of daily value").padding(.top, 28)
                        HairlineStack {
                            ForEach(micros, id: \.0) { micro, amount in
                                HStack {
                                    Text(micro.title).font(.az(15, .semibold))
                                    Spacer()
                                    Text("\(Food.trim((amount * 10).rounded() / 10)) \(micro.unit)")
                                        .font(.az(15)).foregroundStyle(AZColor.muted).monospacedDigit()
                                    Text("\(Int((amount / micro.dailyValue * 100).rounded()))%")
                                        .font(.az(15, .bold)).monospacedDigit().frame(width: 52, alignment: .trailing)
                                }
                                .frame(minHeight: 44)
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if let problem {
                        Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 14)
                    }
                    if food.origin == .database {
                        Text("From Open Food Facts. Labels vary, so check it against the package if it looks off.")
                            .font(.az(13)).foregroundStyle(AZColor.faint).padding(.top, 24)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: nutrients.map { "Log \(Int($0.kcal.rounded()).grouped) kcal to \(slot.title)" } ?? "Log") { log() }
                .disabled(nutrients == nil)
                .opacity(nutrients == nil ? 0.4 : 1)
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
                .background(AZColor.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }.font(.az(16, .bold))
            }
        }
        .azScreen()
    }

    /// "servings", or "1 bar" style labels kept short.
    private var servingName: String {
        guard let label = food.serving?.label, label.count <= 14 else { return "servings" }
        return label
    }

    private func macro(_ name: String, _ grams: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.az(13, .semibold)).foregroundStyle(AZColor.muted)
            Text("\(Food.trim(((grams ?? 0) * 10).rounded() / 10)) g").font(.az(18, .heavy)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Keeps the same amount of food: 1 serving of 60 g becomes 60 g.
    private func switchUnit(to new: Food.Unit) {
        guard new != unit else { return }
        let grams = food.serving?.grams
        if let value, let grams {
            amount = Food.trim(((new == .grams ? value * grams : value / grams) * 100).rounded() / 100)
        } else {
            amount = Food.trim(food.defaultAmount(in: new))
        }
        unit = new
    }

    private func log() {
        guard let value, let meal = food.meal(value, unit, day: environment.today, slot: slot) else { return }
        var named = meal
        named.name = "\(food.name), \(food.amountLabel(value, unit))"
        do {
            try environment.store.logMeal(named)
            environment.changed()
            router.show(.eat)
        } catch {
            problem = "Couldn't save it: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        FoodDetailView(
            food: Food(
                id: "off:1", name: "Greek yogurt", brand: "Fage", barcode: "1", per100g: .init(kcal: 97, proteinG: 9, carbsG: 3.9, fatG: 5),
                serving: .init(label: "1 pot", grams: 170), origin: .database),
            slot: .breakfast)
    }
    .environment(Router()).environment(AppEnvironment.preview())
}
