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
        // Plain value types. No dependencies, no I/O.
        .target(name: "AZModel"),
        // Pure functions: e1RM, trend weight, fatigue, maintenance, calorie review rules.
        .target(name: "AZMath", dependencies: ["AZModel"]),
        // SQLite schema, migrations, records and the sync log.
        .target(name: "AZStore", dependencies: ["AZModel", .product(name: "GRDB", package: "GRDB.swift")]),
        // Wire format between the phone and the bridge.
        .target(name: "AZSync", dependencies: ["AZModel"]),

        .testTarget(name: "AZModelTests", dependencies: ["AZModel"]),
        .testTarget(name: "AZMathTests", dependencies: ["AZMath"]),
        .testTarget(name: "AZStoreTests", dependencies: ["AZStore"]),
    ]
)
