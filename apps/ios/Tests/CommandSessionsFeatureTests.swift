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

        await store.send(.refreshRequested(sessionsAvailable: false)) {
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

        await store.send(.refreshRequested(sessionsAvailable: true)) {
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
        let probe = CommandSessionsProbe()
        probe.result = .failure(CommandSessionsProbeError.failed)
        var initialState = CommandSessionsFeature.State()
        initialState.sessions = [Self.session(key: "chat-existing")]
        let store = TestStore(initialState: initialState) {
            CommandSessionsFeature(client: probe.client)
        }

        await store.send(.refreshRequested(sessionsAvailable: true)) {
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
