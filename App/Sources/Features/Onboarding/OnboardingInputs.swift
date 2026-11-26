import AZModel
import SwiftUI

/// Height on wheels: feet and inches, from 3′ 11″ to 7′ 6″ (the onboarding limits of 120 to 230 cm).
struct HeightPicker: View {
    @Binding var cm: Double
    @Environment(\.dismiss) private var dismiss

    private static let inchesRange = Int((120 / UnitSystem.cmPerInch).rounded(.up))...Int(230 / UnitSystem.cmPerInch)

    private var totalInches: Int {
        min(max(Int((cm / UnitSystem.cmPerInch).rounded()), Self.inchesRange.lowerBound), Self.inchesRange.upperBound)
    }

    var body: some View {
        let feet = Binding<Int>(
            get: { totalInches / 12 },
            set: { set(feet: $0, inches: totalInches % 12) })
        let inches = Binding<Int>(
            get: { totalInches % 12 },
            set: { set(feet: totalInches / 12, inches: $0) })
        VStack(spacing: 0) {
            HStack {
                Text("Height").font(.az(17, .heavy))
                Spacer()
                PillButton(title: "Done", style: .dark) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            HStack(spacing: 0) {
                Picker("Feet", selection: feet) {
                    ForEach(3...7, id: \.self) { Text("\($0) ft").tag($0) }
                }
                Picker("Inches", selection: inches) {
                    ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                }
            }
            .pickerStyle(.wheel)
            .padding(.horizontal, 12)
        }
        .azScreen()
    }

    private func set(feet: Int, inches: Int) {
        let total = min(max(feet * 12 + inches, Self.inchesRange.lowerBound), Self.inchesRange.upperBound)
        cm = Double(total) * UnitSystem.cmPerInch
    }
}

/// Body weight typed in the person's units: one box for kilograms or pounds, or stone and pounds for British. A
/// number that isn't a plausible body weight is ignored until it is one. Tapping in clears the box, with the current
/// weight as a hint; leaving it empty keeps that weight.
struct BodyWeightField: View {
    @Binding var kg: Double
    var units: UnitSystem

    @State private var main = ""
    @State private var pounds = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            box($main, hint: hints.main, width: units.bodyWeight == .stone ? 36 : 64)
            Text(units.bodyWeight == .stone ? "st" : units.bodyWeight.rawValue).font(.az(14, .bold)).foregroundStyle(AZColor.muted)
            if units.bodyWeight == .stone {
                box($pounds, hint: hints.pounds, width: 36)
                Text("lb").font(.az(14, .bold)).foregroundStyle(AZColor.muted)
            }
        }
        .frame(minWidth: 92, minHeight: 40)
        .padding(.horizontal, 6)
        .background(AZColor.fill, in: .rect(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weight")
        .onAppear(perform: fill)
        // The steppers change it from outside: show the new number unless the person is typing.
        .onChange(of: kg) { if !focused { fill() } }
        .onChange(of: units) { fill() }
        .onChange(of: focused) {
            if focused {
                main = ""
                pounds = ""
            } else {
                fill()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }.font(.az(16, .bold))
            }
        }
    }

    private var hints: (main: String, pounds: String) { units.bodyWeightFields(kg) }

    private func box(_ text: Binding<String>, hint: String, width: CGFloat) -> some View {
        TextField("", text: text, prompt: Text(hint).foregroundStyle(AZColor.faint))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.az(16, .bold))
            .monospacedDigit()
            .frame(width: width)
            .focused($focused)
            .onChange(of: text.wrappedValue) {
                if focused, let value = units.bodyWeightKg(typed: main, pounds: pounds) { kg = value }
            }
    }

    private func fill() {
        let fields = units.bodyWeightFields(kg)
        main = fields.main
        pounds = fields.pounds
    }
}
