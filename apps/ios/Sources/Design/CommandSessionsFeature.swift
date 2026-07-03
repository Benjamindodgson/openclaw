import ComposableArchitecture
import OpenClawChatUI

struct CommandSessionsClient {
    var listSessions: @Sendable @MainActor (_ limit: Int) async throws -> [OpenClawChatSessionEntry]
}

extension CommandSessionsClient: DependencyKey {
    static let liveValue = CommandSessionsClient(listSessions: { _ in [] })
    static let testValue = CommandSessionsClient(listSessions: { _ in [] })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        CommandSessionsClient(listSessions: { limit in
            let transport = appModel.makeChatTransport()
            let response = try await transport.listSessions(limit: limit)
            return response.sessions
        })
    }
}

extension DependencyValues {
    var commandSessions: CommandSessionsClient {
        get { self[CommandSessionsClient.self] }
        set { self[CommandSessionsClient.self] = newValue }
    }
}

// swiftformat:disable redundantSendable
enum CommandSessionsError: Error, Equatable, Sendable {
    case failed
}

// swiftformat:enable redundantSendable

@Reducer
struct CommandSessionsFeature {
    private let clientOverride: CommandSessionsClient?

    init(client: CommandSessionsClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var sessions: [OpenClawChatSessionEntry] = []
        var isLoading = false
        var loadErrorText: String?
    }

    enum Action: Equatable, Sendable {
        case refreshRequested(sessionsAvailable: Bool)
        case refreshResponse(Result<[OpenClawChatSessionEntry], CommandSessionsError>)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.commandSessions) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .refreshRequested(sessionsAvailable):
                guard sessionsAvailable else {
                    state.isLoading = false
                    state.sessions = []
                    state.loadErrorText = nil
                    return .none
                }

                state.isLoading = true
                state.loadErrorText = nil
                return .run { send in
                    do {
                        let sessions = try await client.listSessions(CommandCenterTab.recentSessionsFetchLimit)
                        await send(.refreshResponse(.success(sessions)))
                    } catch {
                        await send(.refreshResponse(.failure(.failed)))
                    }
                }

            case let .refreshResponse(.success(sessions)):
                state.isLoading = false
                state.sessions = sessions
                state.loadErrorText = nil
                return .none

            case .refreshResponse(.failure):
                state.isLoading = false
                state.sessions = []
                state.loadErrorText = "Try again after the gateway reconnects."
                return .none
            }
        }
        .autoLogActions()
    }
}

enum CommandSessionsStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<CommandSessionsFeature> {
        Store(initialState: CommandSessionsFeature.State()) {
            CommandSessionsFeature(client: .live(appModel: appModel))
        }
    }
}

@Reducer
struct CommandCenterRecentSessionsFeature {
    private let clientOverride: CommandSessionsClient?

    init(client: CommandSessionsClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var defaultChatSessionEntry: OpenClawChatSessionEntry?
        var recentChatSessions: [OpenClawChatSessionEntry] = []
    }

    struct Snapshot: Equatable, Sendable {
        var defaultChatSessionEntry: OpenClawChatSessionEntry?
        var recentChatSessions: [OpenClawChatSessionEntry]
    }

    enum Action: Equatable, Sendable {
        case refreshRequested(
            sceneActive: Bool,
            sessionsAvailable: Bool,
            currentSessionKey: String,
            defaultSessionKey: String)
        case refreshResponse(Result<Snapshot, CommandSessionsError>)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.commandSessions) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .refreshRequested(sceneActive, sessionsAvailable, currentSessionKey, defaultSessionKey):
                guard sceneActive else { return .none }
                guard sessionsAvailable else {
                    state.defaultChatSessionEntry = nil
                    state.recentChatSessions = []
                    return .none
                }

                return .run { send in
                    do {
                        let sessions = try await client.listSessions(CommandCenterTab.recentSessionsFetchLimit)
                        let snapshot = Self.snapshot(
                            from: sessions,
                            currentSessionKey: currentSessionKey,
                            defaultSessionKey: defaultSessionKey)
                        await send(.refreshResponse(.success(snapshot)))
                    } catch {
                        await send(.refreshResponse(.failure(.failed)))
                    }
                }

            case let .refreshResponse(.success(snapshot)):
                state.defaultChatSessionEntry = snapshot.defaultChatSessionEntry
                state.recentChatSessions = snapshot.recentChatSessions
                return .none

            case .refreshResponse(.failure):
                state.defaultChatSessionEntry = nil
                state.recentChatSessions = []
                return .none
            }
        }
        .autoLogActions()
    }

    private static func snapshot(
        from sessions: [OpenClawChatSessionEntry],
        currentSessionKey: String,
        defaultSessionKey: String) -> Snapshot
    {
        Snapshot(
            defaultChatSessionEntry: sessions.first { $0.key == defaultSessionKey },
            recentChatSessions: self.sessionChoices(
                sessions,
                currentSessionKey: currentSessionKey,
                defaultSessionKey: defaultSessionKey))
    }

    private static func sessionChoices(
        _ sessions: [OpenClawChatSessionEntry],
        currentSessionKey: String,
        defaultSessionKey: String) -> [OpenClawChatSessionEntry]
    {
        let sorted = sessions.sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
        var result: [OpenClawChatSessionEntry] = []
        var included = Set<String>()

        if CommandCenterTab.isRecentChatSession(currentSessionKey, defaultSessionKey: defaultSessionKey),
           let current = sorted.first(where: { $0.key == currentSessionKey })
        {
            result.append(current)
            included.insert(current.key)
        }

        for session in sorted {
            guard !included.contains(session.key) else { continue }
            guard CommandCenterTab.isRecentChatSession(session.key, defaultSessionKey: defaultSessionKey)
            else { continue }
            result.append(session)
            included.insert(session.key)
            if result.count >= 4 { break }
        }

        return result
    }
}

enum CommandCenterRecentSessionsStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<CommandCenterRecentSessionsFeature> {
        Store(initialState: CommandCenterRecentSessionsFeature.State()) {
            CommandCenterRecentSessionsFeature(client: .live(appModel: appModel))
        }
    }
}
