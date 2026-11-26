import AZModel
import AZStore
import SwiftUI

/// Eat: calories left against the target, macros as bars, water, today's food by meal (each with its own add
/// button), and the day's micronutrients.
/// Design: design/source/src/Eat.html
struct EatView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var allMicros = false

    var body: some View {
        let food = try? environment.store.food(on: environment.today)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    LargeTitle(caption: AppEnvironment.caption(environment.today), title: "Eat")
                    Spacer()
                    IconButton(systemImage: "target", label: "Calorie target") { router.push(.calorieTarget) }
                }
                summary(food).padding(.top, 16)
                water(food).padding(.top, 12)
                let meals = food?.meals ?? []
                ForEach(Meal.Slot.allCases) { slot in
                    section(slot, meals.filter { $0.mealSlot == slot }).padding(.top, 22)
                }
                dayDone(food).padding(.top, 26)
                micronutrients(food).padding(.top, 30)
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func summary(_ food: FoodSummary?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(food?.leftKcal?.grouped ?? "-").font(.az(52, .heavy)).tracking(-2).monospacedDigit()
            Button {
                router.push(.calorieTarget)
            } label: {
                HStack(spacing: 4) {
                    if let target = food?.targetKcal {
                        Text("kcal left of").foregroundStyle(AZColor.divMuted)
                        Text(target.grouped).fontWeight(.bold).monospacedDigit()
                        if food?.targetByDiv == true { DivMark().padding(.leading, 1) }
                    } else {
                        Text("No calorie target yet").foregroundStyle(AZColor.divMuted)
                    }
                }
                .font(.az(15))
            }
            .buttonStyle(.plain)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    Capsule().fill(AZColor.accent).frame(width: (geo.size.width - 3) * (food?.fraction ?? 0))
                    Capsule().fill(AZColor.card)
                }
            }
            .frame(height: 10)
            .padding(.top, 16)
            Spacer(minLength: 16)
            HStack(spacing: 18) {
                macro("Protein", food?.eaten.protein ?? 0, of: food?.targets?.protein, color: AZColor.accent)
                macro("Carbs", food?.eaten.carbs ?? 0, of: food?.targets?.carbs, color: AZColor.carbs)
                macro("Fat", food?.eaten.fat ?? 0, of: food?.targets?.fat, color: AZColor.fat)
            }
        }
        .padding(EdgeInsets(top: 22, leading: 22, bottom: 20, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 234)
        .background(AZColor.divTint, in: .rect(cornerRadius: 32, style: .continuous))
    }

    private func macro(_ name: String, _ value: Int, of target: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.az(13, .semibold)).foregroundStyle(AZColor.divMuted)
            HStack(spacing: 0) {
                Text("\(value)").fontWeight(.heavy)
                Text(target.map { "/\($0)g" } ?? "g").fontWeight(.medium).foregroundStyle(AZColor.divMuted)
            }
            .font(.az(16))
            .monospacedDigit()
            MeterBar(value: target.map { Double(value) / Double(max($0, 1)) } ?? 0, color: color, track: AZColor.card, height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Water

    private func water(_ food: FoodSummary?) -> some View {
        let ml = food?.waterMl ?? 0
        let goal = max(food?.waterGoalMl ?? 2000, 1)
        let glasses = Int((ml / WaterLog.glassMl).rounded())
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Water").font(.az(16, .bold))
                    Text("\(Self.litres(ml)) of \(Self.litres(goal)) L").font(.az(14.5, .semibold)).foregroundStyle(AZColor.muted)
                        .monospacedDigit()
                }
                MeterBar(value: ml / goal, color: AZColor.water, track: AZColor.track, height: 6)
                Text("\(glasses) \(glasses == 1 ? "glass" : "glasses") of 250 ml").font(.az(13)).foregroundStyle(AZColor.muted)
            }
            IconButton(systemImage: "minus", label: "Take back a glass", size: 40, background: AZColor.card) {
                change { try $0.removeLastWater(on: environment.today) }
            }
            .disabled(ml <= 0)
            .opacity(ml <= 0 ? 0.4 : 1)
            IconButton(systemImage: "plus", label: "Add a glass of water", size: 40, background: AZColor.water, foreground: .white) {
                change { try $0.logWater(day: environment.today) }
            }
        }
        .padding(16)
        .background(AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Water, \(Self.litres(ml)) of \(Self.litres(goal)) litres")
    }

    /// 1.25, 2.5, 3
    private static func litres(_ ml: Double) -> String {
        let l = (ml / 10).rounded() / 100
        return l.rounded() == l ? "\(Int(l))" : String(format: "%g", l)
    }

    // MARK: Complete day

    /// "That's everything": only days marked complete count in Div's weekly calorie check, since a partly logged day
    /// would look like eating less.
    private func dayDone(_ food: FoodSummary?) -> some View {
        let done = food?.dayComplete == true
        return HStack(spacing: 12) {
            Image(systemName: done ? "checkmark" : "list.bullet")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(done ? AZColor.accent : AZColor.muted)
                .frame(width: 36, height: 36)
                .background(AZColor.card, in: .rect(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(done ? "Today's log is complete" : "Logged everything today?").font(.az(15.5, .bold))
                Text(done ? "It counts in Div's weekly calorie check" : "Only complete days count in Div's calorie check")
                    .font(.az(13)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if done {
                PillButton(title: "Undo", style: .card) { change { try $0.setDayComplete(environment.today, nil) } }
            } else {
                PillButton(title: "That's everything", style: .dark) { change { try $0.setDayComplete(environment.today, true) } }
            }
        }
        .padding(14)
        .background(AZColor.fill, in: .rect(cornerRadius: 22, style: .continuous))
    }

    // MARK: Micronutrients

    private func micronutrients(_ food: FoodSummary?) -> some View {
        let micros = food?.micros ?? [:]
        let meals = food?.meals.count ?? 0
        let known = food?.mealsWithMicros ?? 0
        let shown = allMicros ? Micronutrient.allCases : [.fiber, .sugar, .sodium, .potassium, .calcium, .iron]
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Micronutrients", note: meals == 0 ? nil : "From \(known) of \(meals) foods")
            if meals > 0 && known < meals {
                Text("Only foods from search, a barcode or the database carry these. Quick add and photo meals don't.")
                    .font(.az(13.5)).foregroundStyle(AZColor.muted).padding(.top, 4)
            }
            VStack(spacing: 14) {
                ForEach(shown) { micro in microRow(micro, micros[micro.rawValue] ?? 0) }
            }
            .padding(.top, 14)
            Button(allMicros ? "Show fewer" : "Show all \(Micronutrient.allCases.count)") {
                withAnimation(.snappy(duration: 0.2)) { allMicros.toggle() }
            }
            .font(.az(14.5, .bold))
            .foregroundStyle(AZColor.accent)
            .padding(.top, 14)
        }
    }

    private func microRow(_ micro: Micronutrient, _ amount: Double) -> some View {
        let fraction = amount / micro.dailyValue
        let over = micro.isLimit && fraction > 1
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(micro.title).font(.az(15, .semibold))
                if micro.isLimit { Text("limit").font(.az(12.5, .semibold)).foregroundStyle(AZColor.faint) }
                Spacer()
                Text("\(Self.amount(amount)) / \(Self.amount(micro.dailyValue)) \(micro.unit)")
                    .font(.az(14, .semibold)).foregroundStyle(over ? AZColor.lagging : AZColor.muted).monospacedDigit()
            }
            MeterBar(value: fraction, color: over ? AZColor.lagging : micro.isLimit ? AZColor.carbs : AZColor.accent, height: 5)
        }
        .accessibilityElement(children: .combine)
    }

    /// 2,300, 18, 0.4
    private static func amount(_ value: Double) -> String {
        value >= 100
            ? Int(value.rounded()).grouped : value >= 10 ? "\(Int(value.rounded()))" : String(format: "%g", (value * 10).rounded() / 10)
    }

    // MARK: Meals

    private func section(_ slot: Meal.Slot, _ meals: [Meal]) -> some View {
        let kcal = Int(meals.reduce(0) { $0 + $1.kcal }.rounded())
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Text(slot.title).font(.az(19, .heavy))
                if kcal > 0 {
                    Text("\(kcal.grouped) kcal").font(.az(14.5, .semibold)).foregroundStyle(AZColor.muted).monospacedDigit()
                }
                Spacer()
                PillButton(title: "Add", systemImage: "plus", style: .fill) { router.push(.addFood(slot)) }
                    .accessibilityLabel("Add food to \(slot.title)")
            }
            if !meals.isEmpty {
                HairlineStack {
                    ForEach(meals) { meal($0) }
                }
                .padding(.top, 4)
            }
        }
    }

    private func meal(_ meal: Meal) -> some View {
        var detail = meal.at.formatted(date: .omitted, time: .shortened)
        if let low = meal.kcalLow, let high = meal.kcalHigh, meal.kcal > 0 {
            detail += " · estimate ±\(Int(((high - low) / 2 / meal.kcal * 100).rounded()))%"
        }
        return HStack(spacing: 14) {
            IconTile(systemImage: icon(meal.source), size: 48, foreground: AZColor.muted, background: AZColor.fill)
            VStack(alignment: .leading, spacing: 1) {
                Text(meal.name).font(.az(16, .bold)).lineLimit(1)
                Text(detail).font(.az(14)).foregroundStyle(AZColor.muted)
            }
            Spacer(minLength: 0)
            Text(Int(meal.kcal.rounded()).grouped).font(.az(16, .bold)).monospacedDigit()
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
        .contextMenu {
            Button("Log again", systemImage: "arrow.clockwise") {
                change { try $0.logMeal(meal.again(day: environment.today, slot: meal.mealSlot)) }
            }
            Menu("Move to", systemImage: "arrow.right") {
                ForEach(Meal.Slot.allCases.filter { $0 != meal.mealSlot }) { slot in
                    Button(slot.title) { change { try $0.moveMeal(meal.id, to: slot) } }
                }
            }
            Button("Remove", systemImage: "trash", role: .destructive) { change { try $0.removeMeal(meal.id) } }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Log again") { change { try $0.logMeal(meal.again(day: environment.today, slot: meal.mealSlot)) } }
        .accessibilityAction(named: "Remove") { change { try $0.removeMeal(meal.id) } }
    }

    /// A write to today's log. Removing keeps the row (never delete what the person logged).
    private func change(_ write: (AZStore) throws -> Void) {
        guard (try? write(environment.store)) != nil else { return }
        withAnimation(.snappy(duration: 0.2)) { environment.changed() }
    }

    private func icon(_ source: Meal.Source) -> String {
        switch source {
        case .photo: "camera.fill"
        case .barcode: "barcode"
        case .typed: "text.cursor"
        case .favorite: "star.fill"
        }
    }
}

#Preview {
    NavigationStack { EatView() }.environment(Router()).environment(AppEnvironment.preview())
}
