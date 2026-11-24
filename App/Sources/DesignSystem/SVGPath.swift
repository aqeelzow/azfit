import SwiftUI

/// Turns SVG path data (the `d` attribute) into a SwiftUI `Path`, so shapes can be copied straight from the design
/// files (the body figure, the charts). Supports M L H V C S Q A Z, absolute and relative.
nonisolated enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        let tokens = tokenize(data)
        var index = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?

        func number() -> CGFloat {
            guard index < tokens.count, case .number(let value) = tokens[index] else { return 0 }
            index += 1
            return value
        }
        func point(relative: Bool) -> CGPoint {
            let x = number()
            let y = number()
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while index < tokens.count {
            let startIndex = index
            defer { if index == startIndex { index += 1 } }  // never loop on a malformed token
            if case .command(let c) = tokens[index] {
                command = c
                index += 1
            }
            let relative = command.isLowercase
            switch command.uppercased() {
            case "M":
                current = point(relative: relative)
                subpathStart = current
                path.move(to: current)
                lastCubicControl = nil
                // Extra pairs after a move are lines.
                command = relative ? "l" : "L"
            case "L":
                current = point(relative: relative)
                path.addLine(to: current)
                lastCubicControl = nil
            case "H":
                let x = number()
                current.x = relative ? current.x + x : x
                path.addLine(to: current)
                lastCubicControl = nil
            case "V":
                let y = number()
                current.y = relative ? current.y + y : y
                path.addLine(to: current)
                lastCubicControl = nil
            case "C":
                let c1 = point(relative: relative)
                let c2 = point(relative: relative)
                let end = point(relative: relative)
                path.addCurve(to: end, control1: c1, control2: c2)
                lastCubicControl = c2
                current = end
            case "S":
                let c1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = point(relative: relative)
                let end = point(relative: relative)
                path.addCurve(to: end, control1: c1, control2: c2)
                lastCubicControl = c2
                current = end
            case "Q":
                let control = point(relative: relative)
                let end = point(relative: relative)
                path.addQuadCurve(to: end, control: control)
                lastCubicControl = nil
                current = end
            case "A":
                let rx = number()
                let ry = number()
                let rotation = number()
                let largeArc = number() != 0
                let sweep = number() != 0
                let end = point(relative: relative)
                addArc(
                    to: &path, from: current, to: end, radii: CGSize(width: rx, height: ry), rotation: rotation, largeArc: largeArc,
                    sweep: sweep)
                lastCubicControl = nil
                current = end
            case "Z":
                path.closeSubpath()
                current = subpathStart
                lastCubicControl = nil
            default:
                break  // unsupported command: the guard above skips its numbers
            }
        }
        return path
    }

    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    private static let commands = Set("MmLlHhVvCcSsQqAaZz")

    private static func tokenize(_ data: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(data)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if commands.contains(c) {
                tokens.append(.command(c))
                i += 1
                continue
            }
            guard c.isNumber || c == "-" || c == "+" || c == "." else {
                i += 1
                continue
            }
            var j = i
            if chars[j] == "-" || chars[j] == "+" { j += 1 }
            var seenDot = false
            var seenExponent = false
            while j < chars.count {
                let d = chars[j]
                if d.isNumber {
                    j += 1
                } else if d == ".", !seenDot, !seenExponent {
                    seenDot = true
                    j += 1
                } else if d == "e" || d == "E", !seenExponent {
                    seenExponent = true
                    j += 1
                    if j < chars.count, chars[j] == "-" || chars[j] == "+" { j += 1 }
                } else {
                    break
                }
            }
            if let value = Double(String(chars[i..<j])) { tokens.append(.number(CGFloat(value))) }
            i = max(j, i + 1)
        }
        return tokens
    }

    /// SVG's endpoint arc, converted to cubic curves (SVG spec, appendix B.2.4).
    private static func addArc(
        to path: inout Path, from start: CGPoint, to end: CGPoint, radii: CGSize, rotation: CGFloat, largeArc: Bool, sweep: Bool
    ) {
        var rx = abs(radii.width)
        var ry = abs(radii.height)
        guard rx > 0, ry > 0, start != end else {
            path.addLine(to: end)
            return
        }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coefficient = (largeArc != sweep ? 1 : -1) * max(0, numerator / denominator).squareRoot()
        let cxPrime = coefficient * rx * y1 / ry
        let cyPrime = -coefficient * ry * x1 / rx
        let cx = cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2
        let cy = sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let theta = angle(1, 0, (x1 - cxPrime) / rx, (y1 - cyPrime) / ry)
        var delta = angle((x1 - cxPrime) / rx, (y1 - cyPrime) / ry, (-x1 - cxPrime) / rx, (-y1 - cyPrime) / ry)
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }

        func pointAt(_ a: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(a) * cosPhi - ry * sin(a) * sinPhi, y: cy + rx * cos(a) * sinPhi + ry * sin(a) * cosPhi)
        }
        func tangentAt(_ a: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(a) * cosPhi - ry * cos(a) * sinPhi, y: -rx * sin(a) * sinPhi + ry * cos(a) * cosPhi)
        }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(segments)
        let k = 4 / 3 * tan(step / 4)
        for i in 0..<segments {
            let a1 = theta + CGFloat(i) * step
            let a2 = a1 + step
            let p1 = pointAt(a1)
            let p2 = i == segments - 1 ? end : pointAt(a2)
            let t1 = tangentAt(a1)
            let t2 = tangentAt(a2)
            path.addCurve(
                to: p2, control1: CGPoint(x: p1.x + k * t1.x, y: p1.y + k * t1.y), control2: CGPoint(x: p2.x - k * t2.x, y: p2.y - k * t2.y)
            )
        }
    }
}

/// A shape drawn from SVG path data in a fixed view box, scaled to fit the frame it is given.
struct SVGShape: Shape {
    var data: String
    var viewBox: CGRect

    func path(in rect: CGRect) -> Path {
        let path = SVGPath.parse(data)
        let scale = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / viewBox.width, y: rect.height / viewBox.height)
            .translatedBy(x: -viewBox.minX, y: -viewBox.minY)
        return path.applying(scale)
    }
}
