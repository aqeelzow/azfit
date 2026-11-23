import SwiftUI

/// First run: welcome, goal, days, connect the bridge. Design: design/screens/Welcome.dc.html, Goal, Days, Connect
struct WelcomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AZSpacing.stack) {
            Spacer()
            DivAvatar(size: 72)
            Text("A coach that actually adjusts.").font(AZFont.h1)
            Text("Div reads every set and meal you log and changes your plan, and always shows you why.")
                .font(AZFont.body).foregroundStyle(AZColor.muted)
            Spacer()
        }
        .padding(.horizontal, AZSpacing.gutter)
        .background(AZColor.background)
    }
}

#Preview { WelcomeView() }
