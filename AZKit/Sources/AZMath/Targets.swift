import AZModel

/// Where calories and protein start, and the floor Div can never go below (D-017).
/// After the first weeks the Sunday review recalibrates calories from the scale (D-010), so the start only has to be
/// close.
public enum Targets {
    /// Resting energy, Mifflin-St Jeor: 10 × kg + 6.25 × cm - 5 × age, +5 for men, -161 for women, and the
    /// midpoint (-78) when sex isn't given.
    public static func bmr(sex: Sex?, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let constant: Double =
            switch sex {
            case .male: 5
            case .female: -161
            case nil: -78
            }
        return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + constant
    }

    /// The person's floor: their BMR rounded up to 50, and never under 1,200. Proposed formula, D-017.
    /// Without sex, height or age it falls back to 1,200 for women and unknown, 1,500 for men.
    public static func calorieFloor(sex: Sex?, weightKg: Double?, heightCm: Double?, age: Int?) -> Int {
        let minimum = sex == .male ? 1_500 : 1_200
        guard let sex, let weightKg, let heightCm, let age else { return minimum }
        let bmr = bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        return max(1_200, Int((bmr / 50).rounded(.up)) * 50)
    }

    /// Every number behind the first target, so onboarding can show the working.
    public struct StartingBreakdown: Sendable, Equatable {
        /// Resting energy (Mifflin-St Jeor).
        public var bmr: Int
        /// Lightly active plus training.
        public static let activity = 1.5
        public var maintenance: Int
        /// Per day for the goal's pace: negative to lose, positive to gain.
        public var goalAdjustment: Int
        /// The goal's pace, % of body weight per week.
        public var ratePctPerWeek: Double
        public var floor: Int
        /// The target: maintenance plus the adjustment, rounded to 50 and kept above the floor.
        public var kcal: Int
        /// The floor raised the target.
        public var heldAtFloor: Bool
    }

    /// A first calorie target: BMR × 1.5 (lightly active plus training), then the goal's pace
    /// (7,700 kcal per kg of weight change), rounded to 50 and kept above the floor.
    public static func startingBreakdown(
        sex: Sex?, weightKg: Double, heightCm: Double, age: Int, goal: Goal, ratePctPerWeek: Double
    ) -> StartingBreakdown {
        let resting = bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        let maintenance = resting * StartingBreakdown.activity
        let dailyChange = weightKg * ratePctPerWeek / 100 * 7_700 / 7
        let rounded = Int(((maintenance + dailyChange) / 50).rounded()) * 50
        let floor = calorieFloor(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        return StartingBreakdown(
            bmr: Int(resting.rounded()), maintenance: Int(maintenance.rounded()), goalAdjustment: Int(dailyChange.rounded()),
            ratePctPerWeek: ratePctPerWeek, floor: floor, kcal: max(rounded, floor), heldAtFloor: rounded < floor)
    }

    public static func startingCalories(
        sex: Sex?, weightKg: Double, heightCm: Double, age: Int, goal: Goal, ratePctPerWeek: Double
    )
        -> Int
    {
        startingBreakdown(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age, goal: goal, ratePctPerWeek: ratePctPerWeek)
            .kcal
    }

    /// Daily grams for the three macros: protein from g per kg, fat at 25% of calories, carbs the rest.
    public static func macroGrams(
        kcal: Int, proteinGPerKg: Double, weightKg: Double, fatG: Int? = nil
    )
        -> (protein: Int, carbs: Int, fat: Int)
    {
        let protein = proteinGPerKg * weightKg
        let fat = fatG.map(Double.init) ?? Double(kcal) * 0.25 / MealMath.kcalPerGram.fat
        let carbs =
            max(0, Double(kcal) - protein * MealMath.kcalPerGram.protein - fat * MealMath.kcalPerGram.fat)
            / MealMath.kcalPerGram.carbs
        return (Int(protein.rounded()), Int(carbs.rounded()), Int(fat.rounded()))
    }

    /// A daily water goal: 35 ml per kg, in whole glasses, 2 L without a weight. A rough guide, not a rule:
    /// food brings water too, and heat and training add to it.
    public static func waterMl(weightKg: Double?) -> Double {
        guard let weightKg, weightKg > 0 else { return 2000 }
        let glass = WaterLog.glassMl
        return min(max((weightKg * 35 / glass).rounded() * glass, 1500), 4500)
    }

    /// Why targets the person typed can't be saved: impossible numbers only. A low or unusual target is allowed
    /// (it's their call) and Div talks it through instead.
    public static func problems(kcal: Int, proteinG: Int, fatG: Int, waterMl: Int) -> [String] {
        var problems: [String] = []
        if kcal < 800 || kcal > 6000 { problems.append("Calories need to be between 800 and 6,000.") }
        if proteinG < 0 || proteinG > 400 { problems.append("Protein needs to be between 0 and 400 g.") }
        if fatG < 10 || fatG > 300 { problems.append("Fat needs to be between 10 and 300 g.") }
        if Double(proteinG) * MealMath.kcalPerGram.protein + Double(fatG) * MealMath.kcalPerGram.fat > Double(kcal) {
            problems.append("Protein and fat add up to more than the calories, leaving nothing for carbs.")
        }
        if waterMl < 500 || waterMl > 8000 { problems.append("Water needs to be between 0.5 and 8 L.") }
        return problems
    }

    /// The middle of the goal's protein range, in g per kg.
    public static func startingProtein(goal: Goal) -> Double {
        let range = WeeklyMath.proteinRange(for: goal)
        return rounded((range.lowerBound + range.upperBound) / 2, 1)
    }
}
