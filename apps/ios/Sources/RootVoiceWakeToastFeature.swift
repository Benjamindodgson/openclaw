import ComposableArchitecture
import Foundation

@Reducer
struct RootVoiceWakeToastFeature {
    private let sleepOverride: RootVoiceWakeToastSleepClient?

    private enum CancelID {
        case dismiss
    }

    init(sleeper: RootVoiceWakeToastSleepClient? = nil) {
        self.sleepOverride = sleeper
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var commandText: String?
    }

    enum Action: Equatable, Sendable {
        case commandTriggered(String)
        case dismissDelayElapsed
        case disappeared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.rootVoiceWakeToastSleep) var dependencySleeper
            let sleeper = self.sleepOverride ?? dependencySleeper

            switch action {
            case let .commandTriggered(command):
                let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                state.commandText = trimmed
                return .run { send in
                    try await sleeper.sleep()
                    await send(.dismissDelayElapsed)
                }
                .cancellable(id: CancelID.dismiss, cancelInFlight: true)

            case .dismissDelayElapsed:
                state.commandText = nil
                return .none

            case .disappeared:
                return .cancel(id: CancelID.dismiss)
            }
        }
        .autoLogActions()
    }
}

struct RootVoiceWakeToastSleepClient {
    var sleep: @Sendable () async throws -> Void
}

extension RootVoiceWakeToastSleepClient: DependencyKey {
    static let liveValue = RootVoiceWakeToastSleepClient(sleep: {
        try await Task.sleep(nanoseconds: 2_300_000_000)
    })

    static let testValue = RootVoiceWakeToastSleepClient(sleep: {})
}

extension DependencyValues {
    var rootVoiceWakeToastSleep: RootVoiceWakeToastSleepClient {
        get { self[RootVoiceWakeToastSleepClient.self] }
        set { self[RootVoiceWakeToastSleepClient.self] = newValue }
    }
}
