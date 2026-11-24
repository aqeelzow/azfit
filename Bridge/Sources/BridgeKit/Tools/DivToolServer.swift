import AZModel
import Foundation

/// Serves Div's read tools to Claude over MCP on stdin and stdout (JSON-RPC 2.0, one message per line).
/// Claude Code starts it for each chat run (`div tools --data ... --tools ... --log ...`), as set in `Div.chat`.
public struct DivToolServer: Sendable {
    public let tools: DivTools
    /// The tool list from Div/tools/tools.json, sent as is for `tools/list`.
    public let definitions: Data
    /// If set, each tool call is appended here as one line, so the bridge and evals can see what Div looked up.
    public let log: URL?

    public init(data: DivData, definitions: Data, log: URL? = nil) {
        tools = DivTools(data: data)
        self.definitions = definitions
        self.log = log
    }

    /// Reads requests from stdin until it closes, answering each on stdout.
    public func serve() async throws {
        for try await line in FileHandle.standardInput.bytes.lines {
            if let response = respond(to: line) {
                FileHandle.standardOutput.write(Data((response + "\n").utf8))
            }
        }
    }

    /// The response to one JSON-RPC message, or nil for a notification.
    public func respond(to line: String) -> String? {
        guard let message = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
            return encode(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "parse error"]])
        }
        guard let id = message["id"] else { return nil }
        let method = message["method"] as? String ?? ""
        let params = message["params"] as? [String: Any] ?? [:]

        func result(_ value: Any) -> String? { encode(["jsonrpc": "2.0", "id": id, "result": value]) }
        func error(_ code: Int, _ text: String) -> String? {
            encode(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": text]])
        }

        switch method {
        case "initialize":
            return result([
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [:] as [String: Any]],
                "serverInfo": ["name": "azfit-div", "version": "1"],
                "instructions": "Read-only access to this person's AZfit data. Nothing here changes anything.",
            ])
        case "ping":
            return result([:] as [String: Any])
        case "tools/list":
            let list = (try? JSONSerialization.jsonObject(with: definitions)) ?? []
            return result(["tools": list])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            record(name, arguments)
            do {
                return result(["content": [["type": "text", "text": try tools.call(name, arguments: arguments)]]])
            } catch {
                return result(["content": [["type": "text", "text": "\(error)"]], "isError": true])
            }
        default:
            return error(-32601, "method not found: \(method)")
        }
    }

    private func record(_ name: String, _ arguments: [String: Any]) {
        guard let log else { return }
        let args = (try? JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys])).map {
            String(decoding: $0, as: UTF8.self)
        }
        let line = Data((name + (args == nil || args == "{}" ? "" : " " + args!) + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: log)
        }
    }

    private func encode(_ object: [String: Any]) -> String? {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) }
    }
}
