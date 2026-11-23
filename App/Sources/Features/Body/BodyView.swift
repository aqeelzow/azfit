import SwiftUI

/// Body: muscle map, weight trend, scans. Design: design/screens/Body.dc.html, Progress.dc.html, Scan.dc.html
struct BodyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AZSpacing.stack) {
                Text("Body").font(AZFont.h1)
                Text("82.2 kg trend · -2.1 kg in 3 weeks").font(AZFont.body).foregroundStyle(AZColor.muted)
            }
            .padding(.horizontal, AZSpacing.gutter)
        }
        .background(AZColor.background)
    }
}

#Preview { BodyView() }
