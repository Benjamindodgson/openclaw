import ComposableArchitecture
import SwiftUI

struct RootCameraFlashOverlay: View {
    var nonce: Int

    @State private var store: StoreOf<RootCameraFlashOverlayFeature>

    init(
        nonce: Int,
        store: StoreOf<RootCameraFlashOverlayFeature> = Store(
            initialState: RootCameraFlashOverlayFeature.State())
        {
            RootCameraFlashOverlayFeature()
        })
    {
        self.nonce = nonce
        self._store = SwiftUI.State(wrappedValue: store)
    }

    var body: some View {
        Color.white
            .opacity(self.store.opacity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(
                self.store.opacity > 0 ? .easeOut(duration: 0.08) : .easeOut(duration: 0.32),
                value: self.store.opacity)
            .onChange(of: self.nonce) { _, _ in
                self.store.send(.nonceChanged)
            }
            .onDisappear {
                self.store.send(.disappeared)
            }
    }
}

@Reducer
struct RootCameraFlashOverlayFeature {
    private let sleepOverride: RootCameraFlashOverlaySleepClient?

    private enum CancelID {
        case flash
    }

    init(sleeper: RootCameraFlashOverlaySleepClient? = nil) {
        self.sleepOverride = sleeper
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var opacity: Double = 0
    }

    enum Action: Equatable, Sendable {
        case nonceChanged
        case fadeOutDelayElapsed
        case disappeared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.rootCameraFlashOverlaySleep) var dependencySleeper
            let sleeper = self.sleepOverride ?? dependencySleeper

            switch action {
            case .nonceChanged:
                state.opacity = 0.85
                return .run { send in
                    try await sleeper.sleep()
                    await send(.fadeOutDelayElapsed)
                }
                .cancellable(id: CancelID.flash, cancelInFlight: true)

            case .fadeOutDelayElapsed:
                state.opacity = 0
                return .none

            case .disappeared:
                return .cancel(id: CancelID.flash)
            }
        }
        .autoLogActions()
    }
}

struct RootCameraFlashOverlaySleepClient {
    var sleep: @Sendable () async throws -> Void
}

extension RootCameraFlashOverlaySleepClient: DependencyKey {
    static let liveValue = RootCameraFlashOverlaySleepClient(sleep: {
        try await Task.sleep(nanoseconds: 110_000_000)
    })

    static let testValue = RootCameraFlashOverlaySleepClient(sleep: {})
}

extension DependencyValues {
    var rootCameraFlashOverlaySleep: RootCameraFlashOverlaySleepClient {
        get { self[RootCameraFlashOverlaySleepClient.self] }
        set { self[RootCameraFlashOverlaySleepClient.self] = newValue }
    }
}
