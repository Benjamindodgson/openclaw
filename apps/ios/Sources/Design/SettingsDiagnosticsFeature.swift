import ComposableArchitecture

@Reducer
struct SettingsDiagnosticsFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var issueCount: Int?
        var lastRunText = "Not run"

        var detailText: String {
            "System checks"
        }

        var runValue: String {
            guard let issueCount else { return "pending" }
            return issueCount == 0 ? "pass" : "\(issueCount)"
        }
    }

    enum Action: Equatable, Sendable {
        case diagnosticsCompleted(issueCount: Int, lastRunText: String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .diagnosticsCompleted(issueCount, lastRunText):
                state.issueCount = issueCount
                state.lastRunText = lastRunText
                return .none
            }
        }
        .autoLogActions()
    }
}
