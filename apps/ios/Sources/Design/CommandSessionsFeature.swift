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
