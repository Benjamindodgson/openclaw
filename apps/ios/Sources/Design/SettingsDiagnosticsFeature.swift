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

        var healthColor: Color {
            self.isAppleReviewDemoModeEnabled || self.gatewayConnected ? OpenClawBrand.ok : OpenClawBrand.warn
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
        struct DiagnosticsContextSync: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: Bool
            var gatewayConnected: Bool
            var discoveredGatewayCount: Int
            var discoveryStatusText: String
            var screenRecordActive: Bool
        }

        struct DiagnosticsCompletionRequest: Equatable, Sendable {
            var gatewayConnected: Bool
            var discoveredGatewayCount: Int
            var talkConfigLoaded: Bool
            var notificationsAllowed: Bool
            var lastRunText: String
        }

        case diagnosticsContextSynced(DiagnosticsContextSync)
        case diagnosticsCompletionRequested(DiagnosticsCompletionRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .diagnosticsContextSynced(sync):
                state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled
                state.gatewayConnected = sync.gatewayConnected
                state.discoveredGatewayCount = sync.discoveredGatewayCount
                state.discoveryStatusText = sync.discoveryStatusText
                state.screenRecordActive = sync.screenRecordActive
                return .none

            case let .diagnosticsCompletionRequested(request):
                state.issueCount = SettingsDiagnostics.issueCount(
                    gatewayConnected: request.gatewayConnected,
                    discoveredGatewayCount: request.discoveredGatewayCount,
                    talkConfigLoaded: request.talkConfigLoaded,
                    notificationsAllowed: request.notificationsAllowed)
                state.lastRunText = request.lastRunText
                return .none
            }
        }
        .autoLogActions()
    }
}
