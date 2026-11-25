import AZModel
import AZStore
import AZSync
import Foundation
import Observation
import UIKit

/// App-wide dependencies, injected through the SwiftUI environment with `.environment(_:)`.
/// Views read it with `@Environment(AppEnvironment.self)` instead of creating things themselves.
@MainActor
@Observable
final class AppEnvironment {
    /// This person's database: everything they log, the plan, and Div's changes (D-005).
    let store: AZStore
    /// The Mac running AZfit Bridge, where Div runs. Syncs `store` with it.
    let bridge: BridgeConnection
    /// The conversation on the Div screen. Kept here so it survives leaving the screen.
    let chat: ChatSession
    /// Who this is. Nil until onboarding saves them.
    private(set) var profile: Profile?
    /// Bumped after every write, so screens reading the store refresh.
    private(set) var revision = 0
    /// Workouts Div is reviewing right now.
    private(set) var reviewing: Set<UUID> = []
    /// Why the last review couldn't run, for the screen.
    private(set) var reviewProblem: String?
    /// Tried this launch, so a failing review doesn't keep spending the person's Claude usage.
    @ObservationIgnored private var attempted: Set<UUID> = []

    init(store: AZStore, bridge: BridgeConnection) {
        self.store = store
        self.bridge = bridge
        bridge.store = store
        chat = ChatSession(bridge: bridge)
        try? store.fillMissingTarget(today: Day.string(.now))
        profile = try? store.profile()
        chat.onChange = { [weak self] in self?.changed() }
    }

    /// Call after writing to the store: screens refresh, and the Mac gets the new rows.
    func changed() {
        profile = try? store.profile()
        revision += 1
        Task { try? await bridge.sync() }
    }

    /// Asks Div to review finished workouts from the last two days that don't have a note yet. Runs after Finish and
    /// whenever the Mac comes back; each workout is tried once per launch.
    func reviewFinishedWorkouts() {
        guard bridge.isReady else { return }
        let since = Day.adding(-2, to: Day.string(.now))
        let pending = ((try? store.workoutsAwaitingReview(since: since)) ?? []).filter { !attempted.contains($0.id) }
        for workout in pending {
            attempted.insert(workout.id)
            reviewing.insert(workout.id)
            Task {
                defer {
                    reviewing.remove(workout.id)
                    revision += 1
                }
                do {
                    if case .failed(let reason) = try await bridge.ask(.sessionReview(SessionReviewRequest(workoutID: workout.id))) {
                        reviewProblem = reason
                    } else {
                        reviewProblem = nil
                    }
                    try await bridge.sync()
                    profile = try? store.profile()
                } catch {
                    reviewProblem = "\(error)"
                }
            }
        }
    }

    /// Saves who they are, their targets and a template plan (D-028).
    func finishOnboarding(_ profile: Profile, weightKg: Double?) {
        do {
            try store.start(profile, weightKg: weightKg, today: Day.string(.now))
        } catch {
            assertionFailure("Couldn't save onboarding: \(error)")
        }
        changed()
    }

    static func live() -> AppEnvironment {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let store: AZStore
        do {
            store = try AZStore(url: support.appending(path: "AZfit/azfit.sqlite"))
        } catch {
            fatalError("Couldn't open the database: \(error)")
        }
        return AppEnvironment(store: store, bridge: BridgeConnection(storage: KeychainPairingStorage(), phoneName: UIDevice.current.name))
    }

    /// An in-memory person with a 4-day plan, for previews.
    static func preview() -> AppEnvironment {
        let store = try! AZStore.inMemory()
        try? store.start(
            Profile(name: "Alex", sex: .male, birthYear: 1997, heightCm: 180, goal: .cut, trainingDays: 4), weightKg: 84,
            today: Day.string(.now))
        return AppEnvironment(store: store, bridge: BridgeConnection(storage: MemoryPairingStorage(), phoneName: "iPhone"))
    }
}
