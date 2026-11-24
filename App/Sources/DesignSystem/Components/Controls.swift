import SwiftUI

/// The big bottom button: "Continue", "Log 640 kcal", "Done". Near-black in light mode.
struct PrimaryButton: View {
    enum Style { case dark, soft, accent }
    var title: String
    var trailingImage: String?
    var style: Style = .dark
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                if let trailingImage { Image(systemName: trailingImage).font(.system(size: 16, weight: .semibold)) }
            }
            .font(.az(16.5, .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .dark: AZColor.buttonInk
        case .soft: AZColor.ink
        case .accent: .white
        }
    }

    private var background: Color {
        switch style {
        case .dark: AZColor.button
        case .soft: AZColor.fill
        case .accent: AZColor.accent
        }
    }
}

/// The small pill used inside notes and rows: "Undo", "Keep 8 reps", "Add it".
struct PillButton: View {
    enum Style {
        /// Near-black, the main answer ("Add it").
        case dark
        /// White card, on lavender ("Undo").
        case card
        /// Neutral fill, on white ("Swap", "See the math").
        case fill
        /// Purple ("Finish").
        case accent
    }

    var title: String
    var systemImage: String?
    var trailingImage: String?
    var style: Style = .card
    var height: CGFloat = 34
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .bold)) }
                Text(title).lineLimit(1)
                if let trailingImage { Image(systemName: trailingImage).font(.system(size: 12, weight: .bold)) }
            }
            .font(.az(14, .bold))
            .padding(.horizontal, 14)
            .frame(height: height)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var foreground: Color {
        switch style {
        case .dark: AZColor.buttonInk
        case .card, .fill: AZColor.ink
        case .accent: .white
        }
    }

    private var background: Color {
        switch style {
        case .dark: AZColor.button
        case .card: AZColor.card
        case .fill: AZColor.fill
        case .accent: AZColor.accent
        }
    }
}

/// The 44 pt square button in the top corners: back, search, share.
struct IconButton: View {
    var systemImage: String
    var label: String
    var size: CGFloat = 44
    var background: Color = AZColor.fill
    var foreground: Color = AZColor.ink
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(foreground)
                .background(background, in: .rect(cornerRadius: size * 0.32, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A filter chip: "Shoulders", "3M". The selected one is near-black.
struct Chip: View {
    var title: String
    var isOn = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.az(14, .semibold))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .foregroundStyle(isOn ? AZColor.buttonInk : AZColor.ink)
                .background(isOn ? AZColor.button : AZColor.fill, in: .capsule)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

/// The row of controls at the top of a pushed screen: a button on each side and a centered title.
struct TopBar<Leading: View, Center: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            center
            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .frame(height: 44)
        .padding(.horizontal, AZSpacing.gutter)
        .padding(.top, 6)
    }
}

extension TopBar where Center == TopBarTitle {
    init(title: String, subtitle: String? = nil, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.init(leading: leading, center: { TopBarTitle(title: title, subtitle: subtitle) }, trailing: trailing)
    }
}

struct TopBarTitle: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 1) {
            Text(title).font(.az(17, .heavy))
            if let subtitle { Text(subtitle).font(.az(13, .medium)).foregroundStyle(AZColor.muted) }
        }
    }
}

/// The back button every pushed screen uses.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var systemImage = "chevron.left"

    var body: some View {
        IconButton(systemImage: systemImage, label: "Back") { dismiss() }
    }
}

/// Small grey label above a section: "Needs you", "Up next".
struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text).font(.az(14, .semibold)).foregroundStyle(AZColor.muted)
    }
}

/// A section heading with an optional quiet note on the right: "New record ... History".
struct SectionHeader: View {
    var title: String
    var note: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.az(19, .heavy))
            Spacer()
            if let note { Text(note).font(.az(14, .semibold)).foregroundStyle(AZColor.muted) }
        }
    }
}

/// A screen title with the small date line above it: "Saturday, Nov 21 / Eat".
struct LargeTitle: View {
    var caption: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: caption)
            Text(title).font(.az(34, .heavy)).tracking(-0.85)
        }
    }
}

/// A thin horizontal meter. Protein is a bar, never a ring (D-013).
struct MeterBar: View {
    var value: Double
    var color: Color = AZColor.accent
    var track: Color = AZColor.track
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// A list of rows with a hairline between each, like the design's `.li + .li`.
struct HairlineStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Rectangle().fill(AZColor.hairline).frame(height: 1) }
                    row
                }
            }
        }
    }
}

/// A photo from the asset catalog, cropped to a rounded square. Never a circle (D-013).
struct PhotoTile: View {
    var name: String
    var size: CGFloat = 48
    var radius: CGFloat = 14

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A square icon on a tinted rounded square: the leading icon in Div's log, the record row, quick add.
struct IconTile: View {
    var systemImage: String
    var size: CGFloat = 44
    var foreground: Color = AZColor.divInk
    var background: Color = AZColor.divTint

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .frame(width: size, height: size)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The rounded switch from "What Div knows". A rounded square knob, not a circle (D-013).
struct SquareToggle: View {
    @Binding var isOn: Bool
    var label: String

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { isOn.toggle() }
        } label: {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                .padding(3)
                .frame(width: 50, height: 30)
                .background(isOn ? AZColor.accent : AZColor.track, in: .rect(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

extension View {
    /// Every prototype screen: the design background, full bleed, and no system navigation bar
    /// (each screen draws its own top bar from the design).
    func azScreen() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AZColor.background.ignoresSafeArea())
            #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
            #endif
    }
}
