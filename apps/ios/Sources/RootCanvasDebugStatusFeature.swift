import ComposableArchitecture
import Foundation

struct RootCanvasDebugStatusClient {
    // swiftformat:disable redundantSendable
    struct Update: Equatable, Sendable {
        var title: String?
        var subtitle: String?
    }

    // swiftformat:enable redundantSendable

    var setDebugStatusEnabled: @MainActor @Sendable (Bool) async -> Void
    var updateDebugStatus: @MainActor @Sendable (Update) async -> Void
}

extension RootCanvasDebugStatusClient: DependencyKey {
    static let liveValue = RootCanvasDebugStatusClient(
        setDebugStatusEnabled: { _ in },
        updateDebugStatus: { _ in })
    static let testValue = RootCanvasDebugStatusClient(
        setDebugStatusEnabled: { _ in },
        updateDebugStatus: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        RootCanvasDebugStatusClient(
            setDebugStatusEnabled: { enabled in
                appModel.screen.setDebugStatusEnabled(enabled)
            },
            updateDebugStatus: { update in
                appModel.screen.updateDebugStatus(title: update.title, subtitle: update.subtitle)
            })
    }
}

extension DependencyValues {
    var rootCanvasDebugStatus: RootCanvasDebugStatusClient {
        get { self[RootCanvasDebugStatusClient.self] }
        set { self[RootCanvasDebugStatusClient.self] = newValue }
    }
}

@Reducer
struct RootCanvasDebugStatusFeature {
    private let clientOverride: RootCanvasDebugStatusClient?

    init(client: RootCanvasDebugStatusClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    struct Snapshot: Equatable, Sendable {
        var isEnabled: Bool
        var gatewayDisplayStatusText: String
        var gatewayServerName: String?
        var gatewayRemoteAddress: String?
    }

    enum Action: Equatable, Sendable {
        case snapshotChanged(Snapshot)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.rootCanvasDebugStatus) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .snapshotChanged(snapshot):
                return .run { _ in
                    await client.setDebugStatusEnabled(snapshot.isEnabled)
                    guard snapshot.isEnabled else { return }

                    let title = snapshot.gatewayDisplayStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let subtitle = snapshot.gatewayServerName ?? snapshot.gatewayRemoteAddress
                    await client.updateDebugStatus(.init(title: title, subtitle: subtitle))
                }
            }
        }
        .autoLogActions()
    }
}

extension RootCanvasDebugStatusFeature.Snapshot {
    @MainActor
    init(appModel: NodeAppModel, isEnabled: Bool) {
        self.init(
            isEnabled: isEnabled,
            gatewayDisplayStatusText: appModel.gatewayDisplayStatusText,
            gatewayServerName: appModel.gatewayServerName,
            gatewayRemoteAddress: appModel.gatewayRemoteAddress)
    }
}
