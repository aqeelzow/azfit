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
    @Environment(AppEnvironment.self) private var environment

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
        // Div reviews finished workouts whenever it can: right away, or once the Mac is back.
        .onChange(of: environment.bridge.isReady, initial: true) { _, ready in
            if ready { environment.reviewFinishedWorkouts() }
        }
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
        case .session(let id): SessionView(sessionID: id)
        case .workout(let id): WorkoutView(sessionID: id)
        case .workoutDone: WorkoutDoneView()
        case .swapExercise(let exerciseID): SwapExerciseView(replacing: exerciseID)
        case .exercise(let exerciseID): ExerciseView(exerciseID: exerciseID)
        case .chat: DivChatView()
        case .divLog: DivLogView()
        case .memory: MemoryView()
        case .connectMac: ConnectMacView()
        case .addFood(let slot): AddFoodView(slot: slot ?? .at(.now))
        case .food(let food, let slot): FoodDetailView(food: food, slot: slot)
        case .foodHit(let hit, let slot): DatabaseFoodView(hit: hit, slot: slot)
        case .createFood(let slot, let barcode): CreateFoodView(slot: slot, barcode: barcode)
        case .quickAdd(let slot): DescribeMealView(slot: slot)
        case .mealEstimate(let photo): MealView(photo: photo)
        case .calorieTarget: CalorieTargetView()
        case .editTargets: EditTargetsView()
        case .weighIn: WeighInView()
        case .measurements: ScanResultView()
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
