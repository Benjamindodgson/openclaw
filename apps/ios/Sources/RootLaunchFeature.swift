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
        enum OneShotPhase: Equatable, Sendable {
            case pending
            case applied
        }

        var initialAppearancePhase = OneShotPhase.pending
        var initialChatSessionPhase = OneShotPhase.pending
        var command: Command?

        var didApplyInitialAppearance: Bool {
            self.initialAppearancePhase == .applied
        }

        var didApplyInitialChatSession: Bool {
            self.initialChatSessionPhase == .applied
        }
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
                state.initialAppearancePhase = .applied
                guard let preference = request.preference else { return .none }
                state.command = .applyAppearance(ApplyAppearanceCommand(preference: preference))
                return .none

            case let .initialChatSessionRequested(request):
                guard !state.didApplyInitialChatSession else { return .none }
                state.initialChatSessionPhase = .applied
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
