import ComposableArchitecture
import OpenClawChatUI
import Testing
@testable import OpenClaw

@MainActor
struct CommandSessionsFeatureTests {
    @Test func `unavailable refresh clears sessions and errors without loading`() async {
        let probe = CommandSessionsProbe()
        var initialState = CommandSessionsFeature.State()
        initialState.sessionEntries = .init(entries: [Self.session(key: "chat-existing")])
        initialState.loadingPhase = .inFlight
        initialState.loadErrorText = .init(value: "Previous error")
        let store = TestStore(initialState: initialState) {
            CommandSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(Self.refreshRequest(
            available: false,
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
        let presentation = Self.screenPresentation(store.state, available: false)
        #expect(presentation.headerDetail == "Gateway offline")
        #expect(presentation.emptySessionsPresentation.title == "Gateway offline")
        #expect(presentation.emptySessionsPresentation.detail == "Connect to the gateway.")
    }

    @Test func `available refresh loads recent sessions`() async {
        let probe = CommandSessionsProbe()
        let loadedSessions = [
            Self.session(key: "main", updatedAt: 4),
            Self.session(key: "chat-older", updatedAt: 1),
            Self.session(key: "agent:main:main", updatedAt: 6),
            Self.session(key: "chat-newer", updatedAt: 3),
        ]
        probe.result = .success(loadedSessions)
        var initialState = CommandSessionsFeature.State()
        initialState.loadErrorText = .init(value: "Previous error")
        let store = TestStore(initialState: initialState) {
            CommandSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(Self.refreshRequest(
            available: true,
            currentSessionKey: "chat-newer",
            defaultSessionKey: "main")))
        {
            $0.currentSession = .init(value: "chat-newer")
            $0.defaultSession = .init(value: "main")
            $0.loadingPhase = .inFlight
            $0.loadErrorText = nil
        }
        let loadingPresentation = Self.screenPresentation(store.state, available: true)
        #expect(loadingPresentation.headerDetail == "Loading recent sessions")
        #expect(loadingPresentation.showsLoadingIndicator)

        await store.receive(.refreshResponse(.init(result: .success(.init(entries: loadedSessions))))) {
            $0.loadingPhase = .idle
            $0.sessionEntries = .init(entries: loadedSessions)
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
        #expect(store.state.visibleSessions.map(\.key) == ["chat-newer", "chat-older"])
        let loadedPresentation = Self.screenPresentation(store.state, available: true)
        #expect(loadedPresentation.headerDetail == "2 sessions")
        #expect(loadedPresentation.sessionRows.map(\.id) == ["chat-session-chat-newer", "chat-session-chat-older"])
        #expect(loadedPresentation.sessionRows.first?.state == "open")
    }

    @Test func `available refresh clears sessions and shows reconnect copy on failure`() async {
        let probe = CommandSessionsProbe()
        probe.result = .failure(CommandSessionsProbeError.failed)
        var initialState = CommandSessionsFeature.State()
        initialState.sessionEntries = .init(entries: [Self.session(key: "chat-existing")])
        let store = TestStore(initialState: initialState) {
            CommandSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(Self.refreshRequest(
            available: true,
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
        let presentation = Self.screenPresentation(store.state, available: true)
        #expect(presentation.headerDetail == "No recent sessions")
        #expect(presentation.unavailableSessionsPresentation?.title == "Sessions unavailable")
        #expect(presentation.unavailableSessionsPresentation?.detail == "Try again after the gateway reconnects.")
    }

    private static func refreshRequest(
        available: Bool,
        currentSessionKey: String = "chat-current",
        defaultSessionKey: String = "main") -> CommandSessionsFeature.Action.RefreshRequest
    {
        .init(
            sessionsAvailability: .init(isAvailable: .init(value: available)),
            currentSession: .init(key: .init(value: currentSessionKey)),
            defaultSession: .init(key: .init(value: defaultSessionKey)))
    }

    private static func screenPresentation(
        _ state: CommandSessionsFeature.State,
        available: Bool = true) -> CommandSessionsScreenPresentation
    {
        state.screenPresentation(sessionsAvailability: .init(value: available))
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
}

@MainActor
struct CommandCenterRecentSessionsFeatureTests {
    @Test func `inactive refresh leaves cached overview sessions unchanged`() async {
        let probe = CommandSessionsProbe()
        var initialState = CommandCenterRecentSessionsFeature.State()
        initialState.defaultChatSessionEntry = Self.session(key: "main", updatedAt: 2)
        initialState.recentChatSessionEntries = .init(entries: [Self.session(key: "chat-existing", updatedAt: 1)])
        let store = TestStore(initialState: initialState) {
            CommandCenterRecentSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: .init(value: false)),
            sessionsAvailability: .init(isAvailable: .init(value: true)),
            currentSession: .init(key: .init(value: "chat-existing")),
            defaultSession: .init(key: .init(value: "main")))))
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `unavailable refresh clears cached overview sessions without loading`() async {
        let probe = CommandSessionsProbe()
        var initialState = CommandCenterRecentSessionsFeature.State()
        initialState.defaultChatSessionEntry = Self.session(key: "main", updatedAt: 2)
        initialState.recentChatSessionEntries = .init(entries: [Self.session(key: "chat-existing", updatedAt: 1)])
        let store = TestStore(initialState: initialState) {
            CommandCenterRecentSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: .init(value: true)),
            sessionsAvailability: .init(isAvailable: .init(value: false)),
            currentSession: .init(key: .init(value: "chat-existing")),
            defaultSession: .init(key: .init(value: "main")))))
        {
            $0.defaultChatSessionEntry = nil
            $0.recentChatSessionEntries = .init()
        }
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `available refresh selects default and recent overview sessions`() async {
        let probe = CommandSessionsProbe()
        let defaultSession = Self.session(key: "main", updatedAt: 3)
        let currentSession = Self.session(key: "chat-current", updatedAt: 2)
        let newestSession = Self.session(key: "chat-newest", updatedAt: 4)
        let oldSession = Self.session(key: "chat-old", updatedAt: 1)
        probe.result = .success([
            oldSession,
            Self.session(key: "agent:main:main", updatedAt: 6),
            currentSession,
            defaultSession,
            newestSession,
        ])
        let store = TestStore(initialState: CommandCenterRecentSessionsFeature.State()) {
            CommandCenterRecentSessionsFeature(client: probe.client)
        }
        let expectedSnapshot = CommandCenterRecentSessionsFeature.Snapshot(
            defaultChatSessionEntry: defaultSession,
            recentChatSessionEntries: .init(entries: [
                currentSession,
                newestSession,
                oldSession,
            ]))

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: .init(value: true)),
            sessionsAvailability: .init(isAvailable: .init(value: true)),
            currentSession: .init(key: .init(value: currentSession.key)),
            defaultSession: .init(key: .init(value: defaultSession.key)))))
        await store.receive(.refreshResponse(.init(result: .success(expectedSnapshot)))) {
            $0.defaultChatSessionEntry = defaultSession
            $0.recentChatSessionEntries = .init(entries: [
                currentSession,
                newestSession,
                oldSession,
            ])
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
    }

    @Test func `overview presentation caps preview rows and exposes view more`() {
        var state = CommandCenterRecentSessionsFeature.State()
        state.recentChatSessionEntries = .init(entries: [
            Self.session(key: "chat-current", updatedAt: 4),
            Self.session(key: "chat-newest", updatedAt: 3),
            Self.session(key: "chat-middle", updatedAt: 2),
            Self.session(key: "chat-old", updatedAt: 1),
        ])

        let presentation = state.presentation(
            activeAgentName: .init(value: "Rust Claw"),
            currentSession: .init(value: "chat-current"),
            defaultSession: .init(value: "main"))

        #expect(presentation.defaultChatWorkItem.title == "Rust Claw")
        #expect(presentation.defaultChatWorkItem.detail == "No recent activity")
        #expect(presentation.defaultChatWorkItem.state == "default")
        #expect(presentation.previewRows.map(\.id) == [
            "chat-session-chat-current",
            "chat-session-chat-newest",
            "chat-session-chat-middle",
        ])
        #expect(presentation.previewRows.first?.state == "open")
        #expect(presentation.showsViewMore)
    }

    @Test func `available refresh clears cached overview sessions on failure`() async {
        let probe = CommandSessionsProbe()
        probe.result = .failure(CommandSessionsProbeError.failed)
        var initialState = CommandCenterRecentSessionsFeature.State()
        initialState.defaultChatSessionEntry = Self.session(key: "main", updatedAt: 2)
        initialState.recentChatSessionEntries = .init(entries: [Self.session(key: "chat-existing", updatedAt: 1)])
        let store = TestStore(initialState: initialState) {
            CommandCenterRecentSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: .init(value: true)),
            sessionsAvailability: .init(isAvailable: .init(value: true)),
            currentSession: .init(key: .init(value: "chat-existing")),
            defaultSession: .init(key: .init(value: "main")))))
        await store.receive(.refreshResponse(.init(result: .failure(.failed)))) {
            $0.defaultChatSessionEntry = nil
            $0.recentChatSessionEntries = .init()
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
    }

    private static func session(key: String, updatedAt: Double) -> OpenClawChatSessionEntry {
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
}

private enum CommandSessionsProbeError: Error {
    case failed
}

private final class CommandSessionsProbe: @unchecked Sendable {
    var requestedLimits: [Int] = []
    var result: Result<[OpenClawChatSessionEntry], Error> = .success([])

    var client: CommandSessionsClient {
        CommandSessionsClient(listSessions: { limit in
            self.requestedLimits.append(limit)
            return try self.result.get()
        })
    }
}
