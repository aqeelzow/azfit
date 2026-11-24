// swift-tools-version: 6.2
import PackageDescription

// BridgeKit: everything the Mac menu bar app does, as a testable library.
// The app target in project.yml (Bridge/App) is a thin SwiftUI shell over this.
// `div` is a command line for running Div's jobs and evals by hand, and serves chat's read tools to Claude.
let package = Package(
    name: "Bridge",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "BridgeKit", targets: ["BridgeKit"]),
        .executable(name: "div", targets: ["DivCLI"]),
    ],
    dependencies: [
        .package(path: "../AZKit")
    ],
    targets: [
        .target(
            name: "BridgeKit",
            dependencies: [
                .product(name: "AZModel", package: "AZKit"),
                .product(name: "AZMath", package: "AZKit"),
                .product(name: "AZStore", package: "AZKit"),
                .product(name: "AZSync", package: "AZKit"),
            ]
        ),
        .executableTarget(
            name: "DivCLI",
            dependencies: ["BridgeKit", .product(name: "AZModel", package: "AZKit")]
        ),
        .testTarget(
            name: "BridgeKitTests",
            dependencies: ["BridgeKit", .product(name: "AZModel", package: "AZKit"), .product(name: "AZMath", package: "AZKit")]
        ),
    ]
)
