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
        kcal(proteinG: item.proteinG, carbsG: item.carbsG, fatG: item.fatG)
    }

    public static func kcal(proteinG: Double, carbsG: Double, fatG: Double) -> Double {
        kcalPerGram.protein * proteinG + kcalPerGram.carbs * carbsG + kcalPerGram.fat * fatG
    }

    /// A meal typed in by hand: the calories given, or what the macros add up to when they're left out. Nil when
    /// there's nothing to log, or a number is negative or past what one meal could be.
    public static func typed(kcal: Double?, proteinG: Double?, carbsG: Double?, fatG: Double?) -> MealTotals? {
        let macros = [proteinG, carbsG, fatG].map { $0 ?? 0 }
        guard ([kcal ?? 0] + macros).allSatisfy({ $0 >= 0 && $0 <= maxTypedKcal }) else { return nil }
        let total = kcal ?? self.kcal(proteinG: macros[0], carbsG: macros[1], fatG: macros[2])
        guard total > 0, total <= maxTypedKcal else { return nil }
        return MealTotals(
            kcal: Int(total.rounded()), proteinG: rounded(macros[0]), carbsG: rounded(macros[1]), fatG: rounded(macros[2]), grams: 0)
    }

    /// More than this in one meal is a typo.
    public static let maxTypedKcal = 5000.0
}
