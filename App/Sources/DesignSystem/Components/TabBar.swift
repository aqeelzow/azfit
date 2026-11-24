import SwiftUI

/// The custom tab bar: four tabs around a notch that holds the purple quick add button. When quick add is open the
/// plus turns into a close button. Design: the `nav()` macro in design/source/build.py.
struct TabBar: View {
    @Binding var selection: Router.Tab
    var isQuickAddOpen: Bool
    var onQuickAdd: () -> Void
    var onSelect: (Router.Tab) -> Void

    static let height: CGFloat = 112

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                TabBarShape()
                    .fill(AZColor.nav)
                    .shadow(color: AZColor.navShadow, radius: 9, y: -4)
                ForEach(Self.tabs, id: \.tab) { item in
                    tabButton(item).position(x: width / 2 + item.offset, y: 36 + 25)
                }
                Button(action: onQuickAdd) {
                    Image(systemName: isQuickAddOpen ? "xmark" : "plus")
                        .font(.system(size: 24, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(AZColor.accent, in: .rect(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isQuickAddOpen ? "Close" : "Quick add")
                .position(x: width / 2, y: 10 + 30)
            }
        }
        .frame(height: Self.height)
    }

    private func tabButton(_ item: TabItem) -> some View {
        let isOn = selection == item.tab && !isQuickAddOpen
        return Button {
            onSelect(item.tab)
        } label: {
            Image(systemName: item.systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(isOn ? AZColor.ink : AZColor.faint)
                .frame(width: 50, height: 50)
                .overlay(alignment: .bottom) {
                    if isOn {
                        Capsule().fill(AZColor.accent).frame(width: 16, height: 4).offset(y: 3)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private struct TabItem {
        var tab: Router.Tab
        var systemImage: String
        var label: String
        /// Distance of the tab's center from the bar's center, from the design's 390 pt layout.
        var offset: CGFloat
    }

    private static let tabs = [
        TabItem(tab: .home, systemImage: "house", label: "Home", offset: -148),
        TabItem(tab: .train, systemImage: "dumbbell", label: "Train", offset: -78),
        TabItem(tab: .eat, systemImage: "fork.knife", label: "Eat", offset: 78),
        TabItem(tab: .body, systemImage: "person", label: "Body", offset: 148),
    ]
}

/// The bar's outline with the notch for the quick add button, kept centered at any width.
struct TabBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = rect.midX
        let w = rect.maxX
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 48))
        p.addCurve(to: CGPoint(x: 24, y: 24), control1: CGPoint(x: 0, y: 34.7), control2: CGPoint(x: 10.7, y: 24))
        p.addLine(to: CGPoint(x: c - 71, y: 24))
        p.addCurve(to: CGPoint(x: c - 46, y: 42), control1: CGPoint(x: c - 56, y: 24), control2: CGPoint(x: c - 50, y: 30))
        p.addCurve(to: CGPoint(x: c, y: 80), control1: CGPoint(x: c - 40, y: 62), control2: CGPoint(x: c - 27, y: 80))
        p.addCurve(to: CGPoint(x: c + 46, y: 42), control1: CGPoint(x: c + 27, y: 80), control2: CGPoint(x: c + 40, y: 62))
        p.addCurve(to: CGPoint(x: c + 71, y: 24), control1: CGPoint(x: c + 50, y: 30), control2: CGPoint(x: c + 56, y: 24))
        p.addLine(to: CGPoint(x: w - 24, y: 24))
        p.addCurve(to: CGPoint(x: w, y: 48), control1: CGPoint(x: w - 10.7, y: 24), control2: CGPoint(x: w, y: 34.7))
        p.addLine(to: CGPoint(x: w, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The Monday-to-Sunday strip on Home and Train: done days are lavender with a check, a missed day is struck
/// through, today is near-black, and a day Div moved a session to carries the Div mark.
struct WeekStrip: View {
    enum Day {
        case done, open, missed, today, movedByDiv
    }

    var days: [(letter: String, date: Int, state: Day)] = [
        ("M", 16, .done), ("T", 17, .done), ("W", 18, .open), ("T", 19, .done), ("F", 20, .missed), ("S", 21, .today),
        ("S", 22, .movedByDiv),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                if index > 0 { Spacer(minLength: 0) }
                VStack(spacing: 6) {
                    Text(day.letter)
                        .font(.az(12, .semibold))
                        .foregroundStyle(day.state == .today ? AZColor.ink : AZColor.muted)
                    cell(day.date, day.state)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ date: Int, _ state: Day) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Group {
            switch state {
            case .done:
                Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(AZColor.accent)
                    .frame(width: 42, height: 44).background(AZColor.divTint, in: shape)
            case .open, .movedByDiv:
                Text("\(date)").foregroundStyle(AZColor.muted).frame(width: 42, height: 44).background(AZColor.fill, in: shape)
            case .missed:
                Text("\(date)").strikethrough().foregroundStyle(AZColor.faint).frame(width: 42, height: 44)
                    .overlay(shape.strokeBorder(AZColor.hairline, lineWidth: 1.5))
            case .today:
                Text("\(date)").foregroundStyle(AZColor.buttonInk).frame(width: 42, height: 44).background(AZColor.button, in: shape)
            }
        }
        .font(.az(14, .bold))
        .monospacedDigit()
        .overlay(alignment: .bottomTrailing) {
            if state == .movedByDiv { DivMark(size: 16).offset(x: 5, y: 5) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility(date, state))
    }

    private func accessibility(_ date: Int, _ state: Day) -> String {
        switch state {
        case .done: "\(date), done"
        case .open: "\(date), rest day"
        case .missed: "\(date), missed"
        case .today: "\(date), today"
        case .movedByDiv: "\(date), session moved here by Div"
        }
    }
}
