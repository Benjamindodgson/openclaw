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
    struct CommandText: Equatable, Sendable {
        var value: String

        init?(rawValue: String) {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            self.value = trimmed
        }
    }

    struct CommandTrigger: Equatable, Sendable {
        var commandText: CommandText?

        init(rawValue: String) {
            self.commandText = CommandText(rawValue: rawValue)
        }
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var commandText: CommandText?
    }

    enum Action: Equatable, Sendable {
        case commandTriggered(CommandTrigger)
        case dismissDelayElapsed
        case disappeared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.rootVoiceWakeToastSleep) var dependencySleeper
            let sleeper = self.sleepOverride ?? dependencySleeper

            switch action {
            case let .commandTriggered(trigger):
                guard let commandText = trigger.commandText else { return .none }
                state.commandText = commandText
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
