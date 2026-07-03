import ComposableArchitecture
import OpenClawKit
import SwiftUI

@Reducer
struct SettingsGatewayConnectionFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var connectingGatewayID: String?
        var gatewayAgentCount = 0
        var gatewayDisplayStatusText = "Offline"
        var gatewayRemoteAddress: String?
        var gatewayServerName: String?
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

        var gatewayStatusColor: Color {
            if self.isAppleReviewDemoModeEnabled { return OpenClawBrand.accent }
            return self.gatewayConnected ? OpenClawBrand.ok : .secondary
        }

        var gatewayDiagnosticConnected: Bool {
            self.isAppleReviewDemoModeEnabled || self.gatewayConnected
        }

        var gatewaySummaryDetail: String {
            "\(self.gatewayStatusDetail) • \(Self.agentSummary(count: self.gatewayAgentCount))"
        }

        var gatewayAddress: String {
            self.gatewayRemoteAddress ?? "Waiting for gateway"
        }

        var gatewayServer: String {
            self.gatewayServerName ?? "OpenClaw Gateway"
        }

        static func agentSummary(count: Int) -> String {
            count == 1 ? "1 agent" : "\(count) agents"
        }

        static func discoveredGatewayDetailLines(
            lanHost: String?,
            tailnetDNS: String?,
            gatewayPort: Int?,
            canvasPort: Int?,
            debugID: String) -> [String]
        {
            var lines: [String] = []
            if let lanHost { lines.append("LAN: \(lanHost)") }
            if let tailnetDNS { lines.append("Tailnet: \(tailnetDNS)") }
            let gatewayPortText = gatewayPort.map(String.init)
            let canvasPortText = canvasPort.map(String.init)
            if gatewayPortText != nil || canvasPortText != nil {
                lines.append("Ports: gateway \(gatewayPortText ?? "-") / canvas \(canvasPortText ?? "-")")
            }
            return lines.isEmpty ? [debugID] : lines
        }
    }

    enum Action: Equatable, Sendable {
        case connectionFinished
        case connectionStarted(String)
        case gatewayStatusSynced(
            isAppleReviewDemoModeEnabled: Bool,
            gatewayStatusConnected: Bool,
            gatewayDisplayStatusText: String,
            gatewayAgentCount: Int,
            gatewayRemoteAddress: String?,
            gatewayServerName: String?)
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
                gatewayAgentCount,
                gatewayRemoteAddress,
                gatewayServerName):
                state.isAppleReviewDemoModeEnabled = isAppleReviewDemoModeEnabled
                state.gatewayStatusConnected = gatewayStatusConnected
                state.gatewayDisplayStatusText = gatewayDisplayStatusText
                state.gatewayAgentCount = gatewayAgentCount
                state.gatewayRemoteAddress = gatewayRemoteAddress
                state.gatewayServerName = gatewayServerName
                return .none
            }
        }
        .autoLogActions()
    }
}
