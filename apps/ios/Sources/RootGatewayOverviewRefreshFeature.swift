import ComposableArchitecture

struct RootGatewayOverviewRefreshClient {
    var refreshGatewayOverviewIfConnected: @MainActor @Sendable () async -> Void
}

extension RootGatewayOverviewRefreshClient: DependencyKey {
    static let liveValue = RootGatewayOverviewRefreshClient(refreshGatewayOverviewIfConnected: {})
    static let testValue = RootGatewayOverviewRefreshClient(refreshGatewayOverviewIfConnected: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        RootGatewayOverviewRefreshClient(refreshGatewayOverviewIfConnected: {
            await appModel.refreshGatewayOverviewIfConnected()
        })
    }
}

extension DependencyValues {
    var rootGatewayOverviewRefresh: RootGatewayOverviewRefreshClient {
        get { self[RootGatewayOverviewRefreshClient.self] }
        set { self[RootGatewayOverviewRefreshClient.self] = newValue }
    }
}

@Reducer
struct RootGatewayOverviewRefreshFeature {
    private let clientOverride: RootGatewayOverviewRefreshClient?

    init(client: RootGatewayOverviewRefreshClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case sceneActiveRefreshRequested
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.rootGatewayOverviewRefresh) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case .sceneActiveRefreshRequested:
                return .run { _ in
                    await client.refreshGatewayOverviewIfConnected()
                }
            }
        }
        .autoLogActions()
    }
}
