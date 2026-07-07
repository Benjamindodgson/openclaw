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

    struct DebugStatusEnabled: Equatable, Sendable { var isEnabled: Bool }

    struct GatewayDisplayStatusText: Equatable, Sendable {
        var value: String

        var trimmed: String {
            self.value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    struct GatewayServerName: Equatable, Sendable { var value: String? }

    struct GatewayRemoteAddress: Equatable, Sendable { var value: String? }

    struct Snapshot: Equatable, Sendable {
        var enabled: DebugStatusEnabled
        var gatewayDisplayStatusText: GatewayDisplayStatusText
        var gatewayServerName: GatewayServerName
        var gatewayRemoteAddress: GatewayRemoteAddress
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
                    await client.setDebugStatusEnabled(snapshot.enabled.isEnabled)
                    guard snapshot.enabled.isEnabled else { return }

                    let title = snapshot.gatewayDisplayStatusText.trimmed
                    let subtitle = snapshot.gatewayServerName.value ?? snapshot.gatewayRemoteAddress.value
                    await client.updateDebugStatus(.init(title: title, subtitle: subtitle))
                }
            }
        }
        .autoLogActions()
    }
}

extension RootCanvasDebugStatusFeature.Snapshot {
    @MainActor
    init(appModel: NodeAppModel, enabled: RootCanvasDebugStatusFeature.DebugStatusEnabled) {
        self.init(
            enabled: enabled,
            gatewayDisplayStatusText: .init(value: appModel.gatewayDisplayStatusText),
            gatewayServerName: .init(value: appModel.gatewayServerName),
            gatewayRemoteAddress: .init(value: appModel.gatewayRemoteAddress))
    }
}
