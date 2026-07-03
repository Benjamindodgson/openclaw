import ComposableArchitecture

@Reducer
struct SettingsGatewayConnectionFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var connectingGatewayID: String?
        var gatewayAgentCount = 0
        var gatewayDisplayStatusText = "Offline"
        var gatewayStatusConnected = false
        var isAppleReviewDemoModeEnabled = false

        var gatewayConnected: Bool {
            !self.isAppleReviewDemoModeEnabled && self.gatewayStatusConnected
        }

        var gatewayStatusDetail: String {
            if self.isAppleReviewDemoModeEnabled { return "Apple Review demo mode" }
            return self.gatewayConnected ? "Connected" : self.gatewayDisplayStatusText
        }

        var gatewayStatusValue: String {
            if self.isAppleReviewDemoModeEnabled { return "demo" }
            return self.gatewayConnected ? "online" : "offline"
        }

        var gatewayDiagnosticConnected: Bool {
            self.isAppleReviewDemoModeEnabled || self.gatewayConnected
        }

        var gatewaySummaryDetail: String {
            "\(self.gatewayStatusDetail) • \(Self.agentSummary(count: self.gatewayAgentCount))"
        }

        static func agentSummary(count: Int) -> String {
            count == 1 ? "1 agent" : "\(count) agents"
        }
    }

    enum Action: Equatable, Sendable {
        case connectionFinished
        case connectionStarted(String)
        case gatewayStatusSynced(
            isAppleReviewDemoModeEnabled: Bool,
            gatewayStatusConnected: Bool,
            gatewayDisplayStatusText: String,
            gatewayAgentCount: Int)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .connectionFinished:
                state.connectingGatewayID = nil
                return .none

            case let .connectionStarted(gatewayID):
                state.connectingGatewayID = gatewayID
                return .none

            case let .gatewayStatusSynced(
                isAppleReviewDemoModeEnabled,
                gatewayStatusConnected,
                gatewayDisplayStatusText,
                gatewayAgentCount):
                state.isAppleReviewDemoModeEnabled = isAppleReviewDemoModeEnabled
                state.gatewayStatusConnected = gatewayStatusConnected
                state.gatewayDisplayStatusText = gatewayDisplayStatusText
                state.gatewayAgentCount = gatewayAgentCount
                return .none
            }
        }
        .autoLogActions()
    }
}
