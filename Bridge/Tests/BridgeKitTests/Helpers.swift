import AZModel
import Foundation
import Synchronization

@testable import BridgeKit

let repo = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
let divFiles = try! DivFiles(root: repo.appending(path: "Div"))

func fixture<T: Decodable>(_ job: String, _ name: String, key: String, as type: T.Type = T.self) throws -> T {
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: divFiles.evalsURL.appending(path: "\(job)/\(name).json")))
    let inner = (object as! [String: Any])[key]!
    return try DivJSON.decode(T.self, from: JSONSerialization.data(withJSONObject: inner))
}

func snapshot(_ name: String) throws -> WeeklySnapshot { try fixture("weekly-review", name, key: "snapshot") }
func session(_ name: String) throws -> SessionReport { try fixture("session-review", name, key: "session") }
func chatData() throws -> DivData {
    try DivJSON.decode(DivData.self, from: Data(contentsOf: divFiles.evalsURL.appending(path: "chat/data.json")))
}

/// A stand-in for `claude -p`: records each call and answers with fixed JSON.
final class FakeClaude: ClaudeRunning {
    let answer: String
    let collected: [String: Data]
    private let calls = Mutex<[ClaudeCall]>([])

    init(answer: String, collected: [String: Data] = [:]) {
        self.answer = answer
        self.collected = collected
    }

    var lastCall: ClaudeCall? { calls.withLock { $0.last } }

    func run(_ call: ClaudeCall) async throws -> ClaudeReply {
        calls.withLock { $0.append(call) }
        return ClaudeReply(output: Data(answer.utf8), run: RunInfo(model: "claude-test", durationMs: 1), collected: collected)
    }
}
