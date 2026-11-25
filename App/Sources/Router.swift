import Observation
import SwiftUI

/// Where you can go from anywhere in the app. Screens call `router.push(.meal)` instead of knowing about each other.
@MainActor
@Observable
final class Router {
    enum Tab: CaseIterable { case home, train, eat, body }

    /// Screens pushed on top of the tabs.
    enum Route: Hashable {
        case workout, workoutDone, swapExercise, exercise
        case chat, divLog, memory, connectMac
        case meal, calorieTarget
        case scanResult, progress
    }

    /// Full-screen, always-dark screens that slide up over everything.
    enum Cover: String, Identifiable {
        case snap, voice, scan
        var id: String { rawValue }
    }

    var tab: Tab = .home
    var path: [Route] = []
    var cover: Cover?
    var isQuickAddOpen = false

    func push(_ route: Route) {
        isQuickAddOpen = false
        path.append(route)
    }

    func present(_ cover: Cover) {
        isQuickAddOpen = false
        self.cover = cover
    }

    /// Close the camera or voice screen, then go on to a pushed screen ("Use it" opens the estimate).
    func dismissCover(thenPush route: Route? = nil) {
        cover = nil
        guard let route else { return }
        if path.last != route { path.append(route) }
    }

    /// Back to a tab's root, closing anything pushed on top.
    func show(_ tab: Tab) {
        isQuickAddOpen = false
        path = []
        self.tab = tab
    }
}
