import SwiftUI

/// First run until onboarding saves the person, then the main app. "I already have an account" skips straight to
/// the main app for this launch.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var skipped = false

    private var isOnboarded: Bool { skipped || environment.profile != nil }

    var body: some View {
        if isOnboarded {
            MainView().transition(.opacity)
        } else {
            OnboardingFlow { withAnimation(.easeInOut(duration: 0.3)) { skipped = true } }
        }
    }
}

/// Four tabs (Home, Train, Eat, Body) under one navigation stack, with the custom tab bar and quick add on top.
/// Div lives behind its avatar and notes on every screen, not in a tab.
struct MainView: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            tabContent
                .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: TabBar.height - 34) }
                .overlay { QuickAddOverlay(router: router) }
                .overlay(alignment: .bottom) {
                    TabBar(
                        selection: $router.tab, isQuickAddOpen: router.isQuickAddOpen,
                        onQuickAdd: { withAnimation(.snappy(duration: 0.28)) { router.isQuickAddOpen.toggle() } },
                        onSelect: { tab in withAnimation(.snappy(duration: 0.2)) { router.show(tab) } }
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
                .azScreen()
                .navigationDestination(for: Router.Route.self) { route in destination(route) }
        }
        .environment(router)
        #if os(iOS)
        .fullScreenCover(item: $router.cover) { cover in coverView(cover) }
        #else
        .sheet(item: $router.cover) { cover in coverView(cover) }
        #endif
    }

    @ViewBuilder
    private var tabContent: some View {
        switch router.tab {
        case .home: HomeView()
        case .train: TrainView()
        case .eat: EatView()
        case .body: BodyView()
        }
    }

    @ViewBuilder
    private func destination(_ route: Router.Route) -> some View {
        switch route {
        case .workout: WorkoutView()
        case .workoutDone: WorkoutDoneView()
        case .swapExercise: SwapExerciseView()
        case .exercise: ExerciseView()
        case .chat: DivChatView()
        case .divLog: DivLogView()
        case .memory: MemoryView()
        case .connectMac: ConnectMacView()
        case .meal: MealView()
        case .calorieTarget: CalorieTargetView()
        case .scanResult: ScanResultView()
        case .progress: BodyProgressView()
        }
    }

    @ViewBuilder
    private func coverView(_ cover: Router.Cover) -> some View {
        Group {
            switch cover {
            case .snap: SnapMealView()
            case .voice: VoiceView()
            case .scan: BodyScanView()
            }
        }
        .environment(router)
        .preferredColorScheme(.dark)
    }
}

#Preview("First run") {
    RootView().environment(AppEnvironment.preview())
}

#Preview("Main") {
    MainView().environment(AppEnvironment.preview())
}
