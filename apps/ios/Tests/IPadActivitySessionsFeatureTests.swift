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
        await store.receive(.refreshResponse(.init(result: .success(.init(entries: loadedSessions))))) {
            $0.loadingPhase = .idle
            $0.sessionEntries = .init(entries: loadedSessions)
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
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
