import ComposableArchitecture
import OpenClawKit
import Testing
@testable import OpenClaw

@MainActor
struct GatewayStatusBuilderTests {
    @Test func `paused problem keeps error status`() {
        let state = GatewayStatusBuilder.build(
            gatewayServerName: nil,
            lastGatewayProblem: GatewayConnectionProblem(
                kind: .pairingRequired,
                owner: .gateway,
                title: "Pairing required",
                message: "Approve this device before reconnecting.",
                requestId: "req-123",
                retryable: false,
                pauseReconnect: true),
            gatewayStatusText: "Reconnecting…")

        #expect(state == .error)
    }

    @Test func `transient problem allows connecting status`() {
        let state = GatewayStatusBuilder.build(
            gatewayServerName: nil,
            lastGatewayProblem: GatewayConnectionProblem(
                kind: .timeout,
                owner: .network,
                title: "Connection timed out",
                message: "The gateway did not respond before the connection timed out.",
                retryable: true,
                pauseReconnect: false),
            gatewayStatusText: "Reconnecting…")

        #expect(state == .connecting)
    }

    @Test func `chat gateway pill labels match display state`() {
        #expect(ChatProTab.gatewayPillTitle(state: .disconnected, isGatewayUsable: false) == "Offline")
        #expect(ChatProTab.gatewayPillTitle(state: .connecting, isGatewayUsable: false) == "Connecting")
        #expect(ChatProTab.gatewayPillTitle(state: .error, isGatewayUsable: false) == "Attention")
        #expect(ChatProTab.gatewayPillTitle(state: .connected, isGatewayUsable: true) == "Connected")
        #expect(ChatProTab.gatewayPillTitle(state: .connected, isGatewayUsable: false) == "Unavailable")
    }

    @Test func `reducer refresh updates display state`() async {
        let problem = GatewayConnectionProblem(
            kind: .pairingRequired,
            owner: .gateway,
            title: "Pairing required",
            message: "Approve this device before reconnecting.",
            requestId: "req-123",
            retryable: false,
            pauseReconnect: true)
        let store = TestStore(initialState: GatewayStatusFeature.State(
            gatewayServerName: nil,
            lastGatewayProblem: problem,
            gatewayStatusText: "Reconnecting…"))
        {
            GatewayStatusFeature()
        }

        await store.send(.refresh) {
            $0.displayState = .error
        }
    }
}
