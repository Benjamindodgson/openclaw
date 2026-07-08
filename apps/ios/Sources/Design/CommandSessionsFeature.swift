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
struct CommandSessionsFailureMessage: Equatable, Sendable { var value: String }

enum CommandSessionsLoadingPhase: Equatable, Sendable {
    case idle
    case inFlight
}

struct CommandSessionsAvailable: Equatable, Sendable { var value: Bool }
struct CommandSessionReferenceKey: Equatable, Sendable { var value: String }
struct CommandSessionEntries: Equatable, Sendable {
    var entries: [OpenClawChatSessionEntry] = []
}

struct CommandSceneActive: Equatable, Sendable { var value: Bool }

enum CommandSessionsError: Error, Equatable, Sendable {
    case failed
}

struct CommandSessionsStatusPresentation: Equatable, Sendable {
    let icon: String
    let title: String
    let detail: String
}

struct CommandSessionsScreenPresentation: Equatable, Sendable {
    let headerTitle: String
    let headerDetail: String
    let panelTitle: String
    let showsLoadingIndicator: Bool
    let unavailableSessionsPresentation: CommandSessionsStatusPresentation?
    let emptySessionsPresentation: CommandSessionsStatusPresentation
    let sessionRows: [CommandCenterTab.WorkItem]
}

struct CommandCenterRecentSessionsPresentation: Equatable, Sendable {
    let previewRows: [CommandCenterTab.WorkItem]
    let showsViewMore: Bool
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
        var sessionEntries = CommandSessionEntries()
        var currentSession = CommandSessionReferenceKey(value: "")
        var defaultSession = CommandSessionReferenceKey(value: "")
        var loadingPhase = CommandSessionsLoadingPhase.idle
        var loadErrorText: CommandSessionsFailureMessage?

        var sessions: [OpenClawChatSessionEntry] {
            self.sessionEntries.entries
        }

        var visibleSessions: [OpenClawChatSessionEntry] {
            self.sessionEntries.entries
                .filter { CommandCenterTab.isRecentChatSession($0.key, defaultSessionKey: self.defaultSession.value) }
                .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
        }

        func sessionRows() -> [CommandCenterTab.WorkItem] {
            self.visibleSessions.map {
                CommandCenterTab.sessionWorkItem(
                    for: $0,
                    currentSessionKey: self.currentSession.value)
            }
        }

        func headerDetail(
            sessionRows: [CommandCenterTab.WorkItem],
            sessionsAvailability: CommandSessionsAvailable) -> String
        {
            if self.loadingPhase == .inFlight, self.sessions.isEmpty {
                return "Loading recent sessions"
            }
            let count = sessionRows.count
            guard count > 0 else {
                return sessionsAvailability.value ? "No recent sessions" : "Gateway offline"
            }
            return "\(count) \(count == 1 ? "session" : "sessions")"
        }

        var unavailableSessionsPresentation: CommandSessionsStatusPresentation? {
            self.loadErrorText.map {
                .init(
                    icon: "exclamationmark.triangle.fill",
                    title: "Sessions unavailable",
                    detail: $0.value)
            }
        }

        func emptySessionsPresentation(
            sessionsAvailability: CommandSessionsAvailable) -> CommandSessionsStatusPresentation
        {
            if sessionsAvailability.value {
                return .init(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    title: "No recent sessions",
                    detail: "Start a chat and it will appear here.")
            }
            return .init(
                icon: "wifi.slash",
                title: "Gateway offline",
                detail: "Connect to the gateway.")
        }

        func screenPresentation(
            sessionsAvailability: CommandSessionsAvailable) -> CommandSessionsScreenPresentation
        {
            let sessionRows = self.sessionRows()
            return .init(
                headerTitle: "Sessions",
                headerDetail: self.headerDetail(
                    sessionRows: sessionRows,
                    sessionsAvailability: sessionsAvailability),
                panelTitle: "Recent sessions",
                showsLoadingIndicator: self.loadingPhase == .inFlight,
                unavailableSessionsPresentation: self.unavailableSessionsPresentation,
                emptySessionsPresentation: self.emptySessionsPresentation(sessionsAvailability: sessionsAvailability),
                sessionRows: sessionRows)
        }
    }

    enum Action: Equatable, Sendable {
        struct SessionsAvailability: Equatable, Sendable {
            var isAvailable: CommandSessionsAvailable
        }

        struct RefreshRequest: Equatable, Sendable {
            var sessionsAvailability: SessionsAvailability
            var currentSession: SessionReference
            var defaultSession: SessionReference
        }

        struct RefreshResponse: Equatable, Sendable {
            var result: Result<CommandSessionEntries, CommandSessionsError>
        }

        struct SessionReference: Equatable, Sendable {
            var key: CommandSessionReferenceKey
        }

        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.commandSessions) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .refreshRequested(request):
                state.currentSession = request.currentSession.key
                state.defaultSession = request.defaultSession.key

                guard request.sessionsAvailability.isAvailable.value else {
                    state.loadingPhase = .idle
                    state.sessionEntries = .init()
                    state.loadErrorText = nil
                    return .none
                }

                state.loadingPhase = .inFlight
                state.loadErrorText = nil
                return .run { send in
                    do {
                        let sessions = try await client.listSessions(CommandCenterTab.recentSessionsFetchLimit)
                        await send(.refreshResponse(.init(result: .success(.init(entries: sessions)))))
                    } catch {
                        await send(.refreshResponse(.init(result: .failure(.failed))))
                    }
                }

            case let .refreshResponse(response):
                switch response.result {
                case let .success(sessionEntries):
                    state.loadingPhase = .idle
                    state.sessionEntries = sessionEntries
                    state.loadErrorText = nil
                    return .none

                case .failure:
                    state.loadingPhase = .idle
                    state.sessionEntries = .init()
                    state.loadErrorText = .init(value: "Try again after the gateway reconnects.")
                    return .none
                }
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
        var recentChatSessionEntries = CommandSessionEntries()

        var recentChatSessions: [OpenClawChatSessionEntry] {
            self.recentChatSessionEntries.entries
        }

        func presentation(currentSession: CommandSessionReferenceKey) -> CommandCenterRecentSessionsPresentation {
            let rows = self.recentChatSessions.map {
                CommandCenterTab.sessionWorkItem(
                    for: $0,
                    currentSessionKey: currentSession.value)
            }
            return .init(
                previewRows: Array(rows.prefix(3)),
                showsViewMore: rows.count > 3)
        }
    }

    struct Snapshot: Equatable, Sendable {
        var defaultChatSessionEntry: OpenClawChatSessionEntry?
        var recentChatSessionEntries: CommandSessionEntries
    }

    enum Action: Equatable, Sendable {
        struct SceneActivity: Equatable, Sendable {
            var isActive: CommandSceneActive
        }

        struct SessionsAvailability: Equatable, Sendable {
            var isAvailable: CommandSessionsAvailable
        }

        struct SessionReference: Equatable, Sendable {
            var key: CommandSessionReferenceKey
        }

        struct RefreshRequest: Equatable, Sendable {
            var sceneActivity: SceneActivity
            var sessionsAvailability: SessionsAvailability
            var currentSession: SessionReference
            var defaultSession: SessionReference
        }

        struct RefreshResponse: Equatable, Sendable {
            var result: Result<Snapshot, CommandSessionsError>
        }

        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.commandSessions) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .refreshRequested(request):
                guard request.sceneActivity.isActive.value else { return .none }
                guard request.sessionsAvailability.isAvailable.value else {
                    state.defaultChatSessionEntry = nil
                    state.recentChatSessionEntries = .init()
                    return .none
                }

                return .run { send in
                    do {
                        let sessions = try await client.listSessions(CommandCenterTab.recentSessionsFetchLimit)
                        let snapshot = Self.snapshot(
                            from: sessions,
                            currentSessionKey: request.currentSession.key.value,
                            defaultSessionKey: request.defaultSession.key.value)
                        await send(.refreshResponse(.init(result: .success(snapshot))))
                    } catch {
                        await send(.refreshResponse(.init(result: .failure(.failed))))
                    }
                }

            case let .refreshResponse(response):
                switch response.result {
                case let .success(snapshot):
                    state.defaultChatSessionEntry = snapshot.defaultChatSessionEntry
                    state.recentChatSessionEntries = snapshot.recentChatSessionEntries
                    return .none

                case .failure:
                    state.defaultChatSessionEntry = nil
                    state.recentChatSessionEntries = .init()
                    return .none
                }
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
            recentChatSessionEntries: .init(entries: self.sessionChoices(
                sessions,
                currentSessionKey: currentSessionKey,
                defaultSessionKey: defaultSessionKey)))
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
