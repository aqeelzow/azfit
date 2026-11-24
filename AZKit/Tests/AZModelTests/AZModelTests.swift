import Foundation
import Testing

@testable import AZModel

@Suite struct DivJSONTests {
    @Test func proposalsRoundTripAsFlatSnakeCaseJSON() throws {
        let json = #"{"type":"set_load","exercise":"Bench press","new_load_kg":82.5,"reason":"r","evidence":["e"]}"#
        let p = try DivJSON.decode(Proposal.self, from: Data(json.utf8))
        #expect(p.change == .setLoad(exercise: "Bench press", newLoadKg: 82.5))
        let back = try DivJSON.string(p, pretty: false)
        #expect(back == #"{"evidence":["e"],"exercise":"Bench press","new_load_kg":82.5,"reason":"r","type":"set_load"}"#)
    }

    @Test func unknownChangeTypesAreRejected() {
        let json = #"{"type":"log_food","reason":"r","evidence":[]}"#
        #expect(throws: DecodingError.self) { try DivJSON.decode(Proposal.self, from: Data(json.utf8)) }
    }

    @Test func enumValuesStaySnakeCase() throws {
        let out = WeeklyReviewOutput(calorieReading: .surplusTooBig, calorieAction: .decrease)
        #expect(try DivJSON.string(out).contains(#""calorie_reading" : "surplus_too_big""#))
    }

    @Test func keysWithDigitsRoundTrip() throws {
        #expect(DivJSON.snakeCase("bestE1rm") == "best_e1rm")
        #expect(DivJSON.snakeCase("proteinGPerKg") == "protein_g_per_kg")
        let derived = SessionDerived.Exercise(
            exercise: "Bench", setsDone: 3, setsPrescribed: 3, bestE1rm: 112, e1rmChangePctVsLast: 1, allSetsAtTopOfRange: true,
            avgRir: 2, rirVsPrescribed: 0)
        let json = try DivJSON.string(derived)
        #expect(json.contains("\"best_e1rm\"") && json.contains("\"e1rm_change_pct_vs_last\""))
        #expect(try DivJSON.decode(SessionDerived.Exercise.self, from: Data(json.utf8)) == derived)
    }
}
