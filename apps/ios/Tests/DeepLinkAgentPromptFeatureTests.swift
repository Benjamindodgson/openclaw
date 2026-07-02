import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct DeepLinkAgentPromptFeatureTests {
    @Test func `cancel button declines pending agent deep link prompt`() async {
        let probe = DeepLinkAgentPromptProbe()
        let store = TestStore(initialState: DeepLinkAgentPromptFeature.State()) {
            DeepLinkAgentPromptFeature(client: probe.client)
        }

        await store.send(.cancelButtonTapped)
        await store.finish()

        #expect(probe.didDecline)
        #expect(!probe.didApprove)
    }

    @Test func `run button approves pending agent deep link prompt`() async {
        let probe = DeepLinkAgentPromptProbe()
        let store = TestStore(initialState: DeepLinkAgentPromptFeature.State()) {
            DeepLinkAgentPromptFeature(client: probe.client)
        }

        await store.send(.runButtonTapped)
        await store.finish()

        #expect(probe.didApprove)
        #expect(!probe.didDecline)
    }
}

private final class DeepLinkAgentPromptProbe: @unchecked Sendable {
    var didApprove = false
    var didDecline = false

    var client: DeepLinkAgentPromptClient {
        DeepLinkAgentPromptClient(
            approvePendingAgentDeepLinkPrompt: {
                self.didApprove = true
            },
            declinePendingAgentDeepLinkPrompt: {
                self.didDecline = true
            })
    }
}
