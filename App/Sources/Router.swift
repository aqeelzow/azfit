import AZModel
import AZSync
import Foundation
import Observation
import SwiftUI

/// Where you can go from anywhere in the app. Screens call `router.push(.meal)` instead of knowing about each other.
@MainActor
@Observable
final class Router {
    enum Tab: CaseIterable { case home, train, eat, body }

    /// Screens pushed on top of the tabs.
    enum Route: Hashable {
        /// A planned session's exercises, and starting it on any day.
        case session(UUID)
        /// The live workout for a planned session.
        case workout(UUID)
        case workoutDone
        /// The exercise library, or swapping the given exercise in the plan for another.
        case swapExercise(String?)
        /// One exercise, by its `Library` ID.
        case exercise(String)
        case chat, divLog, memory, connectMac
        /// Searching, scanning or making a food to log to a meal (nil: the meal of the time of day).
        case addFood(Meal.Slot?)
        /// An amount of one food, logged to a meal.
        case food(Food, Meal.Slot)
        /// A search match, whose label is read when it opens.
        case foodHit(FoodDatabase.Hit, Meal.Slot)
        /// Making a food, with the barcode that wasn't found when there was one.
        case createFood(Meal.Slot, barcode: String?)
        /// Typing calories and macros straight in. And Div's estimate of a meal photo.
        case quickAdd(Meal.Slot)
        case mealEstimate(MealPhoto)
        case calorieTarget
        /// Changing your own calorie, macro and water targets (Div then weighs in).
        case editTargets
        case weighIn, measurements, progress
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
    /// A day for Train to pick when it shows, from tapping it in Home's week strip.
    var trainDay: String?

    func push(_ route: Route) {
        isQuickAddOpen = false
        path.append(route)
    }

    func present(_ cover: Cover) {
        isQuickAddOpen = false
        self.cover = cover
    }

    /// Close the camera or voice screen, then go on to a pushed screen (a photo opens its estimate).
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

    /// The Train tab with `day` picked in its week strip.
    func showTrain(on day: String) {
        trainDay = day
        show(.train)
    }

    /// Swaps the top screen for another, so back skips the one replaced.
    func replaceTop(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    /// Back one screen.
    func pop() {
        if !path.isEmpty { path.removeLast() }
    }
}

/// A meal photo on its way to Div: a JPEG ready to send (`PhotoPrep`). Compared by `id`, so routes stay cheap.
struct MealPhoto: Hashable {
    let id = UUID()
    let jpeg: Data
    let takenAt: Date

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
