import AZModel
import AZStore
import SwiftUI

/// Measurements: the latest tape (or scan) reading at each site on the outline with how it moved, the scale and
/// waist to height, and a way to add today's tape. Opened from Progress and Body. Design: design/source/src/ScanResult.html
struct ScanResultView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var isAdding = false
    @State private var typed: [BodyMeasurement.Site: String] = [:]
    @State private var problem: String?
    @FocusState private var focus: BodyMeasurement.Site?

    /// The sites the tape form asks for, in the order you'd measure them. Arm and thigh are the right side.
    static let tapeSites: [(site: BodyMeasurement.Site, name: String)] = [
        (.waist, "Waist"), (.chest, "Chest"), (.hips, "Hips"), (.neck, "Neck"), (.armRight, "Arm"), (.thighRight, "Thigh"),
    ]

    var body: some View {
        let readings = (try? environment.store.latestMeasurements()) ?? []
        let latestDay = readings.map(\.latest.day).max()
        VStack(spacing: 0) {
            TopBar(title: "Measurements", subtitle: latestDay.map { "Last measured \(AppEnvironment.caption($0))" }) {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isAdding {
                        form(readings).padding(.top, 16)
                    } else {
                        if readings.isEmpty {
                            Text("No measurements yet. A tape around your waist once a week tells Div more than the scale does.")
                                .font(.az(15)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 16)
                        }
                        outline(readings).padding(.top, 16)
                        totals(readings).padding(.top, 12)
                    }
                    if let problem {
                        Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 10)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "ruler").font(.system(size: 14, weight: .medium))
                        Text("Same spot each time, relaxed, in the morning. Div reads the trend.").font(.az(13))
                    }
                    .foregroundStyle(AZColor.muted)
                    .padding(.top, 20)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                if isAdding {
                    PrimaryButton(title: "Cancel", style: .soft) { setAdding(false) }
                    PrimaryButton(title: "Save") { save() }
                        .disabled(entries == nil)
                        .opacity(entries == nil ? 0.4 : 1)
                } else {
                    PrimaryButton(title: "Add measurements") { setAdding(true) }
                }
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.bottom, 8)
            .background(AZColor.background)
        }
        .azScreen()
    }

    // MARK: Reading

    private func reading(_ readings: [MeasurementReading], _ sites: BodyMeasurement.Site...) -> MeasurementReading? {
        sites.lazy.compactMap { site in readings.first { $0.latest.site == site } }.first
    }

    /// The outline with six sites around it, each joined to the body by a dashed leader.
    private func outline(_ readings: [MeasurementReading]) -> some View {
        ZStack(alignment: .topLeading) {
            BodyFigure(side: .front, levels: "000000000").frame(width: 94, height: 244)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .accessibilityHidden(true)
            measure("Chest", reading(readings, .chest), x: 18, y: 54)
            leader(x: 76, width: 70, y: 74)
            measure("Waist", reading(readings, .waist), x: 18, y: 118)
            leader(x: 108, width: 44, y: 138)
            measure("Hips", reading(readings, .hips), x: 18, y: 182)
            leader(x: 66, width: 84, y: 202)
            Text(environment.units.tape.rawValue).font(.az(12, .semibold)).foregroundStyle(AZColor.faint)
                .offset(x: 18, y: 268 - 14 - 16)
        }
        .overlay(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                measure("Neck", reading(readings, .neck), x: -18, y: 24, trailing: true)
                leader(x: -96, width: 74, y: 44)
                measure("Arm", reading(readings, .armRight, .armLeft), x: -18, y: 88, trailing: true)
                leader(x: -96, width: 44, y: 108)
                measure("Thigh", reading(readings, .thighRight, .thighLeft), x: -18, y: 156, trailing: true)
                leader(x: -96, width: 50, y: 176)
            }
        }
        .frame(height: 268, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(AZColor.fill, in: .rect(cornerRadius: 32, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func measure(_ name: String, _ reading: MeasurementReading?, x: CGFloat, y: CGFloat, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(name).font(.az(12.5, .semibold)).foregroundStyle(AZColor.muted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(reading.map { number($0.latest.cm) } ?? "-").font(.az(17, .heavy)).tracking(-0.34)
                    .foregroundStyle(reading == nil ? AZColor.faint : AZColor.ink)
                if let change = reading?.changeCm, change != 0 {
                    Text("\(change > 0 ? "+" : "-")\(number(abs(change)))").font(.az(12.5, .bold)).foregroundStyle(AZColor.muted)
                }
            }
            .monospacedDigit()
        }
        .offset(x: x, y: y)
    }

    private func leader(x: CGFloat, width: CGFloat, y: CGFloat) -> some View {
        Leader()
            .stroke(AZColor.ghost, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(width: width, height: 1.5)
            .offset(x: x, y: y)
            .accessibilityHidden(true)
    }

    private func totals(_ readings: [MeasurementReading]) -> some View {
        let weighIn = try? environment.store.latestWeighIn()
        let waist = reading(readings, .waist)?.latest.cm
        let ratio = Self.waistToHeight(waistCm: waist, heightCm: environment.profile?.heightCm)
        return Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 0) {
            GridRow {
                total("Scale weight", weighIn.map { environment.units.bodyWeight($0.kg) } ?? "-", "")
                total("Waist to height", ratio.map { String(format: "%.2f", $0) } ?? "-", ratio.map { $0 < 0.5 ? " healthy" : "" } ?? "")
            }
        }
    }

    private func total(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.az(13.5, .semibold)).foregroundStyle(AZColor.muted)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value).font(.az(24, .heavy)).tracking(-0.72).lineLimit(1).minimumScaleFactor(0.7)
                Text(unit).font(.az(14, .semibold)).foregroundStyle(AZColor.muted)
            }
            .monospacedDigit()
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One decimal in the person's tape unit, no unit.
    private func number(_ cm: Double) -> String {
        String(format: "%.1f", environment.units.tape == .cm ? cm : cm / UnitSystem.cmPerInch)
    }

    /// Waist over height. Under 0.5 is the usual healthy line.
    static func waistToHeight(waistCm: Double?, heightCm: Double?) -> Double? {
        guard let waistCm, let heightCm, heightCm > 0 else { return nil }
        return waistCm / heightCm
    }

    // MARK: Adding

    private func form(_ readings: [MeasurementReading]) -> some View {
        let unit = environment.units.tape.rawValue
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Today's tape", note: unit)
            HairlineStack {
                ForEach(Self.tapeSites, id: \.site) { entry in
                    HStack {
                        Text(entry.name).font(.az(16, .bold))
                        Spacer()
                        TextField(
                            "", text: binding(entry.site),
                            prompt: Text(reading(readings, entry.site).map { number($0.latest.cm) } ?? "0").foregroundStyle(AZColor.faint)
                        )
                        .font(.az(17, .heavy)).monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: entry.site)
                        .frame(width: 96)
                        Text(unit).font(.az(14, .semibold)).foregroundStyle(AZColor.muted).frame(width: 22, alignment: .leading)
                    }
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                    .onTapGesture { focus = entry.site }
                }
            }
            .padding(.top, 6)
            Text("Fill in the ones you measured. The grey numbers are last time.")
                .font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 10)
        }
    }

    private func binding(_ site: BodyMeasurement.Site) -> Binding<String> {
        Binding(
            get: { typed[site] ?? "" },
            set: {
                typed[site] = $0
                problem = nil
            })
    }

    /// What was typed, in cm. Nil when nothing was, or something isn't a plausible measurement.
    private var entries: [(BodyMeasurement.Site, Double)]? {
        let units = environment.units
        var result: [(BodyMeasurement.Site, Double)] = []
        for (site, _) in Self.tapeSites {
            let text = (typed[site] ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            guard !text.isEmpty else { continue }
            guard let value = Double(text) else { return nil }
            let cm = units.tapeCm(value)
            guard Self.plausibleCm.contains(cm) else { return nil }
            result.append((site, cm))
        }
        return result.isEmpty ? nil : result
    }

    /// Anything outside this is a typo.
    static let plausibleCm = 15.0...250.0

    private func setAdding(_ value: Bool) {
        typed = [:]
        problem = nil
        withAnimation(.snappy(duration: 0.2)) { isAdding = value }
        focus = value ? .waist : nil
    }

    private func save() {
        guard let entries else {
            problem = "One of those doesn't look like a measurement."
            return
        }
        do {
            try environment.store.save(entries.map { BodyMeasurement(day: environment.today, site: $0.0, cm: $0.1, source: .tape) })
            environment.changed()
            setAdding(false)
        } catch {
            problem = "Couldn't save them: \(error.localizedDescription)"
        }
    }

    private nonisolated struct Leader: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

#Preview {
    NavigationStack { ScanResultView() }.environment(Router()).environment(AppEnvironment.preview())
}
