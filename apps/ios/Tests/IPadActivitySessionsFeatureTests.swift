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
        initialState.sessions = [Self.session(key: "chat-existing")]
        initialState.isLoading = true
        initialState.loadErrorText = "Previous error"
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(sceneActive: false, sessionsAvailable: true)) {
            $0.isLoading = false
        }
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `unavailable refresh clears sessions and errors without loading`() async {
        let probe = IPadActivitySessionsProbe()
        var initialState = IPadActivitySessionsFeature.State()
        initialState.sessions = [Self.session(key: "chat-existing")]
        initialState.isLoading = true
        initialState.loadErrorText = "Previous error"
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(sceneActive: true, sessionsAvailable: false)) {
            $0.isLoading = false
            $0.sessions = []
            $0.loadErrorText = nil
        }
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `available refresh loads recent sessions`() async {
        let probe = IPadActivitySessionsProbe()
        let loadedSessions = [Self.session(key: "chat-loaded")]
        probe.result = .success(loadedSessions)
        var initialState = IPadActivitySessionsFeature.State()
        initialState.loadErrorText = "Previous error"
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(sceneActive: true, sessionsAvailable: true)) {
            $0.isLoading = true
            $0.loadErrorText = nil
        }
        await store.receive(.refreshResponse(.success(loadedSessions))) {
            $0.isLoading = false
            $0.sessions = loadedSessions
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
    }

    @Test func `available refresh clears sessions and shows reconnect copy on failure`() async {
        let probe = IPadActivitySessionsProbe()
        probe.result = .failure(IPadActivitySessionsProbeError.failed)
        var initialState = IPadActivitySessionsFeature.State()
        initialState.sessions = [Self.session(key: "chat-existing")]
        let store = TestStore(initialState: initialState) {
            IPadActivitySessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(sceneActive: true, sessionsAvailable: true)) {
            $0.isLoading = true
            $0.loadErrorText = nil
        }
        await store.receive(.refreshResponse(.failure(.failed))) {
            $0.isLoading = false
            $0.sessions = []
            $0.loadErrorText = "Try again after the gateway reconnects."
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

    private static func session(key: String) -> OpenClawChatSessionEntry {
        OpenClawChatSessionEntry(
            key: key,
            kind: "chat",
            displayName: key,
            surface: "ios",
            subject: "Test session",
            room: nil,
            space: nil,
            updatedAt: 1,
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
