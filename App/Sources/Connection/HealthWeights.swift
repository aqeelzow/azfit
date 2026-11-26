import AZModel
import AZStore
import Foundation
import HealthKit
import Observation

/// Body weight from Apple Health. Connecting brings in every reading Health has; after that, each time the app opens
/// it reads the last 90 days for anything new or late-arriving. Nothing is ever dropped from AZfit; the Health sample's ID keeps each one from coming in twice. Read only: AZfit doesn't
/// write weigh-ins back, so its own entries never return as duplicates.
@MainActor
@Observable
final class HealthWeights {
    /// The person turned it on. Health never says whether reading was allowed, so this is what's remembered.
    private(set) var isConnected: Bool
    private(set) var isSyncing = false
    /// What the last sync found, for the screen.
    private(set) var lastAdded: Int?
    private(set) var problem: String?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    @ObservationIgnored private let health = HKHealthStore()
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "health.weight.connected"
    private static let bodyMass = HKQuantityType(.bodyMass)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isConnected = defaults.bool(forKey: Self.key)
    }

    /// Asks Health for weight, then reads it in.
    func connect(into store: AZStore) async {
        guard isAvailable else {
            problem = "Apple Health isn't available on this device."
            return
        }
        do {
            try await health.requestAuthorization(toShare: [], read: [Self.bodyMass])
            isConnected = true
            defaults.set(true, forKey: Self.key)
            await sync(into: store, allHistory: true)
        } catch {
            problem = "Couldn't connect to Apple Health: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        isConnected = false
        lastAdded = nil
        defaults.set(false, forKey: Self.key)
    }

    /// Reads weight into the store: the last 90 days, or everything Health has. Returns how many weigh-ins were new.
    @discardableResult
    func sync(into store: AZStore, allHistory: Bool = false) async -> Int {
        guard isConnected, isAvailable, !isSyncing else { return 0 }
        isSyncing = true
        defer { isSyncing = false }
        let since = allHistory ? .distantPast : Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: Self.bodyMass, predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        do {
            let samples = try await query.result(for: health)
            let weighIns = samples.map { sample in
                WeighIn(
                    id: sample.uuid, day: Day.string(sample.startDate), at: sample.startDate,
                    kg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), source: .health)
            }
            let added = try store.importWeighIns(weighIns)
            lastAdded = added
            problem = nil
            return added
        } catch {
            problem = "Couldn't read Apple Health: \(error.localizedDescription)"
            return 0
        }
    }
}
