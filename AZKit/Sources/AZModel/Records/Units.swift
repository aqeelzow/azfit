import Foundation

/// How numbers are shown (D-026). Everything is stored metric; these only convert for display and input.
public enum UnitSystem: String, Codable, Sendable, CaseIterable {
    /// Pounds for body weight and lifts, feet and inches for height, centimetres for the tape.
    case canadian
    /// Pounds, feet and inches.
    case american
    /// Kilograms for lifts, stone and pounds for body weight, feet and inches for height, centimetres for the tape.
    case british

    public var name: String {
        switch self {
        case .canadian: "Canadian"
        case .american: "American"
        case .british: "British"
        }
    }

    public enum MassUnit: String, Sendable { case kg, lb, stone }
    public enum LengthUnit: String, Sendable { case cm, inch }

    public var bodyWeight: MassUnit {
        switch self {
        case .canadian, .american: .lb
        case .british: .stone
        }
    }

    public var liftLoad: MassUnit {
        switch self {
        case .canadian, .american: .lb
        case .british: .kg
        }
    }

    public var tape: LengthUnit {
        switch self {
        case .american: .inch
        case .canadian, .british: .cm
        }
    }

    // MARK: Conversions

    public static let poundsPerKg = 2.204_622_621_8
    public static let cmPerInch = 2.54

    /// "176.4 lb", or "12 st 8 lb" for British body weight.
    public func bodyWeight(_ kg: Double) -> String {
        switch bodyWeight {
        case .kg: return "\(Self.oneDecimal(kg)) kg"
        case .lb: return "\(Self.oneDecimal(kg * Self.poundsPerKg)) lb"
        case .stone:
            let pounds = (kg * Self.poundsPerKg).rounded()
            let stone = Int(pounds / 14)
            let rest = Int(pounds) - stone * 14
            return rest == 0 ? "\(stone) st" : "\(stone) st \(rest) lb"
        }
    }

    /// A weight on the bar, rounded to what plates can make: 2.5 lb or 1.25 kg.
    public func load(_ kg: Double) -> String {
        switch liftLoad {
        case .lb: return "\(Self.trimmed((kg * Self.poundsPerKg / 2.5).rounded() * 2.5)) lb"
        case .kg, .stone: return "\(Self.trimmed((kg / 1.25).rounded() * 1.25)) kg"
        }
    }

    /// The load's number alone in the person's unit, for steppers and text fields.
    public func loadValue(_ kg: Double) -> Double {
        liftLoad == .lb ? kg * Self.poundsPerKg : kg
    }

    /// What the person typed for a load, back in kilograms.
    public func loadKg(_ value: Double) -> Double {
        liftLoad == .lb ? value / Self.poundsPerKg : value
    }

    /// What the person typed for body weight (pounds, or kilograms), back in kilograms. British input is in pounds
    /// as well: `bodyWeightKg(stone: 12, pounds: 8)`.
    public func bodyWeightKg(_ value: Double) -> Double {
        bodyWeight == .kg ? value : value / Self.poundsPerKg
    }

    public static func bodyWeightKg(stone: Int, pounds: Double) -> Double {
        (Double(stone) * 14 + pounds) / poundsPerKg
    }

    /// "81.4 cm" or "32.0 in".
    public func tape(_ cm: Double) -> String {
        tape == .cm ? "\(Self.oneDecimal(cm)) cm" : "\(Self.oneDecimal(cm / Self.cmPerInch)) in"
    }

    public func tapeCm(_ value: Double) -> Double {
        tape == .cm ? value : value * Self.cmPerInch
    }

    /// Height in feet and inches, for every system here: "5′ 11″".
    public func height(_ cm: Double) -> String {
        let inches = Int((cm / Self.cmPerInch).rounded())
        return "\(inches / 12)′ \(inches % 12)″"
    }

    public static func heightCm(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) * cmPerInch
    }

    static func oneDecimal(_ value: Double) -> String { String(format: "%.1f", value) }

    /// "100", "102.5": no trailing ".0".
    static func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}
