import SwiftUI

/// Four tabs, matching the design: Home, Train, Eat, Body. Quick add sits in the middle of the custom tab bar
/// (to build: design/screens/QuickAdd.dc.html). Div lives behind its avatar on every screen, not in a tab.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { TodayView() }
            Tab("Train", systemImage: "dumbbell") { TrainView() }
            Tab("Eat", systemImage: "fork.knife") { EatView() }
            Tab("Body", systemImage: "figure.stand") { BodyView() }
        }
        .tint(AZColor.accent)
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview())
}
