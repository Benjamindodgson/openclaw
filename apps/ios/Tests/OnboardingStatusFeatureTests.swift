import ComposableArchitecture
import Testing
@testable import OpenClaw

@Suite(.serialized) struct OnboardingStatusFeatureTests {
    @Test @MainActor func `retry connection start owns visible and silent presentation`() async {
        var initialState = OnboardingStatusFeature.State(statusLine: "Pairing approval needed.")
        initialState.issue = .pairingRequired(requestId: "pair-1")
        initialState.connectMessageState = .init(value: "Pairing approval needed.")

        let store = TestStore(initialState: initialState) {
            OnboardingStatusFeature()
        }

        await store.send(.retryConnectionStarted(.init(silent: .init(value: false)))) {
            $0.connectingGatewayIDState = .init(value: "retry")
            $0.connectMessageState = .init(value: "Retrying…")
            $0.statusLineState = .init(value: "Retrying last connection…")
        }

        #expect(store.state.issue == .pairingRequired(requestId: "pair-1"))

        await store.send(.connectionFinished) {
            $0.connectingGatewayIDState = nil
        }

        await store.send(.retryConnectionStarted(.init(silent: .init(value: true)))) {
            $0.connectingGatewayIDState = .init(value: "retry-auto")
        }

        #expect(store.state.connectMessage == "Retrying…")
        #expect(store.state.statusLine == "Retrying last connection…")
    }
}
