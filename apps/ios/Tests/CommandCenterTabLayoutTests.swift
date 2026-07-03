import ComposableArchitecture
import SwiftUI
import Testing
@testable import OpenClaw

@MainActor
@Suite struct CommandCenterTabLayoutTests {
    @Test func splitLayoutDisabledForCompactWidth() {
        #expect(
            !CommandCenterTab.usesSplitSectionsLayout(
                horizontalSizeClass: .compact,
                containerWidth: 1_200))
    }

    @Test func splitLayoutDisabledBelowWidthThreshold() {
        #expect(
            !CommandCenterTab.usesSplitSectionsLayout(
                horizontalSizeClass: .regular,
                containerWidth: 900))
    }

    @Test func splitLayoutEnabledForRegularWideLayout() {
        #expect(
            CommandCenterTab.usesSplitSectionsLayout(
                horizontalSizeClass: .regular,
                containerWidth: 1_024))
    }

    @Test func gatewayPresentationReducerUpdatesState() async {
        let presentation = Self.gatewayPresentation(
            gatewayDisplayState: .connected,
            gatewayRemoteAddress: "  studio.local:4455  ",
            gatewayAgentCount: 3,
            activeAgentName: "Joshtimus Prime")
        let store = TestStore(initialState: CommandCenterGatewayPresentationFeature.State()) {
            CommandCenterGatewayPresentationFeature()
        }

        await store.send(.presentationChanged(presentation)) {
            $0.presentation = presentation
        }

        #expect(store.state.presentation.connectionText == "Online")
        #expect(store.state.presentation.addressText == "studio.local:4455")
        #expect(store.state.presentation.agentCountText == "3")
    }

    @Test func gatewayPresentationOwnsCardHeaderAndEmptyStateCopy() {
        let connected = Self.gatewayPresentation(
            gatewayDisplayState: .connected,
            gatewayServerName: "  Studio Gateway  ",
            gatewayAgentCount: 3,
            activeAgentName: "Joshtimus Prime")
        let error = Self.gatewayPresentation(
            gatewayDisplayState: .error,
            activeAgentName: "Joshtimus Prime",
            gatewayDisplayStatusText: "Gateway error")

        #expect(connected.connectionText == "Online")
        #expect(connected.statusColor == OpenClawBrand.ok)
        #expect(connected.gatewaySubtitle == "Joshtimus Prime on Studio Gateway")
        #expect(connected.recentSessionsEmptyIcon == "bubble.left.and.text.bubble.right.fill")
        #expect(connected.recentSessionsEmptyTitle == "No recent sessions")
        #expect(connected.recentSessionsEmptyDetail == "Start a chat and it will appear here.")

        #expect(error.connectionText == "Attention")
        #expect(error.statusColor == OpenClawBrand.warn)
        #expect(error.addressText == "Unknown")
        #expect(error.agentCountText == "—")
        #expect(error.gatewaySubtitle == "Gateway error")
        #expect(error.recentSessionsEmptyIcon == "wifi.slash")
        #expect(error.recentSessionsEmptyTitle == "Gateway offline")
        #expect(error.recentSessionsEmptyDetail == "Connect to the gateway.")
    }

    private static func gatewayPresentation(
        gatewayDisplayState: GatewayDisplayState = .disconnected,
        gatewayRemoteAddress: String? = nil,
        gatewayServerName: String? = nil,
        gatewayAgentCount: Int = 0,
        activeAgentName: String = "Default Agent",
        gatewayDisplayStatusText: String = "Offline") -> CommandCenterGatewayPresentationState
    {
        CommandCenterGatewayPresentationState(
            gatewayDisplayState: gatewayDisplayState,
            gatewayRemoteAddress: gatewayRemoteAddress,
            gatewayServerName: gatewayServerName,
            gatewayAgentCount: gatewayAgentCount,
            activeAgentName: activeAgentName,
            gatewayDisplayStatusText: gatewayDisplayStatusText)
    }
}
