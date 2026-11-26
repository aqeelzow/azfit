import AZSync
import AppKit
import BridgeKit
import Foundation
import Observation
import os

/// Console.app, subsystem com.azfit.bridge: one line per Div job with its time and API-equivalent price.
nonisolated private let log = Logger(subsystem: "com.azfit.bridge", category: "jobs")

/// What the menu shows, and the server that phones connect to.
@MainActor
@Observable
final class BridgeModel {
    private(set) var claude: ClaudeStatus = .unknown
    private(set) var server = BridgeServer.Snapshot()
    private(set) var pairings: [PairingStore.Pairing] = []
    /// The code on screen in "Pair a phone", until a phone uses it or the window closes.
    private(set) var code: PairingCode?

    let store = PairingStore.standard()
    let bridgeName = Host.current().localizedName ?? "Mac"
    @ObservationIgnored private var listener: BridgeServer?

    init() {
        let jobs = Self.makeJobs()
        let listener = BridgeServer(
            store: store, bridgeName: bridgeName,
            status: { await Self.checkClaude() },
            handle: { request in await jobs.handle(request) },
            onChange: { [weak self] snapshot in
                Task { @MainActor in self?.serverChanged(snapshot) }
            })
        self.listener = listener
        pairings = store.pairings
        listener.start()
        Task { await refreshClaude() }
        Task { await watchClaude() }
        Task { await runWeeklyReviews() }
    }

    var phoneSummary: String {
        if let phone = server.phones.last { return "\(phone.name), connected" }
        let paired = pairings.filter { $0.phoneName != nil }
        if paired.isEmpty { return "Not paired" }
        return paired.count == 1 ? "\(paired[0].phoneName ?? "Phone"), not connected" : "\(paired.count) paired, not connected"
    }

    func refreshClaude() async {
        let status = await Self.checkClaude()
        if status != claude {
            claude = status
            listener?.broadcast(status)
        }
    }

    func showNewCode() {
        let host = ProcessInfo.processInfo.hostName
        code = store.newCode(bridgeName: bridgeName, hosts: host.isEmpty ? [] : [host], port: server.port ?? BridgeService.preferredPort)
        pairings = store.pairings
        listener?.start()
    }

    func closeCode() {
        code = nil
    }

    func forget(_ pairing: PairingStore.Pairing) {
        store.forget(pairing.id)
        pairings = store.pairings
        listener?.start()
    }

    /// Opens Terminal on `claude auth login`, which signs in through the browser.
    func signIn() {
        let script = FileManager.default.temporaryDirectory.appending(path: "azfit-claude-login.command")
        let claude = (try? ClaudeCLI.locate().executable.path) ?? "claude"
        let text = "#!/bin/zsh\n'\(claude)' auth login\necho\necho 'You can close this window.'\n"
        try? Data(text.utf8).write(to: script)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        NSWorkspace.shared.open(script)
    }

    func openInstallPage() {
        NSWorkspace.shared.open(URL(string: "https://claude.com/claude-code")!)
    }

    private func serverChanged(_ snapshot: BridgeServer.Snapshot) {
        let phoneArrived = snapshot.phones.count > server.phones.count
        server = snapshot
        pairings = store.pairings
        // The code worked: the pairing now has a phone. Close the code so it can't be shown to anyone else.
        if phoneArrived, let code, pairings.contains(where: { $0.id == code.pairingID && $0.phoneName != nil }) { self.code = nil }
    }

    /// The Sunday review: checked at launch and every hour after, so a Mac asleep on Sunday catches up (WeeklyReviews).
    private func runWeeklyReviews() async {
        let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let reviews = WeeklyReviews(
            div: { Div(files: try DivFiles.locate(), claude: try ClaudeCLI.locate(), toolServer: [executable, "tools"]) },
            people: .standard(),
            onRun: { name, run in log.info("ran \(name, privacy: .public): \(run.summary, privacy: .public)") })
        while !Task.isCancelled {
            for line in await reviews.runDue() { log.info("weekly review \(line, privacy: .public)") }
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    /// Checks Claude every minute, so a sign-out shows up on the phone without anyone opening the menu.
    private func watchClaude() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await refreshClaude()
        }
    }

    nonisolated private static func checkClaude() async -> ClaudeStatus {
        guard let cli = try? ClaudeCLI.locate() else { return .notInstalled }
        return await cli.authStatus()
    }

    /// Div for phone jobs, built per job so installing Claude Code while the bridge runs just works.
    nonisolated private static func makeJobs() -> PhoneJobs {
        let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
        return PhoneJobs(
            div: { Div(files: try DivFiles.locate(), claude: try ClaudeCLI.locate(), toolServer: [executable, "tools"]) },
            people: .standard(),
            onRun: { name, run in log.info("ran \(name, privacy: .public): \(run.summary, privacy: .public)") })
    }
}
