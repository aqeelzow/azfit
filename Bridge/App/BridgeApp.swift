import AZModel
import BridgeKit
import Foundation
import SwiftUI

/// AZfit Bridge: a menu bar app. Pairs with the phone, and runs Div jobs through `claude -p`.
/// Keep these files thin. Logic belongs in BridgeKit where it is tested.
///
/// The same executable also serves Div's read tools to Claude during chat: Claude starts it again as
/// `AZfit Bridge tools --data ... --tools ...` (see `Div.chat`), and then it runs no UI.
@main
enum Entry {
    static func main() {
        if CommandLine.arguments.dropFirst().first == "tools" {
            ToolServerMode.run(Array(CommandLine.arguments.dropFirst(2)))
        } else {
            BridgeApp.main()
        }
    }
}

struct BridgeApp: App {
    @State private var model = BridgeModel()

    var body: some Scene {
        MenuBarExtra("AZfit Bridge", systemImage: "figure.strengthtraining.traditional") {
            BridgeMenu().environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("Pair a phone", id: PairView.windowID) {
            PairView().environment(model)
        }
        .windowResizability(.contentSize)
    }
}

/// `tools --data <file> --tools <file> [--log <file>]`: the MCP server for chat's read tools, on stdin/stdout.
enum ToolServerMode {
    static func run(_ arguments: [String]) -> Never {
        func option(_ name: String) -> String? {
            arguments.firstIndex(of: name).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        }
        guard let dataPath = option("--data"), let toolsPath = option("--tools"),
            let data = try? DivJSON.decode(DivData.self, from: Data(contentsOf: URL(filePath: dataPath))),
            let definitions = try? Data(contentsOf: URL(filePath: toolsPath))
        else {
            FileHandle.standardError.write(Data("tools needs --data and --tools\n".utf8))
            exit(2)
        }
        let server = DivToolServer(data: data, definitions: definitions, log: option("--log").map { URL(filePath: $0) })
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            try? await server.serve()
            done.signal()
        }
        done.wait()
        exit(0)
    }
}
