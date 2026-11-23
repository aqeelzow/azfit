import SwiftUI

/// Food today. Design: design/screens/Eat.dc.html, Calibrate.dc.html ("Why 2,350?"), Meal.dc.html, Snap.dc.html
struct EatView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AZSpacing.stack) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("1,110").font(AZFont.display).monospacedDigit()
                    Text("kcal left of 2,350").font(AZFont.label).foregroundStyle(AZColor.muted)
                    DivMark()
                }
                DivNote(
                    title: "Did Thursday's dinner slip through?",
                    message: "You logged 1,180 kcal, about half your usual, and your weight didn't move Friday."
                ) {
                    PillButton(title: "Add it", style: .primary) {}
                    PillButton(title: "No, that's right") {}
                }
            }
            .padding(.horizontal, AZSpacing.gutter)
        }
        .background(AZColor.background)
    }
}

#Preview { EatView() }
