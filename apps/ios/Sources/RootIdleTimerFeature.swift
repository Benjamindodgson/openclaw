import ComposableArchitecture
import SwiftUI
import UIKit

struct RootIdleTimerClient {
    var setIdleTimerDisabled: @MainActor @Sendable (Bool) async -> Void
}

extension RootIdleTimerClient: DependencyKey {
    static let live = RootIdleTimerClient(setIdleTimerDisabled: { disabled in
        UIApplication.shared.isIdleTimerDisabled = disabled
    })
    static let liveValue = Self.live
    static let testValue = RootIdleTimerClient(setIdleTimerDisabled: { _ in })
}

extension DependencyValues {
    var rootIdleTimer: RootIdleTimerClient {
        get { self[RootIdleTimerClient.self] }
        set { self[RootIdleTimerClient.self] = newValue }
    }
}

@Reducer
struct RootIdleTimerFeature {
    private let clientOverride: RootIdleTimerClient?

    init(client: RootIdleTimerClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    struct SceneActivity: Equatable, Sendable { var isActive: Bool }
    struct PreventSleepPreference: Equatable, Sendable { var isEnabled: Bool }
    struct TalkModeEnabled: Equatable, Sendable { var isEnabled: Bool }

    struct Snapshot: Equatable, Sendable {
        var sceneActivity: SceneActivity
        var preventSleep: PreventSleepPreference
        var talkMode: TalkModeEnabled
    }

    enum Action: Equatable, Sendable {
        case snapshotChanged(Snapshot)
        case disappeared
    }

    // swiftformat:enable redundantSendable

    private enum CancelID {
        case idleTimer
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.rootIdleTimer) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .snapshotChanged(snapshot):
                let isDisabled = snapshot.sceneActivity.isActive &&
                    (snapshot.preventSleep.isEnabled || snapshot.talkMode.isEnabled)
                return .run { _ in
                    try Task.checkCancellation()
                    await client.setIdleTimerDisabled(isDisabled)
                }
                .cancellable(id: CancelID.idleTimer, cancelInFlight: true)

            case .disappeared:
                return .cancel(id: CancelID.idleTimer)
            }
        }
        .autoLogActions()
    }
}

extension RootIdleTimerFeature.Snapshot {
    init(
        scenePhase: ScenePhase,
        preventSleep: RootIdleTimerFeature.PreventSleepPreference,
        talkMode: RootIdleTimerFeature.TalkModeEnabled)
    {
        self.init(
            sceneActivity: .init(isActive: scenePhase == .active),
            preventSleep: preventSleep,
            talkMode: talkMode)
    }
}
