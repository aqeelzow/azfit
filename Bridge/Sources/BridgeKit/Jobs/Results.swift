import AZModel

/// A weekly review: the numbers code computed, what Div said, and the verdict on each change.
public struct WeeklyReviewResult: Codable, Sendable {
    public var derived: WeeklyDerived
    public var output: WeeklyReviewOutput
    public var checked: [Checked<Proposal>]
    public var run: RunInfo
}

public struct SessionReviewResult: Codable, Sendable {
    public var derived: SessionDerived
    public var output: SessionReviewOutput
    public var checked: [Checked<NextTime>]
    public var run: RunInfo
}

public struct MealEstimateResult: Codable, Sendable {
    public var estimate: MealEstimate
    /// Added up in code from the items. Use these, not the model's numbers.
    public var totals: MealTotals
    public var warnings: [String]
    public var run: RunInfo
}

public struct ChatResult: Codable, Sendable {
    public var output: ChatOutput
    public var checked: [Checked<Proposal>]
    /// The read tools Div called, in order, with their arguments.
    public var toolCalls: [String]
    public var run: RunInfo
}
