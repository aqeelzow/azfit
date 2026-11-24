import AZModel
import Foundation
import Testing

@testable import BridgeKit

@Suite struct DivJobTests {
    @Test func weeklyReviewSendsSnapshotAndDerivedAndChecksTheAnswer() async throws {
        let answer = """
            {"summary":"s","calorie_reading":"surplus_too_big","calorie_action":"decrease","calorie_reasoning":"r",
             "changes":[{"type":"set_calorie_target","new_kcal":2700,"reason":"r","evidence":[]},
                        {"type":"set_calorie_target","new_kcal":2750,"reason":"r","evidence":[]}],"questions":[]}
            """
        let claude = FakeClaude(answer: answer)
        let r = try await Div(files: divFiles, claude: claude).weeklyReview(try snapshot("surplus-too-big"))
        let call = try #require(claude.lastCall)
        #expect(call.model == "opus")
        #expect(call.systemPrompt.hasPrefix("# You are Div"))
        #expect(call.systemPrompt.contains("# Job: weekly review"))
        #expect(call.userPrompt.contains("\"implied_maintenance_kcal\" : 2390"))
        #expect(call.builtInTools.isEmpty && call.mcpConfig == nil)
        #expect(r.checked.map(\.verdict) == [.apply, .refuse])
    }

    @Test func mealPutsThePhotoInTheFolderAndKeepsItOutOfThePrompt() async throws {
        let answer = """
            {"meal_name":"Rice","items":[{"name":"Rice","portion":"1 cup","grams":200,"kcal":260,"protein_g":5,"carbs_g":57,"fat_g":0.6}],
             "kcal_low":230,"kcal_high":300,"confidence":"medium","matched_similar_meal":"","assumptions":[],"follow_up_question":""}
            """
        let claude = FakeClaude(answer: answer)
        let photo = Data(repeating: 7, count: 500)
        let r = try await Div(files: divFiles, claude: claude).estimateMeal(MealPhotoRequest(photo: photo, mediaType: .png, note: "half"))
        let call = try #require(claude.lastCall)
        #expect(call.model == "haiku")
        #expect(call.builtInTools == ["Read"])
        #expect(call.files["photo.png"] == photo)
        #expect(call.userPrompt.contains("./photo.png") && call.userPrompt.contains("\"note\" : \"half\""))
        #expect(!call.userPrompt.contains("\"photo\""))
        #expect(r.totals.kcal == 260 && r.warnings.isEmpty)
    }

    @Test func chatWiresTheToolServerAndReportsWhatItLookedUp() async throws {
        let answer = """
            {"reply":"Swapped.","changes":[{"type":"swap_exercise","from":"Overhead press","to":"Landmine press","reason":"r","evidence":[]}],
             "remember":["Left shoulder tight overhead"]}
            """
        let claude = FakeClaude(answer: answer, collected: ["tool-calls.log": Data("get_plan\nget_profile\n".utf8)])
        let div = Div(files: divFiles, claude: claude, toolServer: ["/usr/local/bin/div", "tools"])
        let r = try await div.chat(ChatRequest(message: "Shoulder felt tight"), data: try chatData())
        let call = try #require(claude.lastCall)
        let config = try JSONSerialization.jsonObject(with: Data(try #require(call.mcpConfig).utf8)) as! [String: Any]
        let server = (config["mcpServers"] as! [String: Any])["div"] as! [String: Any]
        #expect(server["command"] as? String == "/usr/local/bin/div")
        #expect((server["args"] as! [String]).starts(with: ["tools", "--data", "{workdir}/data.json"]))
        #expect(call.allowedTools == ["mcp__div"] && call.builtInTools.isEmpty)
        #expect(call.files["data.json"] != nil)
        #expect(call.userPrompt.contains("Today is 2026-11-23"))
        #expect(r.toolCalls == ["get_plan", "get_profile"])
        #expect(r.checked.map(\.verdict) == [.apply])
    }

    @Test func anAnswerThatBreaksTheSchemaIsAnError() async throws {
        let claude = FakeClaude(answer: #"{"note":"hi"}"#)
        await #expect(throws: ClaudeError.self) { try await Div(files: divFiles, claude: claude).sessionReview(try session("push-day")) }
    }
}

@Suite struct ClaudeCLITests {
    @Test func argumentsSwitchOffEverythingThatIsntDivs() {
        var call = ClaudeCall(model: "opus", systemPrompt: "sys", userPrompt: "hi", schema: "{}")
        call.mcpConfig = #"{"x":"{workdir}/data.json"}"#
        let args = ClaudeCLI.arguments(for: call, workDir: URL(filePath: "/tmp/job"))
        for flag in ["--strict-mcp-config", "--no-session-persistence", "--disable-slash-commands"] { #expect(args.contains(flag)) }
        #expect(args[args.firstIndex(of: "--tools")! + 1] == "")
        #expect(args[args.firstIndex(of: "--setting-sources")! + 1] == "")
        #expect(args[args.firstIndex(of: "--mcp-config")! + 1] == #"{"x":"/tmp/job/data.json"}"#)
        #expect(!args.contains("--bare"))  // --bare ignores the Claude login and needs an API key.
    }

    @Test func parsesTheEnvelope() throws {
        let envelope = """
            {"type":"result","subtype":"success","is_error":false,"duration_ms":4200,"num_turns":3,"total_cost_usd":0.05,
             "structured_output":{"note":"ok","next_time":[]},
             "modelUsage":{"claude-haiku-5-5":{},"claude-opus-5-5":{}}}
            """
        let reply = try ClaudeCLI.parse(stdout: Data(envelope.utf8), stderr: Data(), status: 0, model: "opus")
        #expect(reply.run.model == "claude-opus-5-5")
        #expect(reply.run.turns == 3)
        #expect(try JSONSerialization.jsonObject(with: reply.output) as? [String: Any] != nil)
    }

    @Test func errorsAreReported() {
        let error = #"{"type":"result","subtype":"error_max_turns","is_error":true}"#
        #expect(throws: ClaudeError.self) { try ClaudeCLI.parse(stdout: Data(error.utf8), stderr: Data(), status: 1, model: "opus") }
        #expect(throws: ClaudeError.self) {
            try ClaudeCLI.parse(stdout: Data(), stderr: Data("not logged in".utf8), status: 1, model: "opus")
        }
    }
}
