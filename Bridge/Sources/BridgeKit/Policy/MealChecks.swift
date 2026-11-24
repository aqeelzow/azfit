import AZMath
import AZModel

/// Checks Div's meal estimate in code. Div can't change anything from a photo, so this only warns.
public enum MealChecks {
    public static func warnings(_ e: MealEstimate, totals: MealTotals, foodWeightG: Double?) -> [String] {
        var warnings: [String] = []
        for item in e.items {
            let fromMacros = MealMath.kcalFromMacros(item)
            if item.kcal > 50 && abs(fromMacros - item.kcal) / item.kcal > 0.2 {
                warnings.append("\(item.name): \(Int(item.kcal)) kcal doesn't match its macros (about \(Int(fromMacros.rounded())) kcal).")
            }
            if item.grams > 0 && item.kcal / item.grams > 9.5 {
                warnings.append("\(item.name): more calories per gram than pure fat.")
            }
        }
        let total = Double(totals.kcal)
        if !e.items.isEmpty && (total < e.kcalLow * 0.9 || total > e.kcalHigh * 1.1) {
            warnings.append("Items add up to \(totals.kcal) kcal, outside the stated range \(Int(e.kcalLow)) to \(Int(e.kcalHigh)).")
        }
        if let weight = foodWeightG, weight > 0, abs(totals.grams - weight) / weight > 0.1 {
            warnings.append("Items weigh \(Int(totals.grams)) g but the scale said \(Int(weight)) g.")
        }
        return warnings
    }
}
