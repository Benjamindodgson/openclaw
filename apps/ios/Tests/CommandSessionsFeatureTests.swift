import ComposableArchitecture
import OpenClawChatUI
import Testing
@testable import OpenClaw

@MainActor
struct CommandSessionsFeatureTests {
    @Test func `unavailable refresh clears sessions and errors without loading`() async {
        let probe = CommandSessionsProbe()
        var initialState = CommandSessionsFeature.State()
        initialState.sessions = [Self.session(key: "chat-existing")]
        initialState.isLoading = true
        initialState.loadErrorText = "Previous error"
        let store = TestStore(initialState: initialState) {
            CommandSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(sessionsAvailable: false))) {
            $0.isLoading = false
            $0.sessions = []
            $0.loadErrorText = nil
        }
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `available refresh loads recent sessions`() async {
        let probe = CommandSessionsProbe()
        let loadedSessions = [Self.session(key: "chat-loaded")]
        probe.result = .success(loadedSessions)
        var initialState = CommandSessionsFeature.State()
        initialState.loadErrorText = "Previous error"
        let store = TestStore(initialState: initialState) {
            CommandSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(sessionsAvailable: true))) {
            $0.isLoading = true
            $0.loadErrorText = nil
        }
        await store.receive(.refreshResponse(.init(result: .success(loadedSessions)))) {
            $0.isLoading = false
            $0.sessions = loadedSessions
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
    }

    @Test func `available refresh clears sessions and shows reconnect copy on failure`() async {
        let probe = CommandSessionsProbe()
        probe.result = .failure(CommandSessionsProbeError.failed)
        var initialState = CommandSessionsFeature.State()
        initialState.sessions = [Self.session(key: "chat-existing")]
        let store = TestStore(initialState: initialState) {
            CommandSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(sessionsAvailable: true))) {
            $0.isLoading = true
            $0.loadErrorText = nil
        }
        await store.receive(.refreshResponse(.init(result: .failure(.failed)))) {
            $0.isLoading = false
            $0.sessions = []
            $0.loadErrorText = "Try again after the gateway reconnects."
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
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
}

@MainActor
struct CommandCenterRecentSessionsFeatureTests {
    @Test func `inactive refresh leaves cached overview sessions unchanged`() async {
        let probe = CommandSessionsProbe()
        var initialState = CommandCenterRecentSessionsFeature.State()
        initialState.defaultChatSessionEntry = Self.session(key: "main", updatedAt: 2)
        initialState.recentChatSessions = [Self.session(key: "chat-existing", updatedAt: 1)]
        let store = TestStore(initialState: initialState) {
            CommandCenterRecentSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(
            sceneActive: false,
            sessionsAvailable: true,
            currentSessionKey: "chat-existing",
            defaultSessionKey: "main")))
        await store.finish()

        #expect(probe.requestedLimits.isEmpty)
    }

    @Test func `unavailable refresh clears cached overview sessions without loading`() async {
        let probe = CommandSessionsProbe()
        var initialState = CommandCenterRecentSessionsFeature.State()
        initialState.defaultChatSessionEntry = Self.session(key: "main", updatedAt: 2)
        initialState.recentChatSessions = [Self.session(key: "chat-existing", updatedAt: 1)]
        let store = TestStore(initialState: initialState) {
            CommandCenterRecentSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(
            sceneActive: true,
            sessionsAvailable: false,
            currentSessionKey: "chat-existing",
            defaultSessionKey: "main")))
        {
            $0.defaultChatSessionEntry = nil
            $0.recentChatSessions = []
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
            recentChatSessions: [
                currentSession,
                newestSession,
                oldSession,
            ])

        await store.send(.refreshRequested(.init(
            sceneActive: true,
            sessionsAvailable: true,
            currentSessionKey: currentSession.key,
            defaultSessionKey: defaultSession.key)))
        await store.receive(.refreshResponse(.success(expectedSnapshot))) {
            $0.defaultChatSessionEntry = defaultSession
            $0.recentChatSessions = [
                currentSession,
                newestSession,
                oldSession,
            ]
        }
        await store.finish()

        #expect(probe.requestedLimits == [CommandCenterTab.recentSessionsFetchLimit])
    }

    @Test func `available refresh clears cached overview sessions on failure`() async {
        let probe = CommandSessionsProbe()
        probe.result = .failure(CommandSessionsProbeError.failed)
        var initialState = CommandCenterRecentSessionsFeature.State()
        initialState.defaultChatSessionEntry = Self.session(key: "main", updatedAt: 2)
        initialState.recentChatSessions = [Self.session(key: "chat-existing", updatedAt: 1)]
        let store = TestStore(initialState: initialState) {
            CommandCenterRecentSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(.init(
            sceneActive: true,
            sessionsAvailable: true,
            currentSessionKey: "chat-existing",
            defaultSessionKey: "main")))
        await store.receive(.refreshResponse(.failure(.failed))) {
            $0.defaultChatSessionEntry = nil
            $0.recentChatSessions = []
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
