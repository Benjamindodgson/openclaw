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
        struct AppleReviewDemoModeEnabled: Equatable, Sendable { var value: Bool }
        struct DiagnosticsGatewayConnected: Equatable, Sendable { var value: Bool }
        struct DiscoveredGatewayCount: Equatable, Sendable { var value: Int }
        struct DiscoveryStatusText: Equatable, Sendable { var value: String }
        struct ScreenRecordActive: Equatable, Sendable { var value: Bool }
        struct TalkConfigLoaded: Equatable, Sendable { var value: Bool }
        struct NotificationsAllowed: Equatable, Sendable { var value: Bool }
        struct LastRunText: Equatable, Sendable { var value: String }

        struct DiagnosticsContextSync: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: AppleReviewDemoModeEnabled
            var gatewayConnected: DiagnosticsGatewayConnected
            var discoveredGatewayCount: DiscoveredGatewayCount
            var discoveryStatusText: DiscoveryStatusText
            var screenRecordActive: ScreenRecordActive
        }

        struct DiagnosticsCompletionRequest: Equatable, Sendable {
            var gatewayConnected: DiagnosticsGatewayConnected
            var discoveredGatewayCount: DiscoveredGatewayCount
            var talkConfigLoaded: TalkConfigLoaded
            var notificationsAllowed: NotificationsAllowed
            var lastRunText: LastRunText
        }

        case diagnosticsContextSynced(DiagnosticsContextSync)
        case diagnosticsCompletionRequested(DiagnosticsCompletionRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .diagnosticsContextSynced(sync):
                state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled.value
                state.gatewayConnected = sync.gatewayConnected.value
                state.discoveredGatewayCount = sync.discoveredGatewayCount.value
                state.discoveryStatusText = sync.discoveryStatusText.value
                state.screenRecordActive = sync.screenRecordActive.value
                return .none

            case let .diagnosticsCompletionRequested(request):
                state.issueCount = SettingsDiagnostics.issueCount(
                    gatewayConnected: request.gatewayConnected.value,
                    discoveredGatewayCount: request.discoveredGatewayCount.value,
                    talkConfigLoaded: request.talkConfigLoaded.value,
                    notificationsAllowed: request.notificationsAllowed.value)
                state.lastRunText = request.lastRunText.value
                return .none
            }
        }
        .autoLogActions()
    }
}
