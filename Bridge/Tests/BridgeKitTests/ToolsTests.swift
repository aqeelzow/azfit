import AZModel
import Foundation
import Testing

@testable import BridgeKit

@Suite struct DivToolsTests {
    func call(_ name: String, _ arguments: [String: Any] = [:]) throws -> [String: Any] {
        let text = try DivTools(data: try chatData()).call(name, arguments: arguments)
        return try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
    }

    @Test func everyToolInToolsJSONIsImplemented() throws {
        let definitions = try JSONSerialization.jsonObject(with: Data(contentsOf: divFiles.toolsURL)) as! [[String: Any]]
        for name in definitions.compactMap({ $0["name"] as? String }) {
            #expect(throws: Never.self) { try call(name) }
        }
    }

    @Test func trainingLogFiltersByExerciseAndAddsE1RM() throws {
        let log = try call("get_training_log", ["exercise": "bench press", "days": 7])
        let sessions = log["sessions"] as! [[String: Any]]
        #expect(sessions.count == 1)
        let exercise = (sessions[0]["exercises"] as! [[String: Any]])[0]
        #expect(exercise["exercise"] as? String == "Bench press")
        #expect(exercise["best_e1rm"] as? Double == 112)  // 80 kg x 10 at RIR 2: 80 x (1 + 12 / 30)
    }

    @Test func foodLogTotalsEachDayAndAveragesCompleteDaysOnly() throws {
        let log = try call("get_food_log", ["from": "2026-11-10", "to": "2026-11-22"])
        let days = log["days"] as! [[String: Any]]
        #expect(days.count == 13)
        #expect(log["complete_days"] as? Int == 12)
        #expect(log["avg_kcal_complete_days"] as? Int == 2200)
    }

    @Test func weightTrendIsSmoothed() throws {
        let answer = try call("get_weight_trend", ["days": 21])
        #expect((answer["weekly_rate_kg"] as? Double ?? 0) < 0)
        #expect((answer["weigh_ins"] as! [[String: Any]]).allSatisfy { $0["trend_kg"] != nil })
    }

    @Test func badArgumentsAndUnknownToolsAreErrors() throws {
        #expect(throws: DivTools.Failure.self) { try call("get_food_log", ["from": "last week"]) }
        #expect(throws: DivTools.Failure.self) { try call("get_training_log", ["days": 9999]) }
        #expect(throws: DivTools.Failure.self) { try call("log_food") }
    }
}

@Suite struct DivToolServerTests {
    func server(log: URL? = nil) throws -> DivToolServer {
        DivToolServer(data: try chatData(), definitions: try Data(contentsOf: divFiles.toolsURL), log: log)
    }

    func answer(_ s: DivToolServer, _ line: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(try #require(s.respond(to: line)).utf8)) as! [String: Any]
    }

    @Test func handshakeAndToolList() throws {
        let s = try server()
        let initialized = try answer(s, #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#)
        #expect((initialized["result"] as! [String: Any])["protocolVersion"] as? String == "2025-06-18")
        #expect(s.respond(to: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
        let list = try answer(s, #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        #expect(((list["result"] as! [String: Any])["tools"] as! [Any]).count == 6)
    }

    @Test func toolCallsAnswerAndAreLogged() throws {
        let log = FileManager.default.temporaryDirectory.appending(path: "div-tools-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: log) }
        let s = try server(log: log)
        let ok = try answer(s, #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_div_log","arguments":{"days":10}}}"#)
        #expect((ok["result"] as! [String: Any])["isError"] == nil)
        let bad = try answer(s, #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"log_food","arguments":{}}}"#)
        #expect((bad["result"] as! [String: Any])["isError"] as? Bool == true)
        #expect(try String(contentsOf: log, encoding: .utf8) == "get_div_log {\"days\":10}\nlog_food\n")
    }

    @Test func unknownMethodsAndGarbageGetErrors() throws {
        let s = try server()
        #expect(try answer(s, #"{"jsonrpc":"2.0","id":5,"method":"resources/list"}"#)["error"] != nil)
        #expect(try answer(s, "not json")["error"] != nil)
    }
}
