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
    @Test func groupsAnExerciseByItsMainMuscle() throws {
        let library = Library.standard
        #expect(library.group(of: try #require(library.exercise("overhead_press")))?.name == "Shoulders")
        #expect(library.group(of: try #require(library.exercise("barbell_bench_press")))?.name == "Chest")
        #expect(try #require(library.exercise("barbell_bench_press")).equipmentName == "Barbell")
        #expect(try #require(library.exercises.first { $0.equipment == "ez_bar" }).equipmentName == "EZ bar")
    }

    @Test func alternativesShareTheMainMusclesClosestFirst() throws {
        let library = Library.standard
        let bench = try #require(library.exercise("barbell_bench_press"))
        let alternatives = library.alternatives(to: bench)
        #expect(!alternatives.contains { $0.id == bench.id })
        #expect(alternatives.allSatisfy { $0.muscles["lower_chest"] == 1 })
        // Same muscles, same shares: the dumbbell and Smith versions come before the machine press, which skips upper chest.
        let ids = alternatives.map(\.id)
        let dumbbell = try #require(ids.firstIndex(of: "dumbbell_bench_press"))
        let machine = try #require(ids.firstIndex(of: "machine_chest_press"))
        #expect(dumbbell < machine)
    }

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

    @Test func weighInFieldsRoundTrip() throws {
        #expect(UnitSystem.canadian.bodyWeightFields(80).main == "176.4")
        #expect(UnitSystem.british.bodyWeightFields(80) == ("12", "8.4"))
        #expect(abs(try #require(UnitSystem.american.bodyWeightKg(typed: "176,4")) - 80.01) < 0.01)
        #expect(abs(try #require(UnitSystem.british.bodyWeightKg(typed: "12", pounds: "8.4")) - 80) < 0.05)
        #expect(abs(try #require(UnitSystem.british.bodyWeightKg(typed: "12")) - 76.2) < 0.01)
    }

    @Test func weighInFieldsRefuseTypos() {
        #expect(UnitSystem.canadian.bodyWeightKg(typed: "") == nil)
        #expect(UnitSystem.canadian.bodyWeightKg(typed: "abc") == nil)
        #expect(UnitSystem.canadian.bodyWeightKg(typed: "1760") == nil)
        #expect(UnitSystem.british.bodyWeightKg(typed: "12.5", pounds: "2") == nil)
        #expect(UnitSystem.british.bodyWeightKg(typed: "12", pounds: "15") == nil)
    }
}

@Suite struct MealTimeTests {
    @Test func namesTheMealByTheHour() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        func at(_ hour: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(hour * 3600)) }
        #expect(Meal.mealTime(at: at(8), calendar: calendar) == "Breakfast")
        #expect(Meal.mealTime(at: at(13), calendar: calendar) == "Lunch")
        #expect(Meal.mealTime(at: at(16), calendar: calendar) == "Snack")
        #expect(Meal.mealTime(at: at(19), calendar: calendar) == "Dinner")
        #expect(Meal.mealTime(at: at(23), calendar: calendar) == "Snack")
    }

    @Test func loggingAMealAgainMakesANewRow() {
        let first = Meal(
            day: "2026-11-24", name: "Chicken bowl", kcal: 640, kcalLow: 560, kcalHigh: 720, proteinG: 48, carbsG: 62, fatG: 18,
            source: .photo, barcode: "123", isFavorite: true, removed: true)
        let again = first.again(day: "2026-11-25", at: Date(timeIntervalSince1970: 0))
        #expect(again.id != first.id)
        #expect(again.day == "2026-11-25")
        #expect(again.at == Date(timeIntervalSince1970: 0))
        #expect(again.name == first.name && again.kcal == 640 && again.kcalLow == 560 && again.kcalHigh == 720)
        #expect(again.proteinG == 48 && again.carbsG == 62 && again.fatG == 18)
        #expect(again.source == .favorite && again.barcode == nil && !again.isFavorite && !again.removed)
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

@Suite struct FoodTests {
    private let bar = Food(
        id: "off:1", name: "Protein bar", barcode: "1", per100g: .init(kcal: 400, proteinG: 50, carbsG: 30, fatG: 10),
        serving: .init(label: "1 bar", grams: 60), origin: .database)

    @Test func amountsScaleFromGramsOrServings() throws {
        #expect(bar.units == [.servings, .grams])
        #expect(bar.nutrients(150, .grams) == .init(kcal: 600, proteinG: 75, carbsG: 45, fatG: 15))
        #expect(bar.nutrients(2, .servings) == .init(kcal: 480, proteinG: 60, carbsG: 36, fatG: 12))
        #expect(bar.nutrients(0, .grams) == nil)
        #expect(bar.amountLabel(1, .servings) == "1 bar")
        #expect(bar.amountLabel(1.5, .servings) == "1.5 servings")
        #expect(bar.detail == "1 bar (60 g)")
        var pot = bar
        pot.serving = .init(label: "1 pot (170 g)", grams: 170)
        #expect(pot.detail == "1 pot (170 g)")
    }

    @Test func aFoodLogsToTheMealPicked() throws {
        let meal = try #require(bar.meal(1, .servings, day: "2026-11-26", slot: .snacks))
        #expect(meal.kcal == 240 && meal.proteinG == 30 && meal.slot == .snacks && meal.source == .barcode)
    }

    @Test func customFoodsCountOnlyInServings() {
        let wrap = CustomFood(name: "Wrap", servingLabel: "1 wrap", kcal: 450, proteinG: 30, carbsG: 40, fatG: 15).food
        #expect(wrap.units == [.servings])
        #expect(wrap.nutrients(100, .grams) == nil)
        #expect(wrap.nutrients(2, .servings)?.kcal == 900)
    }

    @Test func oldMealsFallIntoTheMealOfTheirTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let eight = Date(timeIntervalSince1970: 8 * 3600)
        #expect(Meal.Slot.at(eight, calendar: calendar) == .breakfast)
        #expect(Meal.Slot.at(eight.addingTimeInterval(11 * 3600), calendar: calendar) == .dinner)
        #expect(Meal.Slot.at(eight.addingTimeInterval(8 * 3600), calendar: calendar) == .snacks)
    }
}
