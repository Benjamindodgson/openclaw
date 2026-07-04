import ComposableArchitecture

@Reducer
struct RootLaunchFeature {
    // swiftformat:disable redundantSendable
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
        case initialAppearanceRequested(String?)
        case initialChatSessionRequested(String?)
        case commandHandled
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .initialAppearanceRequested(rawValue):
                guard !state.didApplyInitialAppearance else { return .none }
                state.didApplyInitialAppearance = true
                guard let rawValue else { return .none }
                state.command = .applyAppearance(rawValue: rawValue)
                return .none

            case let .initialChatSessionRequested(sessionKey):
                guard !state.didApplyInitialChatSession else { return .none }
                state.didApplyInitialChatSession = true
                state.command = .focusChatSession(sessionKey)
                return .none

            case .commandHandled:
                state.command = nil
                return .none
            }
        }
        .autoLogActions()
    }
}
