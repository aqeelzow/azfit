import AZModel
import AZStore
import SwiftUI

/// Eat: calories left against the target, macros as bars, and today's meals.
/// Design: design/source/src/Eat.html
struct EatView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment

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
                if let meals = food?.meals, !meals.isEmpty {
                    HairlineStack {
                        ForEach(meals) { meal($0) }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Nothing logged yet today. Tap + to add a meal.")
                        .font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 20)
                }
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
            Button("Log again", systemImage: "arrow.clockwise") { change { try $0.logMeal(meal.again(day: environment.today)) } }
            Button("Remove", systemImage: "trash", role: .destructive) { change { try $0.removeMeal(meal.id) } }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Log again") { change { try $0.logMeal(meal.again(day: environment.today)) } }
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
