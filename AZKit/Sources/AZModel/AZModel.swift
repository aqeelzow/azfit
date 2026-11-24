import Foundation

// AZModel: the app's data types. Plain structs and enums, no I/O, no dependencies.
//
// Div/ holds the types Div's jobs read and return (see Div/README.md). Their JSON is snake_case: always
// encode and decode them with `DivJSON` so `trendKgNow` reads and writes `trend_kg_now`.
//
// TODO: model what the app records. The brief (docs/product-brief.html) describes each one:
// - Training (Pillar 1): exercises tagged with muscles and fatigue cost, workout sessions, sets with weight, reps and RIR.
// - Food (Pillar 2): meals with a calorie estimate and its range, and whether each day was logged completely.
// - Body (Pillar 3): weigh-ins, tape measurements, scans.
