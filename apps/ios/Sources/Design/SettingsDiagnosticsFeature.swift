import ComposableArchitecture

@Reducer
struct SettingsDiagnosticsFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var discoveredGatewayCount = 0
        var discoveryStatusText = "Discovery idle"
        var gatewayConnected = false
        var issueCount: Int?
        var isAppleReviewDemoModeEnabled = false
        var lastRunText = "Not run"

        var detailText: String {
            "System checks"
        }

        var healthValue: String {
            if self.isAppleReviewDemoModeEnabled { return "demo" }
            if self.gatewayConnected { return "ready" }
            if self.discoveredGatewayCount == 0 { return "check" }
            return "partial"
        }

        var discoveryValue: String {
            "\(self.discoveredGatewayCount)"
        }

        var hasDiscoveredGateway: Bool {
            self.discoveredGatewayCount > 0
        }

        var runValue: String {
            guard let issueCount else { return "pending" }
            return issueCount == 0 ? "pass" : "\(issueCount)"
        }
    }

    enum Action: Equatable, Sendable {
        case diagnosticsContextSynced(
            isAppleReviewDemoModeEnabled: Bool,
            gatewayConnected: Bool,
            discoveredGatewayCount: Int,
            discoveryStatusText: String)
        case diagnosticsCompleted(issueCount: Int, lastRunText: String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .diagnosticsContextSynced(
                isAppleReviewDemoModeEnabled,
                gatewayConnected,
                discoveredGatewayCount,
                discoveryStatusText):
                state.isAppleReviewDemoModeEnabled = isAppleReviewDemoModeEnabled
                state.gatewayConnected = gatewayConnected
                state.discoveredGatewayCount = discoveredGatewayCount
                state.discoveryStatusText = discoveryStatusText
                return .none

            case let .diagnosticsCompleted(issueCount, lastRunText):
                state.issueCount = issueCount
                state.lastRunText = lastRunText
                return .none
            }
        }
        .autoLogActions()
    }
}
