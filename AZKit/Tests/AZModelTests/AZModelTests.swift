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

    @Test func swapWeeksAndOneOffMovesRoundTrip() throws {
        for change in [
            PlanChange.swapExercise(from: "A", to: "B", weeks: 2), .moveSession(session: "Legs", toDay: "Friday", thisWeekOnly: true),
        ] {
            let p = Proposal(change, reason: "r")
            #expect(try DivJSON.decode(Proposal.self, from: DivJSON.encode(p)) == p)
        }
        #expect(try DivJSON.string(Proposal(.moveSession(session: "Legs", toDay: "Friday", thisWeekOnly: true))).contains("this_week_only"))
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

@Suite struct ChangeSummaryTests {
    @Test func summariesReadLikeTheDesign() {
        #expect(
            PlanChange.swapExercise(from: "Overhead press", to: "Landmine press", weeks: 2).summary
                == ("Swapped in landmine press", "For overhead press · 2 weeks"))
        #expect(PlanChange.swapExercise(from: "RDL", to: "Hip thrust", weeks: 0).summary.detail == "For RDL · for good")
        #expect(
            PlanChange.moveSession(session: "Legs", toDay: "Friday", thisWeekOnly: true).summary == (
                "Legs moved to Friday", "This week only"
            ))
        #expect(PlanChange.setLoad(exercise: "Bench press", newLoadKg: 82.5).summary.title == "Bench press to 82.5 kg")
        #expect(PlanChange.changeVolume(muscle: "Back", deltaSetsPerWeek: 2).summary.title == "Back: +2 sets a week")
    }
}

@Suite struct LibraryTests {
    @Test func everyExerciseNamesRealMusclesAndEveryMuscleHasAGroup() {
        let library = Library.standard
        let muscles = Set(library.muscles.map(\.id))
        #expect(library.exercises.count >= 100)
        #expect(Set(library.exercises.map(\.id)).count == library.exercises.count)
        for exercise in library.exercises {
            #expect(Set(exercise.muscles.keys).isSubset(of: muscles), "\(exercise.id)")
            #expect(!exercise.primaryMuscles.isEmpty, "\(exercise.id)")
            #expect((1...5).contains(exercise.fatigueCost), "\(exercise.id)")
        }
        #expect(Set(library.muscleGroups.flatMap(\.muscles)) == muscles)
        #expect(library.group("shoulders")?.muscles == ["front_delts", "side_delts", "rear_delts"])
        #expect(library.exercise(named: "landmine press")?.id == "landmine_press")
    }

    @Test func everyTemplateUsesLibraryExercisesOnItsTrainingDays() {
        for days in 2...6 {
            let template = PlanTemplate.forDays(days)
            #expect(template.sessions.count == days)
            #expect(template.sessions.map(\.weekday) == PlanTemplate.trainingWeekdays[days])
            for item in template.sessions.flatMap(\.exercises) {
                #expect(Library.standard.exercise(item.exerciseID) != nil, "\(item.exerciseID)")
                #expect(item.repMin <= item.repMax)
            }
        }
        #expect(PlanTemplate.forDays(9).days == 6)
    }
}

@Suite struct UnitTests {
    @Test func eachSystemShowsItsOwnUnits() {
        #expect(UnitSystem.canadian.bodyWeight(80) == "176.4 lb")
        #expect(UnitSystem.american.bodyWeight(80) == "176.4 lb")
        #expect(UnitSystem.british.bodyWeight(80) == "12 st 8 lb")
        #expect(UnitSystem.british.load(61) == "61.25 kg")
        #expect(UnitSystem.canadian.load(100) == "220 lb")
        #expect(UnitSystem.american.tape(81.28) == "32.0 in")
        #expect(UnitSystem.canadian.tape(81.4) == "81.4 cm")
        #expect(UnitSystem.british.height(180) == "5′ 11″")
    }

    @Test func inputComesBackInMetric() {
        #expect(abs(UnitSystem.american.loadKg(225) - 102.06) < 0.01)
        #expect(UnitSystem.british.loadKg(100) == 100)
        #expect(abs(UnitSystem.bodyWeightKg(stone: 12, pounds: 8) - 79.83) < 0.01)
        #expect(abs(UnitSystem.heightCm(feet: 5, inches: 11) - 180.34) < 0.01)
    }
}

@Suite struct DayTests {
    @Test func daysAreLocalCalendarDays() {
        #expect(Day.adding(1, to: "2026-12-31") == "2027-01-01")
        #expect(Day.adding(-7, to: "2026-11-25") == "2026-11-18")
        #expect(Day.weekday("2026-11-23") == 1)  // a Monday
        #expect(Day.weekday("2026-11-29") == 7)
    }
}
