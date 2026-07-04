import ComposableArchitecture

@Reducer
struct RootLaunchFeature {
    // swiftformat:disable redundantSendable
    struct InitialAppearanceRequest: Equatable, Sendable {
        var rawValue: String?
    }

    struct InitialChatSessionRequest: Equatable, Sendable {
        var sessionKey: String?
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var didApplyInitialAppearance = false
        var didApplyInitialChatSession = false
        var command: Command?
    }

    enum Command: Equatable, Sendable {
        case applyAppearance(rawValue: String)
        case focusChatSession(String?)
    }

    enum Action: Equatable, Sendable {
        case initialAppearanceRequested(InitialAppearanceRequest)
        case initialChatSessionRequested(InitialChatSessionRequest)
        case commandHandled
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .initialAppearanceRequested(request):
                guard !state.didApplyInitialAppearance else { return .none }
                state.didApplyInitialAppearance = true
                let rawValue = request.rawValue
                guard let rawValue else { return .none }
                state.command = .applyAppearance(rawValue: rawValue)
                return .none

            case let .initialChatSessionRequested(request):
                guard !state.didApplyInitialChatSession else { return .none }
                state.didApplyInitialChatSession = true
                state.command = .focusChatSession(request.sessionKey)
                return .none

            case .commandHandled:
                state.command = nil
                return .none
            }
        }
        .autoLogActions()
    }
}
