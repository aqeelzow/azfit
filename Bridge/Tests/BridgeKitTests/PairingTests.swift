import AZModel
import AZStore
import AZSync
import Foundation
import Testing

@testable import BridgeKit

func tempStore() -> PairingStore {
    PairingStore(url: FileManager.default.temporaryDirectory.appending(path: "azfit-test-\(UUID().uuidString)/pairings.json"))
}

@Suite struct PairingStoreTests {
    @Test func keepsTheBridgeIDAndPairingsAcrossLaunches() throws {
        let store = tempStore()
        let code = store.newCode(bridgeName: "Mac", hosts: [], port: 1)
        store.seen(code.pairingID, phoneName: "iPhone")
        let again = PairingStore(url: store.url)
        #expect(again.bridgeID == store.bridgeID)
        #expect(again.pairings.map(\.phoneName) == ["iPhone"])
        let mode = try FileManager.default.attributesOfItem(atPath: store.url.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test func unscannedCodesExpireAndAreReplaced() {
        let store = tempStore()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let first = store.newCode(bridgeName: "Mac", hosts: [], port: 1, now: start)
        #expect(store.keys(now: start).count == 1)
        #expect(store.keys(now: start + PairingStore.codeLifetime + 1).isEmpty)
        let second = store.newCode(bridgeName: "Mac", hosts: [], port: 1, now: start)
        #expect(store.pairings.map(\.id) == [second.pairingID])
        #expect(first.pairingID != second.pairingID)
        store.seen(second.pairingID, phoneName: "iPhone")
        #expect(store.keys(now: start + 365 * 86_400).count == 1)
        store.forget(second.pairingID)
        #expect(store.pairings.isEmpty)
    }

    @Test func runSummaryHasTimeTurnsAndPrice() {
        #expect(
            RunInfo(model: "claude-opus-5-5", durationMs: 24_310, turns: 6, costUsdEquivalent: 0.2141).summary
                == "claude-opus-5-5, 24.3 s, 6 turns, about $0.214 at API prices")
        #expect(RunInfo(model: "claude-haiku-5-5", durationMs: 900).summary == "claude-haiku-5-5, 0.9 s")
    }

    @Test func readsClaudeAuthStatus() {
        #expect(ClaudeCLI.parseAuthStatus(stdout: Data(#"{"loggedIn": true, "authMethod": "claude.ai"}"#.utf8), status: 0) == .ready)
        #expect(ClaudeCLI.parseAuthStatus(stdout: Data(#"{"loggedIn": false}"#.utf8), status: 1) == .signedOut)
        #expect(ClaudeCLI.parseAuthStatus(stdout: Data("Not logged in".utf8), status: 1) == .signedOut)
    }
}

/// A real bridge server and a phone link over the network, found through Bonjour.
@Suite(.serialized) struct BridgeServerTests {
    @Test func aPairedPhoneFindsTheBridgeAndAsksDiv() async throws {
        let store = tempStore()
        let server = BridgeServer(
            store: store, bridgeName: "Test bridge \(UUID().uuidString.prefix(6))", status: { .ready },
            handle: { request in
                guard case .chat(let request) = request.job else { return .failed("no") }
                return .chat(ChatReply(reply: "You said: \(request.message)", model: "claude-test"))
            })
        let code = store.newCode(bridgeName: server.bridgeName, hosts: [], port: 0)
        server.start()
        defer { server.stop() }

        let link = BridgeLink(code: code, phoneName: "Test iPhone")
        let status = try await link.connect(searchFor: .seconds(10))
        #expect(status.claude == .ready)
        #expect(store.pairings.first?.phoneName == "Test iPhone")

        let outcome = try await link.ask(.chat(ChatRequest(message: "hi")))
        #expect(outcome == .chat(ChatReply(reply: "You said: hi", model: "claude-test")))
        link.close()
    }

    @Test func theAddressInTheCodeWorksWithoutBonjour() async throws {
        let store = tempStore()
        let server = BridgeServer(store: store, bridgeName: "Test bridge", status: { .signedOut }, handle: { _ in .failed("x") })
        var code = store.newCode(bridgeName: "Test bridge", hosts: [], port: 0)
        server.start()
        defer { server.stop() }
        var port: UInt16?
        for _ in 0..<50 where port == nil {
            port = server.snapshot.port
            try await Task.sleep(for: .milliseconds(100))
        }
        code.bridgeID = UUID()  // so Bonjour can't find it
        code.hosts = ["127.0.0.1"]
        code.port = try #require(port)
        let status = try await BridgeLink(code: code, phoneName: "iPhone").connect(searchFor: .milliseconds(200))
        #expect(status.claude == .signedOut)
    }

    @Test func aForgottenPhoneCantConnect() async throws {
        let store = tempStore()
        let server = BridgeServer(store: store, bridgeName: "Test bridge", status: { .ready }, handle: { _ in .failed("x") })
        var code = store.newCode(bridgeName: "Test bridge", hosts: [], port: 0)
        _ = store.newCode(bridgeName: "Test bridge", hosts: [], port: 0)  // replaces the unscanned first code
        server.start()
        defer { server.stop() }
        var port: UInt16?
        for _ in 0..<50 where port == nil {
            port = server.snapshot.port
            try await Task.sleep(for: .milliseconds(100))
        }
        code.hosts = ["127.0.0.1"]
        code.port = try #require(port)
        await #expect(throws: (any Error).self) {
            try await BridgeLink(code: code, phoneName: "iPhone").connect(searchFor: .milliseconds(200))
        }
    }
}

/// The phone's data reaches the bridge, Div answers from it, and its changes come back to the phone.
@Suite struct PhoneJobsTests {
    @Test func syncThenChatSavesDivsChangesAndTheyComeBack() async throws {
        let phone = try AZStore.inMemory()
        try phone.start(
            Profile(name: "Sam", sex: .male, birthYear: 1996, heightCm: 180, goal: .cut, trainingDays: 4), weightKg: 82,
            today: "2026-11-25")
        let person = try #require(try phone.profile()?.id)
        let answer = """
            {"reply":"Landmine press for two weeks.","changes":[{"type":"swap_exercise","from":"Seated dumbbell shoulder press",
             "to":"Landmine press","weeks":2,"reason":"Shoulder","evidence":[]}],"remember":["Left shoulder tight overhead"]}
            """
        let claude = FakeClaude(answer: answer)
        let people = PeopleStores(folder: FileManager.default.temporaryDirectory.appending(path: "azfit-people-\(UUID().uuidString)"))
        let jobs = PhoneJobs(
            div: { Div(files: divFiles, claude: claude, toolServer: ["/usr/local/bin/div", "tools"]) }, people: people,
            today: { "2026-11-25" })

        func sync() async throws {
            let push = SyncPush(
                batch: try phone.changes(after: try phone.acknowledgedSeq(by: "bridge")), since: try phone.receivedSeq(from: "bridge"))
            guard case .synced(let pull) = await jobs.handle(Request(job: .sync(push), person: person)) else { throw CancellationError() }
            try phone.apply(pull.batch, from: "bridge")
            try phone.setAcknowledged(pull.received, by: "bridge")
        }

        try await sync()
        let bridge = try people.store(for: person)
        #expect(try bridge.records() == phone.records())

        guard case .chat(let reply) = await jobs.handle(Request(job: .chat(ChatRequest(message: "Shoulder hurts")), person: person))
        else { throw CancellationError() }
        #expect(reply.changes.map(\.verdict) == [.propose])  // swaps ask first (D-012)
        let id = try #require(reply.saved.first ?? nil)
        let call = try #require(claude.lastCall)
        let data = try DivJSON.decode(DivData.self, from: try #require(call.files["data.json"]))
        #expect(data.profile.name == "Sam")  // Div read this person, not the sample

        try await sync()
        #expect(try phone.all(DivChange.self).map(\.id) == [id])
        #expect(try phone.all(Memory.self).map(\.text) == ["Left shoulder tight overhead"])

        // Approve on the phone changes the plan there, and the bridge catches up.
        try phone.approve(id, today: "2026-11-25")
        try await sync()
        #expect(try bridge.plan().flatMap(\.exercises).contains { $0.exerciseID == "landmine_press" })
        #expect(try bridge.all(DivChange.self).first?.status == .approved)
    }

    @Test func sessionReviewSavesTheNoteAndLoadsAndTheySyncBack() async throws {
        let phone = try AZStore.inMemory()
        try phone.start(
            Profile(name: "Sam", sex: .male, birthYear: 1996, heightCm: 180, goal: .cut, trainingDays: 4), weightKg: 82,
            today: "2026-11-23")
        let person = try #require(try phone.profile()?.id)
        let push = try #require(try phone.plan().first?.session)
        let workout = try phone.startWorkout(push, today: "2026-11-23")
        for i in 0..<3 {
            try phone.logSet(LoggedSet(workoutID: workout.id, exerciseID: "barbell_bench_press", position: i, loadKg: 80, reps: 8, rir: 2))
        }
        try phone.finishWorkout(workout.id)
        let answer = """
            {"note":"Every set at 8. Up next time.","next_time":[{"exercise":"Barbell bench press","call":"progress",
             "next_load_kg":82.5,"reason":"All sets at the top of the range."}]}
            """
        let people = PeopleStores(folder: FileManager.default.temporaryDirectory.appending(path: "azfit-people-\(UUID().uuidString)"))
        let jobs = PhoneJobs(
            div: { Div(files: divFiles, claude: FakeClaude(answer: answer)) }, people: people, today: { "2026-11-23" })

        func sync() async throws {
            let push = SyncPush(
                batch: try phone.changes(after: try phone.acknowledgedSeq(by: "bridge")), since: try phone.receivedSeq(from: "bridge"))
            guard case .synced(let pull) = await jobs.handle(Request(job: .sync(push), person: person)) else { throw CancellationError() }
            try phone.apply(pull.batch, from: "bridge")
            try phone.setAcknowledged(pull.received, by: "bridge")
        }

        try await sync()
        let outcome = await jobs.handle(Request(job: .sessionReview(SessionReviewRequest(workoutID: workout.id)), person: person))
        #expect(outcome == .sessionReviewed(SessionReviewReply(note: "Every set at 8. Up next time.", applied: 1, proposed: 0)))
        try await sync()
        #expect(try phone.all(Workout.self).first?.divNote == "Every set at 8. Up next time.")
        #expect(try phone.plan().first?.exercises.first?.loadKg == 82.5)
        #expect(try phone.all(DivChange.self).first?.job == "session_review")
    }

    @Test func syncNeedsAPerson() async {
        let jobs = PhoneJobs(div: { throw ClaudeError.notInstalled }, people: PeopleStores(folder: FileManager.default.temporaryDirectory))
        let push = SyncPush(batch: SyncBatch(rows: [], lastSeq: 0, more: false), since: 0)
        #expect(await jobs.handle(Request(job: .sync(push))) == .failed("Finish setting up AZfit first."))
    }
}
