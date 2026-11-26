import AZModel
import AZSync
import BridgeKit
import Foundation

// div: run Div's jobs by hand, run the evals, and serve chat's read tools to Claude.
// Each job uses some of your Claude plan's usage (your own `claude` login, never an API key).

let usage = """
    Usage: div <command> [options]

      review  <file>                 weekly review of a snapshot (or a Div/evals/weekly-review fixture)
      session <file>                 session review of a workout (or a Div/evals/session-review fixture)
      meal    <photo> [--note text] [--plate cm] [--weight g]
      revise  <file>                 revise a meal estimate with an answer (a Div/evals/revise-meal fixture)
      workout <file>                 tweak the next set mid-workout (a Div/evals/in-workout fixture)
      chat    <message> [--data file]  chat with Div over a DivData file (default Div/evals/chat/data.json)
      eval    [job] [filter]         run the evals for one job (e.g. chat, estimate-meal) or all of them
      tools   --data f --tools f [--log f]   serve the read tools over MCP on stdin/stdout (Claude starts this)
      weekly  [--week YYYY-MM-DD]    run the Sunday review now for everyone paired (default: the last Sunday)
      serve   [--pair]               be the bridge for the phone, like the menu bar app (and run Sunday reviews); --pair prints a pairing code

    Options: --json prints the full result. --ask-first turns off everything Div may do without asking.
    """

var args = Array(CommandLine.arguments.dropFirst())
@MainActor func flag(_ name: String) -> Bool {
    guard let i = args.firstIndex(of: name) else { return false }
    args.remove(at: i)
    return true
}
@MainActor func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let value = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return value
}
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

/// Reads a job input from a file: the value under `key` if it's a fixture, otherwise the whole file.
func input<T: Decodable>(_ type: T.Type, _ path: String, key: String) throws -> T {
    let data = try Data(contentsOf: URL(filePath: path))
    if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let inner = object[key] {
        return try Validation.decode(T.self, from: JSONSerialization.data(withJSONObject: inner))
    }
    return try Validation.decode(T.self, from: data)
}

func show(_ value: some Encodable) throws { print(try DivJSON.string(value)) }

func verdictLabel(_ verdict: Verdict) -> String {
    switch verdict {
    case .apply: "APPLIED "
    case .propose: "ASKS    "
    case .refuse: "REFUSED "
    }
}

func describe(_ change: PlanChange) -> String {
    switch change {
    case .setCalorieTarget(let kcal): "calorie target -> \(kcal) kcal"
    case .setProteinTarget(let g): "protein -> \(g) g/kg"
    case .setLoad(let exercise, let load): "\(exercise) -> \(load) kg"
    case .swapExercise(let from, let to, let weeks): "swap \(from) -> \(to)" + (weeks > 0 ? " for \(weeks) weeks" : " for good")
    case .moveSession(let session, let day, let once): "move \(session) -> \(day)" + (once ? " this week" : " in the plan")
    case .changeVolume(let muscle, let delta): "\(muscle) \(delta > 0 ? "+" : "")\(delta) sets/week"
    case .scheduleDeload(let start, let weeks): "deload \(weeks) week(s) from \(start)"
    }
}

func printChanges(_ checked: [Checked<Proposal>]) {
    for c in checked {
        print("  \(verdictLabel(c.verdict)) \(describe(c.item.change))")
        print("           \(c.item.reason)")
        for note in c.notes { print("           note: \(note)") }
    }
}

func printRun(_ run: RunInfo) {
    print("\n(\(run.summary))")
}

@MainActor func makeDiv() throws -> Div {
    let executable = URL(filePath: CommandLine.arguments[0]).standardizedFileURL
    let path = executable.path.hasPrefix("/") ? executable.path : FileManager.default.currentDirectoryPath + "/" + executable.path
    return Div(
        files: try DivFiles.locate(), claude: try ClaudeCLI.locate(), autonomy: flag("--ask-first") ? .askFirst : .standard,
        toolServer: [path, "tools"])
}

do {
    let json = flag("--json")
    guard let command = args.first else { fail(usage) }
    args.removeFirst()

    switch command {
    case "tools":
        guard let dataPath = option("--data"), let toolsPath = option("--tools") else { fail("tools needs --data and --tools") }
        let data = try DivJSON.decode(DivData.self, from: Data(contentsOf: URL(filePath: dataPath)))
        let server = DivToolServer(
            data: data, definitions: try Data(contentsOf: URL(filePath: toolsPath)), log: option("--log").map { URL(filePath: $0) })
        try await server.serve()

    case "review":
        let div = try makeDiv()
        guard let path = args.first else { fail("review needs a file") }
        let r = try await div.weeklyReview(try input(WeeklySnapshot.self, path, key: "snapshot"))
        if json {
            try show(r)
        } else {
            print(r.output.summary)
            print("\nCalories: \(r.output.calorieAction.rawValue) (\(r.output.calorieReading.rawValue)). \(r.output.calorieReasoning)")
            if !r.checked.isEmpty { print("\nChanges:") }
            printChanges(r.checked)
            if !r.output.questions.isEmpty { print("\nQuestions:\n" + r.output.questions.map { "  - \($0)" }.joined(separator: "\n")) }
            printRun(r.run)
        }

    case "session":
        let div = try makeDiv()
        guard let path = args.first else { fail("session needs a file") }
        let r = try await div.sessionReview(try input(SessionReport.self, path, key: "session"))
        if json {
            try show(r)
        } else {
            print(r.output.note + "\n\nNext time:")
            for c in r.checked {
                print("  \(verdictLabel(c.verdict)) \(c.item.exercise): \(c.item.call.rawValue), \(c.item.nextLoadKg) kg")
                if !c.item.reason.isEmpty { print("           \(c.item.reason)") }
                for note in c.notes { print("           note: \(note)") }
            }
            printRun(r.run)
        }

    case "meal":
        let div = try makeDiv()
        let note = option("--note")
        let plate = option("--plate").flatMap(Double.init)
        let weight = option("--weight").flatMap(Double.init)
        guard let path = args.first else { fail("meal needs a photo") }
        let types: [String: MealPhotoRequest.MediaType] = ["jpg": .jpeg, "jpeg": .jpeg, "png": .png, "webp": .webp]
        guard let type = types[URL(filePath: path).pathExtension.lowercased()] else { fail("the photo must be JPEG, PNG or WebP") }
        let request = MealPhotoRequest(
            photo: try Data(contentsOf: URL(filePath: path)), mediaType: type, note: note, plateDiameterCm: plate, foodWeightG: weight)
        let problems = Validation.check(request)
        if !problems.isEmpty { fail(problems.joined(separator: "\n")) }
        let r = try await div.estimateMeal(request)
        if json {
            try show(r)
        } else {
            print(
                "\(r.estimate.mealName): \(r.totals.kcal) kcal (range \(Int(r.estimate.kcalLow)) to \(Int(r.estimate.kcalHigh)), \(r.estimate.confidence.rawValue) confidence)"
            )
            print("P \(r.totals.proteinG) g, C \(r.totals.carbsG) g, F \(r.totals.fatG) g\n")
            for item in r.estimate.items { print("  \(item.name), \(item.portion) (\(Int(item.grams)) g): \(Int(item.kcal)) kcal") }
            if !r.estimate.assumptions.isEmpty { print("\nAssumed: " + r.estimate.assumptions.joined(separator: "; ")) }
            if !r.estimate.followUpQuestion.isEmpty { print("Question: \(r.estimate.followUpQuestion)") }
            for w in r.warnings { print("Warning: \(w)") }
            printRun(r.run)
        }

    case "revise":
        let div = try makeDiv()
        guard let path = args.first else { fail("revise needs a file") }
        let request = try input(MealRevisionRequest.self, path, key: "request")
        let r = try await div.reviseMeal(request)
        if json {
            try show(r)
        } else {
            print("Q: \(request.question)\nA: \(request.answer)\n")
            print("\(r.estimate.mealName): \(r.totals.kcal) kcal (was \(Int(request.previous.items.map(\.kcal).reduce(0, +))))")
            for item in r.estimate.items { print("  \(item.name), \(item.portion) (\(Int(item.grams)) g): \(Int(item.kcal)) kcal") }
            for w in r.warnings { print("Warning: \(w)") }
            printRun(r.run)
        }

    case "workout":
        let div = try makeDiv()
        guard let path = args.first else { fail("workout needs a file") }
        let r = try await div.inWorkout(try input(InWorkoutRequest.self, path, key: "request"))
        if json {
            try show(r)
        } else {
            let o = r.checked.item
            print("\(verdictLabel(r.checked.verdict)) \(o.call.rawValue): next set \(o.nextLoadKg) kg x \(o.nextReps), rest \(o.restS) s")
            print("           \(o.reason)")
            for note in r.checked.notes { print("           note: \(note)") }
            printRun(r.run)
        }

    case "chat":
        let div = try makeDiv()
        let dataPath = option("--data") ?? div.files.evalsURL.appending(path: "chat/data.json").path
        guard !args.isEmpty else { fail("chat needs a message") }
        let data = try DivJSON.decode(DivData.self, from: Data(contentsOf: URL(filePath: dataPath)))
        let r = try await div.chat(ChatRequest(message: args.joined(separator: " ")), data: data)
        if json {
            try show(r)
        } else {
            print("Div: \(r.output.reply)")
            if !r.checked.isEmpty { print("\nChanges:") }
            printChanges(r.checked)
            if !r.output.remember.isEmpty { print("\nRemembers: " + r.output.remember.joined(separator: "; ")) }
            print("\nLooked up: " + (r.toolCalls.isEmpty ? "nothing" : r.toolCalls.joined(separator: ", ")))
            printRun(r.run)
        }

    case "serve":
        setvbuf(stdout, nil, _IOLBF, 0)  // a line at a time, so a log file shows each event as it happens
        let pair = flag("--pair")
        let div = try makeDiv()
        let files = div.files
        let cli = try ClaudeCLI.locate()
        let store = PairingStore.standard()
        let name = (Host.current().localizedName ?? "Mac") + " (div serve)"
        let jobs = PhoneJobs(
            div: { div }, people: .standard(), sampleData: PhoneJobs.sampleData(files),
            onRun: { name, run in print("ran \(name): \(run.summary)") })
        let server = BridgeServer(
            store: store, bridgeName: name, status: { await cli.authStatus() },
            handle: { request in
                switch request.job {
                case .chat(let chat): print("chat: \(chat.message)")
                case .sync(let push): print("sync: \(push.batch.rows.count) rows from the phone")
                case .sessionReview(let review): print("session review: workout \(review.workoutID)")
                case .estimateMeal(let photo): print("meal photo: \(photo.photo.count / 1024) KB")
                case .reviseMeal(let revision): print("meal answer: \(revision.answer)")
                }
                let outcome = await jobs.handle(request)
                switch outcome {
                case .chat(let reply): print("answer: \(reply.reply)")
                case .synced(let pull): print("synced: \(pull.batch.rows.count) rows to the phone")
                case .sessionReviewed(let reply):
                    print("reviewed: \(reply.note) (\(reply.applied) applied, \(reply.proposed) to check)")
                case .mealEstimated(let reply): print("meal: \(reply.estimate.mealName), \(reply.totals.kcal) kcal")
                case .failed(let why): print("failed: \(why)")
                }
                return outcome
            },
            onChange: { snapshot in
                print("listening on \(snapshot.port.map(String.init) ?? "-"), phones: \(snapshot.phones.map(\.name))")
                if let problem = snapshot.problem { print(problem) }
            })
        print("Claude: \(await cli.authStatus().label)")
        if pair {
            let host = ProcessInfo.processInfo.hostName
            let code = store.newCode(bridgeName: name, hosts: host.isEmpty ? [] : [host], port: BridgeService.preferredPort)
            print("Pairing code (paste it in the app, valid 15 minutes):\n\(code.text)")
        } else if store.pairings.isEmpty {
            fail("No phones paired yet. Run with --pair.")
        }
        server.start()
        let reviews = WeeklyReviews(
            div: { div }, people: .standard(), onRun: { name, run in print("ran \(name): \(run.summary)") })
        while true {
            for line in await reviews.runDue() { print("weekly review \(line)") }
            try await Task.sleep(for: .seconds(3600))
        }

    case "weekly":
        let div = try makeDiv()
        let week = option("--week") ?? WeeklyReviews.sunday(onOrBefore: Day.string(.now))
        let people = PeopleStores.standard()
        let reviews = WeeklyReviews(div: { div }, people: people, onRun: { _, run in printRun(run) })
        if people.people().isEmpty { print("No one has synced to this Mac yet.") }
        for person in people.people() {
            let outcome = try await reviews.review(person, week: week, today: Day.string(.now))
            print("\(person.uuidString.prefix(8)), week ending \(week): \(outcome)")
            if let review = try people.store(for: person).weekReview(weekEnding: week), outcome.hasPrefix("reviewed") {
                print(review.summary)
                for q in review.questions { print("  ? \(q)") }
            }
        }

    case "eval":
        let div = try makeDiv()
        let jobs = args.first.flatMap(DivJob.init(rawValue:)).map { [$0] } ?? DivJob.allCases
        if args.first.flatMap(DivJob.init(rawValue:)) != nil { args.removeFirst() }
        let evals = DivEvals(div: div)
        let scenarios = evals.scenarios(jobs: jobs, filter: args.first)
        if scenarios.isEmpty { fail("no scenarios match") }
        print("Running \(scenarios.count) scenarios through your Claude plan...\n")
        let outcomes = await evals.run(scenarios) { o in
            print("\(o.passed ? "PASS" : "FAIL")  \(o.job.rawValue)/\(o.name): \(o.summary)")
            for d in o.details where !o.passed || d.hasPrefix("refused") { print("        \(d)") }
        }
        let passed = outcomes.filter(\.passed).count
        print("\n\(passed)/\(outcomes.count) passed")
        exit(passed == outcomes.count ? 0 : 1)

    default:
        fail(usage)
    }
} catch {
    fail("\(error)")
}
