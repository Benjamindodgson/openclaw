import ComposableArchitecture

@Reducer
struct RootLaunchFeature {
    // swiftformat:disable redundantSendable
    struct InitialAppearanceRequest: Equatable, Sendable {
        var preference: AppAppearancePreference?
    }

    struct InitialChatSessionRequest: Equatable, Sendable {
        var sessionKey: ChatSessionKey?
    }

    struct ApplyAppearanceCommand: Equatable, Sendable {
        var preference: AppAppearancePreference
    }

    struct FocusChatSessionCommand: Equatable, Sendable {
        var sessionKey: ChatSessionKey?
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var didApplyInitialAppearance = false
        var didApplyInitialChatSession = false
        var command: Command?
    }

    enum Command: Equatable, Sendable {
        case applyAppearance(ApplyAppearanceCommand)
        case focusChatSession(FocusChatSessionCommand)
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
                guard let preference = request.preference else { return .none }
                state.command = .applyAppearance(ApplyAppearanceCommand(preference: preference))
                return .none

            case let .initialChatSessionRequested(request):
                guard !state.didApplyInitialChatSession else { return .none }
                state.didApplyInitialChatSession = true
                state.command = .focusChatSession(FocusChatSessionCommand(sessionKey: request.sessionKey))
                return .none

            case .commandHandled:
                state.command = nil
                return .none
            }
        }
        .autoLogActions()
    }
}
