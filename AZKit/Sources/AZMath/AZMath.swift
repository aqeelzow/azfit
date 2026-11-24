import AZModel
import Foundation

// AZMath: pure functions over AZModel types. Same input, same output, easy to test (D-010).
//
// Built: the numbers Div's jobs read (WeeklyMath, Strength, MealMath, WeightTrend).
// TODO, from the brief (docs/product-brief.html): effective sets, muscle fatigue and recovery.

/// Rounds to `places` decimal places, half away from zero.
func rounded(_ value: Double, _ places: Int = 1) -> Double {
    let scale = pow(10, Double(places))
    return (value * scale).rounded() / scale
}
