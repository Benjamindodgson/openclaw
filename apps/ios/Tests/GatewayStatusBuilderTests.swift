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
        #expect(Self.chatState(.disconnected).gatewayPillTitle == "Offline")
        #expect(Self.chatState(.connecting).gatewayPillTitle == "Connecting")
        #expect(Self.chatState(.error).gatewayPillTitle == "Attention")
        #expect(Self.chatState(.connected, isGatewayUsable: true).gatewayPillTitle == "Connected")
        #expect(Self.chatState(.connected, isGatewayUsable: false).gatewayPillTitle == "Unavailable")
    }

    @Test func `chat presentation state owns gateway color and message placeholder`() {
        let offline = Self.chatState(.disconnected)
        let connected = Self.chatState(.connected, isGatewayUsable: true)
        let unavailable = Self.chatState(.connected, isGatewayUsable: false)

        #expect(offline.gatewayPillColor == .secondary)
        #expect(offline.messagePlaceholder == "Connect to a gateway")
        #expect(connected.gatewayPillColor == OpenClawBrand.ok)
        #expect(connected.messagePlaceholder == "Message Joshtimus Prime...")
        #expect(unavailable.gatewayPillColor == .secondary)
        #expect(unavailable.messagePlaceholder == "Connect to a gateway")
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

    private static func chatState(
        _ gatewayDisplayState: GatewayDisplayState,
        isGatewayUsable: Bool = false) -> ChatProPresentationState
    {
        ChatProPresentationState(
            gatewayDisplayState: gatewayDisplayState,
            isGatewayUsable: isGatewayUsable,
            agentDisplayName: "Joshtimus Prime")
    }
}
