import ComposableArchitecture
import Foundation
import OpenClawKit

enum GatewayDisplayState: Equatable {
    case connected
    case connecting
    case error
    case disconnected
}

@Reducer
struct GatewayStatusFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayServerName: String?
        var lastGatewayProblem: GatewayConnectionProblem?
        var gatewayStatusText: String
        var displayState: GatewayDisplayState = .disconnected
    }

    enum Action: Equatable, Sendable {
        case refresh
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                state.displayState = Self.displayState(
                    gatewayServerName: state.gatewayServerName,
                    lastGatewayProblem: state.lastGatewayProblem,
                    gatewayStatusText: state.gatewayStatusText)
                return .none
            }
        }
        .autoLogActions()
    }

    static func displayState(
        gatewayServerName: String?,
        lastGatewayProblem: GatewayConnectionProblem?,
        gatewayStatusText: String) -> GatewayDisplayState
    {
        if gatewayServerName != nil { return .connected }
        if let lastGatewayProblem, lastGatewayProblem.pauseReconnect { return .error }

        let text = gatewayStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.localizedCaseInsensitiveContains("connecting") ||
            text.localizedCaseInsensitiveContains("reconnecting")
        {
            return .connecting
        }

        if text.localizedCaseInsensitiveContains("error") {
            return .error
        }

        return .disconnected
    }
}

enum GatewayStatusBuilder {
    @MainActor
    static func build(appModel: NodeAppModel) -> GatewayDisplayState {
        self.build(
            gatewayServerName: appModel.gatewayServerName,
            lastGatewayProblem: appModel.lastGatewayProblem,
            gatewayStatusText: appModel.gatewayStatusText)
    }

    static func build(
        gatewayServerName: String?,
        lastGatewayProblem: GatewayConnectionProblem?,
        gatewayStatusText: String) -> GatewayDisplayState
    {
        GatewayStatusFeature.displayState(
            gatewayServerName: gatewayServerName,
            lastGatewayProblem: lastGatewayProblem,
            gatewayStatusText: gatewayStatusText)
    }
}
