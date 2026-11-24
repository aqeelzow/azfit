import AZModel

public enum MealMath {
    /// Calories per gram of protein, carbohydrate and fat.
    public static let kcalPerGram = (protein: 4.0, carbs: 4.0, fat: 9.0)

    /// Adds up a meal's items. The app always uses these totals, never a total from the model.
    public static func totals(_ items: [MealItem]) -> MealTotals {
        func sum(_ value: (MealItem) -> Double) -> Double { items.map(value).reduce(0, +) }
        return MealTotals(
            kcal: Int(sum(\.kcal).rounded()),
            proteinG: rounded(sum(\.proteinG)),
            carbsG: rounded(sum(\.carbsG)),
            fatG: rounded(sum(\.fatG)),
            grams: rounded(sum(\.grams), 0)
        )
    }

    /// The calories an item's macros add up to.
    public static func kcalFromMacros(_ item: MealItem) -> Double {
        kcalPerGram.protein * item.proteinG + kcalPerGram.carbs * item.carbsG + kcalPerGram.fat * item.fatG
    }
}
