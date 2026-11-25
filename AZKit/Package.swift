// swift-tools-version: 6.2
import PackageDescription

// AZKit: the shared core used by the iPhone app and the Mac bridge.
// Nothing in here may import UIKit, AppKit or SwiftUI.
let package = Package(
    name: "AZKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AZModel", targets: ["AZModel"]),
        .library(name: "AZMath", targets: ["AZMath"]),
        .library(name: "AZStore", targets: ["AZStore"]),
        .library(name: "AZSync", targets: ["AZSync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0")
    ],
    targets: [
        // Plain value types and the bundled exercise library. No dependencies.
        .target(name: "AZModel", resources: [.copy("Resources/exercises.json")]),
        // Pure functions: e1RM, trend weight, fatigue, maintenance, calorie review rules.
        .target(name: "AZMath", dependencies: ["AZModel"]),
        // SQLite schema, migrations, records and the sync log.
        .target(name: "AZStore", dependencies: ["AZModel", "AZMath", .product(name: "GRDB", package: "GRDB.swift")]),
        // The connection between the phone and the bridge: pairing, TLS channel, messages, sync.
        .target(name: "AZSync", dependencies: ["AZModel", "AZStore"]),

        .testTarget(name: "AZModelTests", dependencies: ["AZModel"]),
        .testTarget(name: "AZMathTests", dependencies: ["AZMath"]),
        .testTarget(name: "AZStoreTests", dependencies: ["AZStore", "AZModel"]),
        .testTarget(name: "AZSyncTests", dependencies: ["AZSync", "AZModel"]),
    ]
)
