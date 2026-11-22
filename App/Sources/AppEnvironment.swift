import Foundation
import Observation

/// App-wide dependencies, injected through the SwiftUI environment with `.environment(_:)`.
/// Views read it with `@Environment(AppEnvironment.self)` instead of creating things themselves.
///
/// TODO: hold the database (AZStore) here once it exists, with a `live()` version on disk and a
/// `preview()` version in memory for previews and tests.
@MainActor
@Observable
final class AppEnvironment {
    static func live() -> AppEnvironment { AppEnvironment() }
    static func preview() -> AppEnvironment { AppEnvironment() }
}
