import SwiftUI

/// A line through `values`, scaled to fill the frame (highest value at the top). Flat with fewer than two values.
nonisolated struct Sparkline: Shape {
    var values: [Double]

    func path(in rect: CGRect) -> Path {
        Path { p in
            guard values.count > 1, let low = values.min(), let high = values.max() else {
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                return
            }
            let span = max(high - low, 0.0001)
            for (i, value) in values.enumerated() {
                let x = rect.minX + rect.width * CGFloat(i) / CGFloat(values.count - 1)
                let y = rect.minY + rect.height * CGFloat((high - value) / span)
                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}
