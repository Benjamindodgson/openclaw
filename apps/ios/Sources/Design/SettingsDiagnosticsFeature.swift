import ComposableArchitecture
import OpenClawKit
import SwiftUI

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
        var screenRecordActive = false

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

        var discoveryColor: Color {
            self.hasDiscoveredGateway ? OpenClawBrand.accent : .secondary
        }

        var hasDiscoveredGateway: Bool {
            self.discoveredGatewayCount > 0
        }

        var screenCaptureValue: String {
            self.screenRecordActive ? "live" : "idle"
        }

        var screenCaptureColor: Color {
            self.screenRecordActive ? OpenClawBrand.ok : .secondary
        }

        var runValue: String {
            guard let issueCount else { return "pending" }
            return issueCount == 0 ? "pass" : "\(issueCount)"
        }

        var runColor: Color {
            guard let issueCount else { return .secondary }
            return issueCount == 0 ? OpenClawBrand.ok : OpenClawBrand.warn
        }
    }

    enum Action: Equatable, Sendable {
        case diagnosticsContextSynced(
            isAppleReviewDemoModeEnabled: Bool,
            gatewayConnected: Bool,
            discoveredGatewayCount: Int,
            discoveryStatusText: String,
            screenRecordActive: Bool)
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
                discoveryStatusText,
                screenRecordActive):
                state.isAppleReviewDemoModeEnabled = isAppleReviewDemoModeEnabled
                state.gatewayConnected = gatewayConnected
                state.discoveredGatewayCount = discoveredGatewayCount
                state.discoveryStatusText = discoveryStatusText
                state.screenRecordActive = screenRecordActive
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
