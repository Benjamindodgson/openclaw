import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct GatewayTrustPromptFeatureTests {
    @Test func `cancel button declines pending trust prompt`() async {
        let probe = GatewayTrustPromptProbe()
        let store = TestStore(initialState: GatewayTrustPromptFeature.State()) {
            GatewayTrustPromptFeature(client: probe.client)
        }

        await store.send(.cancelButtonTapped)
        await store.finish()

        #expect(probe.didDecline)
        #expect(!probe.didAccept)
    }

    @Test func `trust and connect button accepts pending trust prompt`() async {
        let probe = GatewayTrustPromptProbe()
        let store = TestStore(initialState: GatewayTrustPromptFeature.State()) {
            GatewayTrustPromptFeature(client: probe.client)
        }

        await store.send(.trustAndConnectButtonTapped)
        await store.finish()

        #expect(probe.didAccept)
        #expect(!probe.didDecline)
    }
}

private final class GatewayTrustPromptProbe: @unchecked Sendable {
    var didAccept = false
    var didDecline = false

    var client: GatewayTrustPromptClient {
        GatewayTrustPromptClient(
            acceptPendingTrustPrompt: {
                self.didAccept = true
            },
            declinePendingTrustPrompt: {
                self.didDecline = true
            })
    }
}
