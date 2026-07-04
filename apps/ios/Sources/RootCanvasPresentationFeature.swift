import ComposableArchitecture

struct RootCanvasPresentationClient {
    var hideCanvas: @MainActor @Sendable () async -> Void
}

extension RootCanvasPresentationClient: DependencyKey {
    static let liveValue = RootCanvasPresentationClient(hideCanvas: {})
    static let testValue = RootCanvasPresentationClient(hideCanvas: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        RootCanvasPresentationClient(hideCanvas: {
            appModel.screen.hideCanvas()
        })
    }
}

extension DependencyValues {
    var rootCanvasPresentation: RootCanvasPresentationClient {
        get { self[RootCanvasPresentationClient.self] }
        set { self[RootCanvasPresentationClient.self] = newValue }
    }
}

@Reducer
struct RootCanvasPresentationFeature {
    private let clientOverride: RootCanvasPresentationClient?

    init(client: RootCanvasPresentationClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case closeButtonTapped
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.rootCanvasPresentation) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case .closeButtonTapped:
                return .run { _ in
                    await client.hideCanvas()
                }
            }
        }
        .autoLogActions()
    }
}
