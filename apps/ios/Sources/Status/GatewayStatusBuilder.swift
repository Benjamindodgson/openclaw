import ComposableArchitecture
import Foundation
import OpenClawKit

enum GatewayDisplayState: Equatable {
    case connected
    case connecting
    case error
    case disconnected
}

// swiftformat:disable redundantSendable
struct GatewayDisplayServerName: Equatable, Sendable {
    var value: String?
}

struct GatewayDisplayStatusText: Equatable, Sendable {
    var value: String
}

// swiftformat:enable redundantSendable

@Reducer
struct GatewayStatusFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayServerName: GatewayDisplayServerName
        var lastGatewayProblem: GatewayConnectionProblem?
        var gatewayStatusText: GatewayDisplayStatusText
        var displayState: GatewayDisplayState = .disconnected

        init(
            gatewayServerName: String? = nil,
            lastGatewayProblem: GatewayConnectionProblem? = nil,
            gatewayStatusText: String = "",
            displayState: GatewayDisplayState = .disconnected)
        {
            self.gatewayServerName = .init(value: gatewayServerName)
            self.lastGatewayProblem = lastGatewayProblem
            self.gatewayStatusText = .init(value: gatewayStatusText)
            self.displayState = displayState
        }
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
                    gatewayServerName: state.gatewayServerName.value,
                    lastGatewayProblem: state.lastGatewayProblem,
                    gatewayStatusText: state.gatewayStatusText.value)
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
