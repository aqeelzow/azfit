import SwiftUI

/// This week and today's session. Design: design/screens/Train.dc.html, Workout.dc.html, Exercise.dc.html
struct TrainView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AZSpacing.stack) {
                Text("This week").font(AZFont.h1)
                HStack(spacing: 8) {
                    WasValue(value: "Overhead press")
                    Text("Landmine press").font(AZFont.title)
                    DivMark()
                }
            }
            .padding(.horizontal, AZSpacing.gutter)
        }
        .background(AZColor.background)
    }
}

#Preview { TrainView() }
