import ComposableArchitecture
import Foundation
import OpenClawKit
import SwiftUI

@Reducer
struct SettingsGatewayConnectionFeature {
    private let persistenceClientOverride: SettingsDiscoveredGatewayPersistenceClient?
    private let disconnectClientOverride: SettingsGatewayDisconnectClient?

    init(
        persistenceClient: SettingsDiscoveredGatewayPersistenceClient? = nil,
        disconnectClient: SettingsGatewayDisconnectClient? = nil)
    {
        self.persistenceClientOverride = persistenceClient
        self.disconnectClientOverride = disconnectClient
    }

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
        struct ConnectionStart: Equatable, Sendable {
            var gatewayID: String
        }

        struct DiscoveredGatewayPersistenceRequest: Equatable, Sendable {
            var stableID: SettingsGatewayStableID
        }

        struct GatewayAppleReviewDemoModeEnabled: Equatable, Sendable { var value: Bool }
        struct GatewayConnectionStatusConnected: Equatable, Sendable { var value: Bool }

        struct GatewayStatusSync: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: GatewayAppleReviewDemoModeEnabled
            var gatewayStatusConnected: GatewayConnectionStatusConnected
            var gatewayDisplayStatusText: String
            var gatewayAgentCount: Int
            var gatewayRemoteAddress: String?
            var gatewayServerName: String?
        }

        case connectionFinished
        case connectionStarted(ConnectionStart)
        case disconnectRequested
        case discoveredGatewayPersistenceRequested(DiscoveredGatewayPersistenceRequest)
        case gatewayStatusSynced(GatewayStatusSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsDiscoveredGatewayPersistence) var dependencyPersistenceClient
            @Dependency(\.settingsGatewayDisconnect) var dependencyDisconnectClient
            let persistenceClient = self.persistenceClientOverride ?? dependencyPersistenceClient
            let disconnectClient = self.disconnectClientOverride ?? dependencyDisconnectClient

            switch action {
            case .connectionFinished:
                state.connectingGatewayID = nil
                return .none

            case let .connectionStarted(start):
                state.connectingGatewayID = start.gatewayID
                return .none

            case .disconnectRequested:
                state.connectingGatewayID = nil
                return .run { _ in
                    await disconnectClient.disconnect()
                }

            case let .discoveredGatewayPersistenceRequested(request):
                guard request.stableID.trimmedValue != nil else { return .none }
                return .run { _ in
                    await persistenceClient.saveSelectedGatewayStableID(request.stableID)
                }

            case let .gatewayStatusSynced(sync):
                state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled.value
                state.gatewayStatusConnected = sync.gatewayStatusConnected.value
                state.gatewayDisplayStatusText = sync.gatewayDisplayStatusText
                state.gatewayAgentCount = sync.gatewayAgentCount
                state.gatewayRemoteAddress = sync.gatewayRemoteAddress
                state.gatewayServerName = sync.gatewayServerName
                return .none
            }
        }
        .autoLogActions()
    }
}
