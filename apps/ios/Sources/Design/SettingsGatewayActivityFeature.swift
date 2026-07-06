import ComposableArchitecture
import OpenClawKit

@Reducer
struct SettingsGatewayActivityFeature {
    private let diagnosticsRefreshClientOverride: SettingsGatewayDiagnosticsRefreshClient?
    private let problemTrustClientOverride: SettingsGatewayProblemTrustClient?
    private let reconnectClientOverride: SettingsGatewayReconnectClient?

    init(
        diagnosticsRefreshClient: SettingsGatewayDiagnosticsRefreshClient? = nil,
        problemTrustClient: SettingsGatewayProblemTrustClient? = nil,
        reconnectClient: SettingsGatewayReconnectClient? = nil)
    {
        self.diagnosticsRefreshClientOverride = diagnosticsRefreshClient
        self.problemTrustClientOverride = problemTrustClient
        self.reconnectClientOverride = reconnectClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        enum ReconnectPhase: Equatable, Sendable {
            case idle
            case inFlight
        }

        enum RefreshPhase: Equatable, Sendable {
            case idle
            case inFlight
        }

        var reconnectPhase = ReconnectPhase.idle
        var refreshPhase = RefreshPhase.idle
    }

    enum Action: Equatable, Sendable {
        struct SettingsGatewayActivityDemoModeEnabled: Equatable, Sendable { var value: Bool }

        struct DiagnosticsRefreshRequest: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: SettingsGatewayActivityDemoModeEnabled
        }

        struct ReconnectRequest: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: SettingsGatewayActivityDemoModeEnabled
        }

        struct RotatedCertificateTrustRequest: Equatable, Sendable { var problem: GatewayConnectionProblem }

        case diagnosticsRefreshRequested(DiagnosticsRefreshRequest)
        case reconnectFinished
        case reconnectRequested(ReconnectRequest)
        case reconnectStarted
        case refreshFinished
        case refreshStarted
        case rotatedCertificateTrustRequested(RotatedCertificateTrustRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsGatewayDiagnosticsRefresh) var dependencyDiagnosticsRefreshClient
            @Dependency(\.settingsGatewayProblemTrust) var dependencyProblemTrustClient
            @Dependency(\.settingsGatewayReconnect) var dependencyReconnectClient
            let diagnosticsRefreshClient = self.diagnosticsRefreshClientOverride ?? dependencyDiagnosticsRefreshClient
            let problemTrustClient = self.problemTrustClientOverride ?? dependencyProblemTrustClient
            let reconnectClient = self.reconnectClientOverride ?? dependencyReconnectClient

            switch action {
            case let .diagnosticsRefreshRequested(request):
                guard state.refreshPhase != .inFlight else { return .none }
                state.refreshPhase = .inFlight
                return .run { send in
                    if !request.isAppleReviewDemoModeEnabled.value {
                        await diagnosticsRefreshClient.refreshGateway()
                    }
                    await send(.refreshFinished)
                }

            case .reconnectFinished:
                state.reconnectPhase = .idle
                return .none

            case let .reconnectRequested(request):
                guard
                    !request.isAppleReviewDemoModeEnabled.value,
                    state.reconnectPhase != .inFlight
                else { return .none }
                state.reconnectPhase = .inFlight
                return .run { send in
                    await reconnectClient.reconnect()
                    await send(.reconnectFinished)
                }

            case .reconnectStarted:
                state.reconnectPhase = .inFlight
                return .none

            case .refreshFinished:
                state.refreshPhase = .idle
                return .none

            case .refreshStarted:
                state.refreshPhase = .inFlight
                return .none

            case let .rotatedCertificateTrustRequested(request):
                return .run { _ in
                    _ = await problemTrustClient.trustRotatedCertificate(request.problem)
                }
            }
        }
        .autoLogActions()
    }
}
