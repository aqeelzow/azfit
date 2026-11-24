import Foundation

// The meal photo estimate (Div/prompts/jobs/estimate-meal.md).

public struct MealPhotoRequest: Codable, Sendable, Equatable {
    public enum MediaType: String, Codable, Sendable {
        case jpeg = "image/jpeg"
        case png = "image/png"
        case webp = "image/webp"

        public var fileExtension: String {
            switch self {
            case .jpeg: "jpg"
            case .png: "png"
            case .webp: "webp"
            }
        }
    }

    /// The photo. Base64 in JSON. The phone converts HEIC before sending.
    public var photo: Data
    public var mediaType: MediaType
    /// What the person typed, e.g. "chicken shawarma plate, half the rice".
    public var note: String?
    /// Measured once in settings; the ruler in the photo.
    public var plateDiameterCm: Double?
    /// From a kitchen scale, food only. The most accurate input there is.
    public var foodWeightG: Double?
    public var mealTime: String?
    /// Favorites and recent meals, so the same meal is logged the same way.
    public var similarMeals: [SimilarMeal]?

    public struct SimilarMeal: Codable, Sendable, Equatable {
        public var name: String
        public var kcal: Double
        public var proteinG: Double
        public var carbsG: Double
        public var fatG: Double
        public var loggedTimes: Int
    }

    public init(
        photo: Data, mediaType: MediaType, note: String? = nil, plateDiameterCm: Double? = nil, foodWeightG: Double? = nil,
        mealTime: String? = nil, similarMeals: [SimilarMeal]? = nil
    ) {
        self.photo = photo
        self.mediaType = mediaType
        self.note = note
        self.plateDiameterCm = plateDiameterCm
        self.foodWeightG = foodWeightG
        self.mealTime = mealTime
        self.similarMeals = similarMeals
    }
}

public struct MealItem: Codable, Sendable, Equatable {
    public var name: String
    public var portion: String
    public var grams: Double
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public init(name: String, portion: String, grams: Double, kcal: Double, proteinG: Double, carbsG: Double, fatG: Double) {
        self.name = name
        self.portion = portion
        self.grams = grams
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}

/// What Div returns for a meal photo (Div/schemas/estimate-meal.json).
public struct MealEstimate: Codable, Sendable, Equatable {
    public enum Confidence: String, Codable, Sendable {
        case low
        case medium
        case high
    }

    public var mealName: String
    public var items: [MealItem]
    public var kcalLow: Double
    public var kcalHigh: Double
    public var confidence: Confidence
    public var matchedSimilarMeal: String
    public var assumptions: [String]
    public var followUpQuestion: String

    public init(
        mealName: String = "", items: [MealItem], kcalLow: Double, kcalHigh: Double, confidence: Confidence = .medium,
        matchedSimilarMeal: String = "", assumptions: [String] = [], followUpQuestion: String = ""
    ) {
        self.mealName = mealName
        self.items = items
        self.kcalLow = kcalLow
        self.kcalHigh = kcalHigh
        self.confidence = confidence
        self.matchedSimilarMeal = matchedSimilarMeal
        self.assumptions = assumptions
        self.followUpQuestion = followUpQuestion
    }
}

/// A meal's totals, always added up in code from the items (never taken from the model).
public struct MealTotals: Codable, Sendable, Equatable {
    public var kcal: Int
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var grams: Double

    public init(kcal: Int, proteinG: Double, carbsG: Double, fatG: Double, grams: Double) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.grams = grams
    }
}

/// The person's answer to Div's follow-up question ("Was there dressing?"), to revise an estimate without the photo.
public struct MealRevisionRequest: Codable, Sendable, Equatable {
    public var previous: MealEstimate
    public var question: String
    public var answer: String

    public init(previous: MealEstimate, question: String, answer: String) {
        self.previous = previous
        self.question = question
        self.answer = answer
    }
}
