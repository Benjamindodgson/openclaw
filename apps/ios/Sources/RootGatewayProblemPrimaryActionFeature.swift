import ComposableArchitecture
import OpenClawKit

struct RootGatewayProblemPrimaryActionClient {
    var connectLastKnown: @MainActor @Sendable () async -> Void
    var openGatewaySettings: @MainActor @Sendable () async -> Void
    var openProtocolMismatchHelpIfNeeded: @MainActor @Sendable (GatewayConnectionProblem) async -> Bool
    var trustRotatedCertificate: @MainActor @Sendable (GatewayConnectionProblem) async -> Bool
}

extension RootGatewayProblemPrimaryActionClient: DependencyKey {
    static let liveValue = RootGatewayProblemPrimaryActionClient(
        connectLastKnown: {},
        openGatewaySettings: {},
        openProtocolMismatchHelpIfNeeded: { GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded($0) },
        trustRotatedCertificate: { _ in false })

    static let testValue = RootGatewayProblemPrimaryActionClient(
        connectLastKnown: {},
        openGatewaySettings: {},
        openProtocolMismatchHelpIfNeeded: { _ in false },
        trustRotatedCertificate: { _ in false })

    @MainActor
    static func live(
        gatewayController: GatewayConnectionController,
        openGatewaySettings: @escaping @MainActor @Sendable () async -> Void) -> Self
    {
        RootGatewayProblemPrimaryActionClient(
            connectLastKnown: {
                await gatewayController.connectLastKnown()
            },
            openGatewaySettings: openGatewaySettings,
            openProtocolMismatchHelpIfNeeded: { problem in
                GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem)
            },
            trustRotatedCertificate: { problem in
                await gatewayController.trustRotatedGatewayCertificate(from: problem)
            })
    }
}

extension DependencyValues {
    var rootGatewayProblemPrimaryAction: RootGatewayProblemPrimaryActionClient {
        get { self[RootGatewayProblemPrimaryActionClient.self] }
        set { self[RootGatewayProblemPrimaryActionClient.self] = newValue }
    }
}

@Reducer
struct RootGatewayProblemPrimaryActionFeature {
    private let clientOverride: RootGatewayProblemPrimaryActionClient?

    init(client: RootGatewayProblemPrimaryActionClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case primaryActionTapped(GatewayConnectionProblem)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.rootGatewayProblemPrimaryAction) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .primaryActionTapped(problem):
                if problem.canTrustRotatedCertificate {
                    return .run { _ in
                        _ = await client.trustRotatedCertificate(problem)
                    }
                }
                if problem.kind == .protocolMismatch {
                    return .run { _ in
                        _ = await client.openProtocolMismatchHelpIfNeeded(problem)
                    }
                }
                if problem.retryable {
                    return .run { _ in
                        await client.connectLastKnown()
                    }
                }
                return .run { _ in
                    await client.openGatewaySettings()
                }
            }
        }
        .autoLogActions()
    }
}
