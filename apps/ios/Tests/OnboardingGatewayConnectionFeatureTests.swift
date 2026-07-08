import ComposableArchitecture
import Testing
@testable import OpenClaw

@Suite(.serialized) struct OnboardingGatewayConnectionFeatureTests {
    @Test @MainActor func `discovered gateway presentation trims host and prepares connection status action`() async {
        let store = TestStore(initialState: OnboardingGatewayConnectionFeature.State()) {
            OnboardingGatewayConnectionFeature()
        }

        let row = OnboardingGatewayConnectionFeature.State.discoveredGatewayRowPresentation(
            lanHost: .init(value: "  gateway.local  "),
            tailnetDNS: .init(value: nil))
        #expect(row.displayHost == .init(value: "gateway.local"))
        #expect(row.canConnect)

        let fallbackRow = OnboardingGatewayConnectionFeature.State.discoveredGatewayRowPresentation(
            lanHost: .init(value: "  "),
            tailnetDNS: .init(value: " tailnet.openclaw.ts.net "))
        #expect(fallbackRow.displayHost == .init(value: "tailnet.openclaw.ts.net"))
        #expect(fallbackRow.canConnect)

        let unresolvedRow = OnboardingGatewayConnectionFeature.State.discoveredGatewayRowPresentation(
            lanHost: .init(value: "  "),
            tailnetDNS: .init(value: nil))
        #expect(unresolvedRow.displayHost == .init(value: nil))
        #expect(!unresolvedRow.canConnect)

        await store.send(.discoveredGatewayConnectionRequested(.init(
            id: .init(value: "gateway-1"),
            name: .init(value: "Studio Mac"))))
        {
            $0.discoveredGatewayConnectionStatusAction = .connectionStarted(.init(
                id: .init(value: "gateway-1"),
                message: .init(value: "Connecting to Studio Mac…"),
                statusLine: .init(value: "Connecting to Studio Mac…"),
                clearsIssue: .init(value: true)))
        }

        await store.send(.discoveredGatewayConnectionStatusHandled) {
            $0.discoveredGatewayConnectionStatusAction = nil
        }
    }
}
