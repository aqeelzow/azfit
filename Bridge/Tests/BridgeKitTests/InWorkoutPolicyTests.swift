import AZModel
import Testing

@testable import BridgeKit

@Suite struct InWorkoutPolicyTests {
    func verdict(_ out: InWorkoutOutput, _ autonomy: Autonomy = .standard) throws -> Verdict {
        let request = try fixture("in-workout", "reps-dropping", key: "request", as: InWorkoutRequest.self)
        return InWorkoutPolicy.check(out, request: request, autonomy: autonomy).verdict
    }

    @Test func keepingAndDroppingRepsAreRoutine() throws {
        #expect(try verdict(InWorkoutOutput(call: .keep, nextLoadKg: 50, nextReps: 8, restS: 120)) == .apply)
        #expect(try verdict(InWorkoutOutput(call: .lowerReps, nextLoadKg: 50, nextReps: 6, restS: 150)) == .apply)
        #expect(try verdict(InWorkoutOutput(call: .lowerReps, nextLoadKg: 50, nextReps: 6, restS: 150), .askFirst) == .propose)
    }

    @Test func loadDropsUpTo10PercentApplyBiggerAskHugeAreRefused() throws {
        #expect(try verdict(InWorkoutOutput(call: .lowerLoad, nextLoadKg: 47.5, nextReps: 6, restS: 120)) == .apply)
        #expect(try verdict(InWorkoutOutput(call: .lowerLoad, nextLoadKg: 42.5, nextReps: 6, restS: 120)) == .propose)
        #expect(try verdict(InWorkoutOutput(call: .lowerLoad, nextLoadKg: 35, nextReps: 6, restS: 120)) == .refuse)
    }

    @Test func goingHeavierOrStoppingIsAlwaysThePersonsCall() throws {
        #expect(try verdict(InWorkoutOutput(call: .raiseLoad, nextLoadKg: 52.5, nextReps: 6, restS: 120)) == .propose)
        #expect(try verdict(InWorkoutOutput(call: .raiseLoad, nextLoadKg: 60, nextReps: 6, restS: 120)) == .refuse)
        #expect(try verdict(InWorkoutOutput(call: .stop, nextLoadKg: 50, nextReps: 6, restS: 120)) == .propose)
    }

    @Test func callsThatContradictTheirNumbersAreRefused() throws {
        #expect(try verdict(InWorkoutOutput(call: .keep, nextLoadKg: 45, nextReps: 8, restS: 120)) == .refuse)
        #expect(try verdict(InWorkoutOutput(call: .lowerReps, nextLoadKg: 45, nextReps: 6, restS: 120)) == .refuse)
        #expect(try verdict(InWorkoutOutput(call: .keep, nextLoadKg: 50, nextReps: 0, restS: 120)) == .refuse)
        #expect(try verdict(InWorkoutOutput(call: .keep, nextLoadKg: 50, nextReps: 8, restS: 5)) == .refuse)
    }
}
