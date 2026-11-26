import Foundation

extension Meal {
    /// The meal of the day a food is logged to. Eat groups the day's log by it.
    public enum Slot: String, Codable, Sendable, CaseIterable, Identifiable {
        case breakfast
        case lunch
        case dinner
        case snacks

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .breakfast: "Breakfast"
            case .lunch: "Lunch"
            case .dinner: "Dinner"
            case .snacks: "Snacks"
            }
        }

        /// The meal a time of day falls in, for food logged without one picked.
        public static func at(_ date: Date, calendar: Calendar = .current) -> Slot {
            switch calendar.component(.hour, from: date) {
            case 4..<11: .breakfast
            case 11..<15: .lunch
            case 17..<22: .dinner
            default: .snacks
            }
        }
    }

    /// The meal it was logged to, or the one its time falls in for food logged before meals had one.
    public var mealSlot: Slot { slot ?? .at(at) }
}

/// The nutrients beyond calories and macros that Eat totals, with US daily values (FDA, 2,000 kcal label).
public enum Micronutrient: String, Codable, Sendable, CaseIterable, Identifiable {
    case fiber
    case sugar
    case saturatedFat = "saturated_fat"
    case sodium
    case cholesterol
    case potassium
    case calcium
    case iron
    case magnesium
    case vitaminA = "vitamin_a"
    case vitaminC = "vitamin_c"
    case vitaminD = "vitamin_d"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fiber: "Fiber"
        case .sugar: "Sugar"
        case .saturatedFat: "Saturated fat"
        case .sodium: "Sodium"
        case .cholesterol: "Cholesterol"
        case .potassium: "Potassium"
        case .calcium: "Calcium"
        case .iron: "Iron"
        case .magnesium: "Magnesium"
        case .vitaminA: "Vitamin A"
        case .vitaminC: "Vitamin C"
        case .vitaminD: "Vitamin D"
        }
    }

    /// The unit amounts are kept in.
    public var unit: String {
        switch self {
        case .fiber, .sugar, .saturatedFat: "g"
        case .vitaminA, .vitaminD: "µg"
        default: "mg"
        }
    }

    /// The daily value: a goal to reach, or a limit to stay under (`isLimit`).
    public var dailyValue: Double {
        switch self {
        case .fiber: 28
        case .sugar: 50
        case .saturatedFat: 20
        case .sodium: 2300
        case .cholesterol: 300
        case .potassium: 4700
        case .calcium: 1300
        case .iron: 18
        case .magnesium: 420
        case .vitaminA: 900
        case .vitaminC: 90
        case .vitaminD: 20
        }
    }

    /// Less is better: sugar, saturated fat, sodium, cholesterol.
    public var isLimit: Bool { [.sugar, .saturatedFat, .sodium, .cholesterol].contains(self) }

    /// Open Food Facts' name for it. Its values are in grams.
    public var foodFactsKey: String {
        switch self {
        case .sugar: "sugars"
        case .saturatedFat: "saturated-fat"
        case .vitaminA: "vitamin-a"
        case .vitaminC: "vitamin-c"
        case .vitaminD: "vitamin-d"
        default: rawValue
        }
    }

    /// Grams to this nutrient's unit.
    public var perGram: Double {
        switch unit {
        case "mg": 1000
        case "µg": 1_000_000
        default: 1
        }
    }

    /// Totals of logged amounts, keyed by `rawValue`, the way meals store them.
    public static func total(_ meals: [[String: Double]?]) -> [String: Double] {
        meals.compactMap { $0 }.reduce(into: [:]) { sum, micros in sum.merge(micros, uniquingKeysWith: +) }
    }
}

/// Calories, macros and any micronutrients known for an amount of food. Micronutrients are keyed by
/// `Micronutrient.rawValue`, in that nutrient's unit.
public struct Nutrients: Codable, Sendable, Hashable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var micros: [String: Double]

    public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double, micros: [String: Double] = [:]) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.micros = micros
    }

    public static let zero = Nutrients(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)

    public func scaled(_ factor: Double) -> Nutrients {
        Nutrients(
            kcal: kcal * factor, proteinG: proteinG * factor, carbsG: carbsG * factor, fatG: fatG * factor,
            micros: micros.mapValues { $0 * factor })
    }
}

/// A food to log an amount of: from the food database (by search or barcode) or one the person made. Knows its
/// nutrients per 100 g, per serving, or both.
public struct Food: Codable, Sendable, Hashable, Identifiable {
    public enum Origin: String, Codable, Sendable {
        /// Open Food Facts.
        case database
        /// Made by the person (`CustomFood`).
        case custom
    }

    public struct Serving: Codable, Sendable, Hashable {
        /// "1 bar", "1 cup (240 ml)"
        public var label: String
        public var grams: Double?
        /// Nutrients for one serving, when known directly rather than from grams.
        public var nutrients: Nutrients?

        public init(label: String, grams: Double? = nil, nutrients: Nutrients? = nil) {
            self.label = label
            self.grams = grams
            self.nutrients = nutrients
        }
    }

    /// How an amount is counted.
    public enum Unit: String, Codable, Sendable { case grams, servings }

    public var id: String
    public var name: String
    public var brand: String?
    public var barcode: String?
    public var per100g: Nutrients?
    public var serving: Serving?
    public var origin: Origin

    public init(
        id: String, name: String, brand: String? = nil, barcode: String? = nil, per100g: Nutrients? = nil, serving: Serving? = nil,
        origin: Origin
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.per100g = per100g
        self.serving = serving
        self.origin = origin
    }

    /// What one serving holds: given directly, or from its grams and the per-100 g values.
    public var perServing: Nutrients? {
        if let nutrients = serving?.nutrients { return nutrients }
        guard let grams = serving?.grams, let per100g else { return nil }
        return per100g.scaled(grams / 100)
    }

    /// The units an amount can be given in, the natural one first.
    public var units: [Unit] {
        var units: [Unit] = []
        if perServing != nil { units.append(.servings) }
        if per100g != nil { units.append(.grams) }
        return units
    }

    /// The amount to start from: one serving, or 100 g.
    public func defaultAmount(in unit: Unit) -> Double { unit == .servings ? 1 : 100 }

    /// Nutrients for an amount, or nil when the food can't be counted in that unit.
    public func nutrients(_ amount: Double, _ unit: Unit) -> Nutrients? {
        guard amount > 0 else { return nil }
        switch unit {
        case .grams: return per100g?.scaled(amount / 100)
        case .servings: return perServing?.scaled(amount)
        }
    }

    /// "Brand · 1 bar (40 g)"
    public var detail: String {
        [
            brand,
            serving.map { s in s.grams.map { s.label.contains(Self.trim($0)) ? s.label : "\(s.label) (\(Self.trim($0)) g)" } ?? s.label },
        ]
        .compactMap { $0?.isEmpty == false ? $0 : nil }
        .joined(separator: " · ")
    }

    /// "1.5 servings", "1 bar", "150 g"
    public func amountLabel(_ amount: Double, _ unit: Unit) -> String {
        switch unit {
        case .grams: return "\(Self.trim(amount)) g"
        case .servings:
            if amount == 1, let label = serving?.label { return label }
            return "\(Self.trim(amount)) \(amount == 1 ? "serving" : "servings")"
        }
    }

    /// The food logged: an amount of it, as a meal row.
    public func meal(_ amount: Double, _ unit: Unit, day: String, at: Date = .now, slot: Meal.Slot) -> Meal? {
        guard let n = nutrients(amount, unit) else { return nil }
        let round = { (value: Double) in (value * 10).rounded() / 10 }
        let micros = n.micros.mapValues { ($0 * 100).rounded() / 100 }
        return Meal(
            day: day, at: at, name: name, kcal: n.kcal.rounded(), proteinG: round(n.proteinG), carbsG: round(n.carbsG),
            fatG: round(n.fatG), source: barcode == nil ? .typed : .barcode, barcode: barcode, slot: slot,
            micros: micros.isEmpty ? nil : micros)
    }

    /// 150, 1.5
    public static func trim(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

/// A food the person made: per serving, with an optional barcode so scanning it finds it next time. Kept on the
/// phone only.
public struct CustomFood: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var brand: String?
    public var servingLabel: String
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var barcode: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(), name: String, brand: String? = nil, servingLabel: String, kcal: Double, proteinG: Double,
        carbsG: Double, fatG: Double, barcode: String? = nil, createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servingLabel = servingLabel
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.barcode = barcode
        self.createdAt = createdAt
    }

    public var food: Food {
        Food(
            id: "custom:\(id.uuidString.lowercased())", name: name, brand: brand, barcode: barcode,
            serving: .init(label: servingLabel, nutrients: .init(kcal: kcal, proteinG: proteinG, carbsG: carbsG, fatG: fatG)),
            origin: .custom)
    }
}

/// A glass or bottle of water. Removing one keeps the row (never delete what the person logged).
public struct WaterLog: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var day: String
    public var at: Date
    public var ml: Double
    public var removed: Bool

    public init(id: UUID = UUID(), day: String, at: Date = .now, ml: Double, removed: Bool = false) {
        self.id = id
        self.day = day
        self.at = at
        self.ml = ml
        self.removed = removed
    }

    /// One glass.
    public static let glassMl = 250.0
}
