import ComposableArchitecture
import OpenClawChatUI
import SwiftUI
import Testing
@testable import OpenClaw

@MainActor
struct IPadActivitySessionsFeatureTests {
    @Test func `inactive refresh clears loading and leaves current session details unchanged`() async {
        let probe = IPadActivitySessionsProbe()
        var initialState = IPadActivitySessionsFeature.State()
        initialState.sessionEntries = .init(entries: [Self.session(key: "chat-existing")])
        initialState.loadingPhase = .inFlight
        initialState.loadErrorText = .init(value: "Previous error")
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(Self.refreshRequest(
            isActive: false,
            isAvailable: true,
            currentSessionKey: "chat-current",
            defaultSessionKey: "main")))
        {
            $0.currentSession = .init(value: "chat-current")
            $0.defaultSession = .init(value: "main")
            $0.loadingPhase = .idle
        }
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `unavailable refresh clears sessions and errors without loading`() async {
        let probe = IPadActivitySessionsProbe()
        var initialState = IPadActivitySessionsFeature.State()
        initialState.sessionEntries = .init(entries: [Self.session(key: "chat-existing")])
        initialState.loadingPhase = .inFlight
        initialState.loadErrorText = .init(value: "Previous error")
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(Self.refreshRequest(
            isActive: true,
            isAvailable: false,
            currentSessionKey: "chat-current",
            defaultSessionKey: "main")))
        {
            $0.currentSession = .init(value: "chat-current")
            $0.defaultSession = .init(value: "main")
            $0.loadingPhase = .idle
            $0.sessionEntries = .init()
            $0.loadErrorText = nil
        }
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `available refresh loads recent sessions`() async {
        let probe = IPadActivitySessionsProbe()
        let loadedSessions = [
            Self.session(key: "main", updatedAt: 20),
            Self.session(key: "agent:main:main", updatedAt: 19),
            Self.session(key: "chat-1", updatedAt: 1),
            Self.session(key: "chat-2", updatedAt: 2),
            Self.session(key: "chat-3", updatedAt: 3),
            Self.session(key: "chat-4", updatedAt: 4),
            Self.session(key: "chat-5", updatedAt: 5),
            Self.session(key: "chat-6", updatedAt: 6),
            Self.session(key: "chat-7", updatedAt: 7),
            Self.session(key: "chat-8", updatedAt: 8),
            Self.session(key: "chat-9", updatedAt: 9),
        ]
        probe.result = .success(loadedSessions)
        var initialState = IPadActivitySessionsFeature.State()
        initialState.loadErrorText = .init(value: "Previous error")
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(Self.refreshRequest(
            isActive: true,
            isAvailable: true,
            currentSessionKey: "chat-9",
            defaultSessionKey: "main")))
        {
            $0.currentSession = .init(value: "chat-9")
            $0.defaultSession = .init(value: "main")
            $0.loadingPhase = .inFlight
            $0.loadErrorText = nil
        }
        let loadingPresentation = Self.screenPresentation(store.state)
        #expect(loadingPresentation.sessionMetricValue == "...")
        #expect(loadingPresentation.feedHeaderPresentation.value == "Loading")
        #expect(loadingPresentation.showsLoadingSessionsPlaceholder)
        #expect(loadingPresentation.loadingSessionsPresentation.title == "Loading sessions")
        #expect(loadingPresentation.loadingSessionsPresentation.detail == "Fetching recent activity from the gateway.")
        #expect(loadingPresentation.loadingSessionsPresentation.value == "loading")
        await store.receive(.refreshResponse(.init(result: .success(.init(entries: loadedSessions))))) {
            $0.loadingPhase = .idle
            $0.sessionEntries = .init(entries: loadedSessions)
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
        let loadedPresentation = Self.screenPresentation(store.state)
        #expect(loadedPresentation.sessionMetricValue == "8")
        #expect(loadedPresentation.sessionRows.map(\.id) == [
            "chat-session-chat-9",
            "chat-session-chat-8",
            "chat-session-chat-7",
            "chat-session-chat-6",
            "chat-session-chat-5",
            "chat-session-chat-4",
            "chat-session-chat-3",
            "chat-session-chat-2",
        ])
        #expect(loadedPresentation.feedHeaderPresentation.value == nil)
        #expect(!loadedPresentation.showsLoadingSessionsPlaceholder)
        #expect(store.state.visibleSessions.map(\.key) == [
            "chat-9",
            "chat-8",
            "chat-7",
            "chat-6",
            "chat-5",
            "chat-4",
            "chat-3",
            "chat-2",
        ])
    }

    @Test func `available refresh clears sessions and shows reconnect copy on failure`() async {
        let probe = IPadActivitySessionsProbe()
        probe.result = .failure(IPadActivitySessionsProbeError.failed)
        var initialState = IPadActivitySessionsFeature.State()
        initialState.sessionEntries = .init(entries: [Self.session(key: "chat-existing")])
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(Self.refreshRequest(
            isActive: true,
            isAvailable: true,
            currentSessionKey: "chat-current",
            defaultSessionKey: "main")))
        {
            $0.currentSession = .init(value: "chat-current")
            $0.defaultSession = .init(value: "main")
            $0.loadingPhase = .inFlight
            $0.loadErrorText = nil
        }
        await store.receive(.refreshResponse(.init(result: .failure(.failed)))) {
            $0.loadingPhase = .idle
            $0.sessionEntries = .init()
            $0.loadErrorText = .init(value: "Try again after the gateway reconnects.")
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
        let presentation = Self.screenPresentation(store.state)
        #expect(presentation.sessionMetricValue == "0")
        #expect(presentation.unavailableSessionsPresentation?.title == "Sessions unavailable")
        #expect(presentation.unavailableSessionsPresentation?.detail == "Try again after the gateway reconnects.")
        #expect(presentation.unavailableSessionsPresentation?.value == "error")
    }

    @Test func `gateway presentation refresh updates reducer state`() async {
        let presentation = Self.gatewayPresentation(
            gatewayDisplayState: .connected,
            gatewayRemoteAddress: "  studio.local:4455  ",
            gatewayAgentCount: 3)
        let store = TestStore(initialState: IPadActivitySessionsFeature.State()) {
            IPadActivitySessionsFeature()
        }

        await store.send(.gatewayPresentationChanged(presentation)) {
            $0.gatewayPresentation = presentation
        }

        #expect(store.state.gatewayPresentation.gatewayStateText == "Online")
        #expect(store.state.gatewayPresentation.agentCountText == "3")
        #expect(store.state.gatewayPresentation.gatewayDetailText == "studio.local:4455")
        #expect(
            Self.screenPresentation(store.state).gatewayPresentation
                == presentation)
    }

    @Test func `gateway presentation owns metric and row fallbacks`() {
        let connected = Self.gatewayPresentation(
            gatewayDisplayState: .connected,
            gatewayRemoteAddress: "  studio.local:4455  ",
            gatewayAgentCount: 3)
        let offline = Self.gatewayPresentation(
            gatewayDisplayState: .disconnected,
            gatewayDisplayStatusText: "  Pairing required  ",
            gatewayRemoteAddress: "   ",
            gatewayServerName: "  Office Gateway  ",
            gatewayAgentCount: 3)
        let empty = Self.gatewayPresentation(gatewayDisplayStatusText: "   ")

        #expect(connected.metricIcon == "checkmark.circle.fill")
        #expect(connected.rowIcon == "network")
        #expect(connected.gatewayStateText == "Online")
        #expect(connected.gatewayRowValue == "online")
        #expect(connected.gatewayStateColor == OpenClawBrand.ok)
        #expect(connected.agentCountText == "3")
        #expect(connected.settingsActionTitle == nil)
        #expect(!connected.showsSettingsAction)

        #expect(offline.metricIcon == "wifi.slash")
        #expect(offline.rowIcon == "wifi.slash")
        #expect(offline.gatewayStateText == "Pairing required")
        #expect(offline.gatewayRowValue == "pairing required")
        #expect(offline.gatewayStateColor == .secondary)
        #expect(offline.agentCountText == "offline")
        #expect(offline.gatewayDetailText == "Office Gateway")
        #expect(offline.settingsActionTitle == "Settings")
        #expect(offline.showsSettingsAction)

        #expect(empty.gatewayStateText == "Offline")
        #expect(empty.gatewayDetailText == "No gateway connection")
    }

    @Test func `screen presentation owns empty session copy`() {
        let state = IPadActivitySessionsFeature.State()

        let available = Self.screenPresentation(state, sessionsAvailable: true).emptySessionPresentation
        #expect(available.icon == "bubble.left.and.text.bubble.right")
        #expect(available.title == "No recent sessions")
        #expect(available.detail == "Start a chat and it will appear here.")
        #expect(available.value == "empty")
        #expect(available.actionTitle == "Chat")
        #expect(available.opensChat)

        let offline = Self.screenPresentation(state, sessionsAvailable: false).emptySessionPresentation
        #expect(offline.icon == "bubble.left.and.text.bubble.right")
        #expect(offline.title == "Session activity offline")
        #expect(offline.detail == "Connect to the gateway to load recent chat activity.")
        #expect(offline.value == "offline")
        #expect(offline.actionTitle == nil)
        #expect(!offline.opensChat)
    }

    @Test func `screen presentation owns refresh task identifier`() {
        let state = IPadActivitySessionsFeature.State()

        let active = Self.screenPresentation(
            state,
            sessionsMode: "fixture",
            currentSessionKey: "chat-current",
            defaultSessionKey: "main",
            isActive: true)
        #expect(active.refreshTaskID == "fixture:chat-current:main:active")

        let inactive = Self.screenPresentation(
            state,
            sessionsMode: "gateway",
            currentSessionKey: "chat-next",
            defaultSessionKey: "fallback",
            isActive: false)
        #expect(inactive.refreshTaskID == "gateway:chat-next:fallback:inactive")
    }

    @Test func `screen presentation owns share intake row`() {
        let state = IPadActivitySessionsFeature.State()

        let presentation = Self.screenPresentation(
            state,
            lastShareEventText: "Last share received from Safari.").shareIntakePresentation
        #expect(presentation.icon == "square.and.arrow.down")
        #expect(presentation.title == "Share intake")
        #expect(presentation.detail == "Last share received from Safari.")
        #expect(presentation.value == "iPad")
    }

    @Test func `screen presentation owns chrome copy`() {
        let presentation = Self.screenPresentation(IPadActivitySessionsFeature.State()).screenChromePresentation

        #expect(presentation.title == "Activity")
        #expect(presentation.subtitle == "Live device and gateway activity.")
    }

    @Test func `screen presentation owns feed header copy`() {
        let presentation = Self.screenPresentation(IPadActivitySessionsFeature.State()).feedHeaderPresentation

        #expect(presentation.title == "Recent activity")
        #expect(presentation.value == nil)
        #expect(presentation.actionTitle == "Refresh")
    }

    @Test func `screen presentation owns pending approval row`() {
        let state = IPadActivitySessionsFeature.State()

        #expect(Self.screenPresentation(state).pendingApprovalPresentation == nil)

        let preview = Self.screenPresentation(
            state,
            pendingApproval: Self.pendingApproval(
                commandText: "openclaw apply risky change",
                commandPreview: "Apply risky change")).pendingApprovalPresentation
        #expect(preview?.icon == "hand.raised.fill")
        #expect(preview?.title == "Approval needed")
        #expect(preview?.detail == "Apply risky change")
        #expect(preview?.value == "pending")

        let commandText = Self.screenPresentation(
            state,
            pendingApproval: Self.pendingApproval(commandText: "openclaw run checks")).pendingApprovalPresentation
        #expect(commandText?.detail == "openclaw run checks")
    }

    private static func refreshRequest(
        isActive: Bool,
        isAvailable: Bool,
        currentSessionKey: String = "chat-current",
        defaultSessionKey: String = "main") -> IPadActivitySessionsFeature.Action.RefreshRequest
    {
        .init(
            sceneActivity: .init(isActive: .init(value: isActive)),
            sessionsAvailability: .init(isAvailable: .init(value: isAvailable)),
            currentSession: .init(key: .init(value: currentSessionKey)),
            defaultSession: .init(key: .init(value: defaultSessionKey)))
    }

    private static func screenPresentation(
        _ state: IPadActivitySessionsFeature.State,
        sessionsAvailable: Bool = true,
        sessionsMode: String = "fixture",
        currentSessionKey: String = "chat-current",
        defaultSessionKey: String = "main",
        isActive: Bool = true,
        lastShareEventText: String = "No recent shares",
        pendingApproval: IPadActivityPendingApprovalSnapshot? = nil) -> IPadActivityScreenPresentation
    {
        state.screenPresentation(
            sessionsAvailability: .init(value: sessionsAvailable),
            sessionsMode: .init(value: sessionsMode),
            currentSession: .init(value: currentSessionKey),
            defaultSession: .init(value: defaultSessionKey),
            sceneActivity: .init(value: isActive),
            lastShareEventText: .init(value: lastShareEventText),
            pendingApproval: pendingApproval)
    }

    private static func pendingApproval(
        commandText: String,
        commandPreview: String? = nil) -> IPadActivityPendingApprovalSnapshot
    {
        .init(
            commandText: .init(value: commandText),
            commandPreview: .init(value: commandPreview))
    }

    private static func session(key: String, updatedAt: Double = 1) -> OpenClawChatSessionEntry {
        OpenClawChatSessionEntry(
            key: key,
            kind: "chat",
            displayName: key,
            surface: "ios",
            subject: "Test session",
            room: nil,
            space: nil,
            updatedAt: updatedAt,
            sessionId: key,
            systemSent: true,
            abortedLastRun: false,
            thinkingLevel: nil,
            verboseLevel: nil,
            inputTokens: nil,
            outputTokens: nil,
            totalTokens: nil,
            modelProvider: "openai",
            model: "gpt-5.5",
            contextTokens: 128_000)
    }

    private static func gatewayPresentation(
        gatewayDisplayState: GatewayDisplayState = .disconnected,
        gatewayDisplayStatusText: String = "Offline",
        gatewayRemoteAddress: String? = nil,
        gatewayServerName: String? = nil,
        gatewayAgentCount: Int = 0) -> IPadActivityGatewayPresentationState
    {
        IPadActivityGatewayPresentationState(
            gatewayDisplayState: gatewayDisplayState,
            gatewayDisplayStatusText: gatewayDisplayStatusText,
            gatewayRemoteAddress: gatewayRemoteAddress,
            gatewayServerName: gatewayServerName,
            gatewayAgentCount: gatewayAgentCount)
    }
}

private enum IPadActivitySessionsProbeError: Error {
    case failed
}

private final class IPadActivitySessionsProbe: @unchecked Sendable {
    var requestedLimits: [Int] = []
    var result: Result<[OpenClawChatSessionEntry], Error> = .success([])

    var client: IPadActivitySessionsClient {
        IPadActivitySessionsClient(listSessions: { limit in
            self.requestedLimits.append(limit)
            return try self.result.get()
        })
    }
}
