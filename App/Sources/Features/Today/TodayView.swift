import SwiftUI

/// Home. Design: design/screens/Home.dc.html
struct TodayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AZSpacing.section) {
                Text("Good morning, Alex").font(AZFont.h1)
                DivNote(title: "Swapped in landmine press", message: "Your shoulder felt tight on Tuesday. Same pattern, less strain.") {
                    PillButton(title: "Undo") {}
                }
            }
            .padding(.horizontal, AZSpacing.gutter)
        }
        .background(AZColor.background)
    }
}

#Preview { TodayView() }
