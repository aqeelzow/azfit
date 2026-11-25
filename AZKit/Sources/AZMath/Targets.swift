import AZModel

/// Where calories and protein start, and the floor Div can never go below (D-017).
/// After the first weeks the Sunday review recalibrates calories from the scale (D-010), so the start only has to be
/// close.
public enum Targets {
    /// Resting energy, Mifflin-St Jeor: 10 × kg + 6.25 × cm - 5 × age, +5 for men, -161 for women.
    public static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        10 * weightKg + 6.25 * heightCm - 5 * Double(age) + (sex == .male ? 5 : -161)
    }

    /// The person's floor: their BMR rounded up to 50, and never under 1,200. Proposed formula, D-017.
    /// Without sex, height or age it falls back to 1,200 for women and unknown, 1,500 for men.
    public static func calorieFloor(sex: Sex?, weightKg: Double?, heightCm: Double?, age: Int?) -> Int {
        let minimum = sex == .male ? 1_500 : 1_200
        guard let sex, let weightKg, let heightCm, let age else { return minimum }
        let bmr = bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        return max(1_200, Int((bmr / 50).rounded(.up)) * 50)
    }

    /// A first calorie target: BMR × 1.5 (lightly active plus training), then the goal's pace
    /// (7,700 kcal per kg of weight change), rounded to 50 and kept above the floor.
    public static func startingCalories(
        sex: Sex, weightKg: Double, heightCm: Double, age: Int, goal: Goal, ratePctPerWeek: Double
    )
        -> Int
    {
        let maintenance = bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age) * 1.5
        let dailyChange = weightKg * ratePctPerWeek / 100 * 7_700 / 7
        let target = Int(((maintenance + dailyChange) / 50).rounded()) * 50
        return max(target, calorieFloor(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age))
    }

    /// The middle of the goal's protein range, in g per kg.
    public static func startingProtein(goal: Goal) -> Double {
        let range = WeeklyMath.proteinRange(for: goal)
        return rounded((range.lowerBound + range.upperBound) / 2, 1)
    }
}
