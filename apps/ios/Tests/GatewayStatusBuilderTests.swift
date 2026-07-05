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

    @Test func `chat presentation state owns route header overrides`() {
        let routed = Self.chatState(
            .connected,
            isGatewayUsable: true,
            headerTitle: "  Chat  ",
            headerSubtitle: "  Agent conversation  ",
            showsAgentBadge: false)
        let standalone = Self.chatState(.connected, isGatewayUsable: true)
        let unbadged = Self.chatState(.connected, isGatewayUsable: true, showsAgentBadge: false)

        #expect(routed.headerDisplayTitle == "Chat")
        #expect(routed.headerDisplaySubtitle == "Agent conversation")
        #expect(standalone.headerDisplayTitle == "Joshtimus Prime")
        #expect(standalone.headerDisplaySubtitle == nil)
        #expect(unbadged.headerDisplayTitle == "Chat")
    }

    @Test func `chat presentation state owns agent badge fallback`() {
        let override = Self.chatState(.connected, agentBadgeOverride: "  BOT  ")
        let initials = Self.chatState(.connected, agentDisplayName: "Joshtimus Prime")
        let hyphenated = Self.chatState(.connected, agentDisplayName: "north-star")
        let fallback = Self.chatState(.connected, agentDisplayName: "   ")

        #expect(override.agentBadge == "BOT")
        #expect(initials.agentBadge == "JP")
        #expect(hyphenated.agentBadge == "NS")
        #expect(fallback.agentBadge == "OC")
    }

    @Test func `chat presentation reducer updates state`() async {
        let presentation = Self.chatState(.connected, isGatewayUsable: true)
        let store = TestStore(initialState: ChatProPresentationFeature.State()) {
            ChatProPresentationFeature()
        }

        await store.send(.presentationChanged(.init(presentation: presentation))) {
            $0.presentation = presentation
        }

        #expect(store.state.presentation.gatewayPillTitle == "Connected")
        #expect(store.state.presentation.messagePlaceholder == "Message Joshtimus Prime...")
    }

    @Test func `chat view model lifecycle reducer records transport mode`() async {
        let store = TestStore(initialState: ChatViewModelLifecycleFeature.State()) {
            ChatViewModelLifecycleFeature()
        }

        await store.send(.transportModeRecorded(.init(transportModeID: "gateway"))) {
            $0.transportModeID = "gateway"
        }
        await store.send(.transportModeRecorded(.init(transportModeID: "demo"))) {
            $0.transportModeID = "demo"
        }
    }

    @Test func `chat talk toggle focuses session and flips enabled state through client`() async {
        let probe = ChatTalkControlProbe()
        let store = TestStore(initialState: ChatTalkControlFeature.State()) {
            ChatTalkControlFeature(client: probe.client)
        }

        await store.send(.toggleRequested(.init(
            sessionKey: ChatSessionKey(rawValue: "session-1"),
            talkEnabled: .init(isEnabled: false))))
        await store.send(.toggleRequested(.init(
            sessionKey: ChatSessionKey(rawValue: "session-2"),
            talkEnabled: .init(isEnabled: true))))
        await store.finish()

        #expect(probe.focusedSessionKeys == ["session-1", "session-2"])
        #expect(probe.talkEnabledValues == [true, false])
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
        isGatewayUsable: Bool = false,
        agentDisplayName: String = "Joshtimus Prime",
        headerTitle: String? = nil,
        headerSubtitle: String? = nil,
        showsAgentBadge: Bool = true,
        agentBadgeOverride: String? = nil) -> ChatProPresentationState
    {
        ChatProPresentationState(
            gatewayDisplayState: gatewayDisplayState,
            isGatewayUsable: isGatewayUsable,
            agentDisplayName: agentDisplayName,
            headerTitle: headerTitle,
            headerSubtitle: headerSubtitle,
            showsAgentBadge: showsAgentBadge,
            agentBadgeOverride: agentBadgeOverride)
    }
}

private final class ChatTalkControlProbe: @unchecked Sendable {
    var focusedSessionKeys: [String?] = []
    var talkEnabledValues: [Bool] = []

    var client: ChatTalkControlClient {
        ChatTalkControlClient(
            focusChatSession: { sessionKey in
                self.focusedSessionKeys.append(sessionKey?.value)
            },
            setTalkEnabled: { enabled in
                self.talkEnabledValues.append(enabled)
            })
    }
}
