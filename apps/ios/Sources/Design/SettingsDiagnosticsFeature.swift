import ComposableArchitecture
import OpenClawKit
import SwiftUI

@Reducer
struct SettingsDiagnosticsFeature {
    // swiftformat:disable redundantSendable
    struct AppleReviewDemoModeEnabled: Equatable, Sendable { var value: Bool }
    struct DiscoveryStatusText: Equatable, Sendable { var value: String }
    struct DiagnosticsIssueCount: Equatable, Sendable { var value: Int }
    struct DiagnosticsGatewayConnected: Equatable, Sendable { var value: Bool }
    struct DiscoveredGatewayCount: Equatable, Sendable { var value: Int }
    struct LastRunText: Equatable, Sendable { var value: String }
    struct NotificationsAllowed: Equatable, Sendable { var value: Bool }
    struct ScreenRecordActive: Equatable, Sendable { var value: Bool }
    struct TalkConfigLoaded: Equatable, Sendable { var value: Bool }

    @ObservableState
    struct State: Equatable, Sendable {
        var discoveredGatewayCount = DiscoveredGatewayCount(value: 0)
        var discoveryStatusText = DiscoveryStatusText(value: "Discovery idle")
        var gatewayConnected = DiagnosticsGatewayConnected(value: false)
        var issueCount: DiagnosticsIssueCount?
        var isAppleReviewDemoModeEnabled = AppleReviewDemoModeEnabled(value: false)
        var lastRunText = LastRunText(value: "Not run")
        var screenRecordActive = ScreenRecordActive(value: false)

        var detailText: String {
            "System checks"
        }

        var healthValue: String {
            if self.isAppleReviewDemoModeEnabled.value { return "demo" }
            if self.gatewayConnected.value { return "ready" }
            if self.discoveredGatewayCount.value == 0 { return "check" }
            return "partial"
        }

        var healthColor: Color {
            self.isAppleReviewDemoModeEnabled.value || self.gatewayConnected.value
                ? OpenClawBrand.ok
                : OpenClawBrand.warn
        }

        var discoveryValue: String {
            "\(self.discoveredGatewayCount.value)"
        }

        var discoveryColor: Color {
            self.hasDiscoveredGateway ? OpenClawBrand.accent : .secondary
        }

        var hasDiscoveredGateway: Bool {
            self.discoveredGatewayCount.value > 0
        }

        var screenCaptureValue: String {
            self.screenRecordActive.value ? "live" : "idle"
        }

        var screenCaptureColor: Color {
            self.screenRecordActive.value ? OpenClawBrand.ok : .secondary
        }

        var runValue: String {
            guard let issueCount else { return "pending" }
            return issueCount.value == 0 ? "pass" : "\(issueCount.value)"
        }

        var runColor: Color {
            guard let issueCount else { return .secondary }
            return issueCount.value == 0 ? OpenClawBrand.ok : OpenClawBrand.warn
        }
    }

    enum Action: Equatable, Sendable {
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
                state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled
                state.gatewayConnected = sync.gatewayConnected
                state.discoveredGatewayCount = sync.discoveredGatewayCount
                state.discoveryStatusText = sync.discoveryStatusText
                state.screenRecordActive = sync.screenRecordActive
                return .none

            case let .diagnosticsCompletionRequested(request):
                state.issueCount = .init(value: SettingsDiagnostics.issueCount(
                    gatewayConnected: request.gatewayConnected.value,
                    discoveredGatewayCount: request.discoveredGatewayCount.value,
                    talkConfigLoaded: request.talkConfigLoaded.value,
                    notificationsAllowed: request.notificationsAllowed.value))
                state.lastRunText = request.lastRunText
                return .none
            }
        }
        .autoLogActions()
    }
}
