import AZModel
import AZStore
import Foundation

/// Screen helpers: today's date and the person's units, read so views refresh when the store changes.
extension AppEnvironment {
    var today: String {
        _ = revision
        return Day.string(.now)
    }

    var units: UnitSystem { profile?.units ?? .canadian }

    /// "Wednesday, Nov 25"
    static func caption(_ day: String) -> String {
        Day.date(day)?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? day
    }

    /// "Morning, Sam", or just "Morning".
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Morning" : hour < 18 ? "Afternoon" : "Evening"
        return profile?.name.flatMap { $0.isEmpty ? nil : "\(part), \($0)" } ?? part
    }
}

extension WeekStrip {
    init(_ week: [WeekDay]) {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        self.init(
            days: week.enumerated().map { index, day in
                let state: Day =
                    switch day.state {
                    case .done: .done
                    case .open: .open
                    case .missed: .missed
                    case .today: .today
                    case .movedByDiv: .movedByDiv
                    }
                return (letters[index % 7], day.date, state)
            })
    }
}

extension Int {
    /// "1,110"
    var grouped: String { formatted(.number.grouping(.automatic)) }
}
