/// The smoothed trend weight: each weigh-in moves the trend 10% of the way towards it (an EWMA, alpha 0.1).
/// The first weigh-in starts the trend.
public enum WeightTrend {
    public static let alpha = 0.1

    public static func trend(_ weights: [Double], alpha: Double = alpha) -> [Double] {
        var out: [Double] = []
        out.reserveCapacity(weights.count)
        for w in weights {
            out.append(out.last.map { $0 + alpha * (w - $0) } ?? w)
        }
        return out.map { rounded($0, 2) }
    }

    /// Weekly change of the trend between its first and last value, over `days`.
    public static func weeklyRateKg(_ trend: [Double], days: Int) -> Double? {
        guard let first = trend.first, let last = trend.last, days > 0 else { return nil }
        return rounded((last - first) / Double(days) * 7, 2)
    }
}
