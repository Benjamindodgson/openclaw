import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct ExecApprovalPromptFeatureTests {
    @Test func `allow once button resolves pending approval once`() async {
        let probe = ExecApprovalPromptProbe()
        let store = TestStore(initialState: ExecApprovalPromptFeature.State()) {
            ExecApprovalPromptFeature(client: probe.client)
        }

        await store.send(.allowOnceButtonTapped)
        await store.finish()

        #expect(probe.decisions == [.allowOnce])
        #expect(!probe.didDismiss)
    }

    @Test func `allow always button resolves pending approval permanently`() async {
        let probe = ExecApprovalPromptProbe()
        let store = TestStore(initialState: ExecApprovalPromptFeature.State()) {
            ExecApprovalPromptFeature(client: probe.client)
        }

        await store.send(.allowAlwaysButtonTapped)
        await store.finish()

        #expect(probe.decisions == [.allowAlways])
        #expect(!probe.didDismiss)
    }

    @Test func `deny button resolves pending approval with denial`() async {
        let probe = ExecApprovalPromptProbe()
        let store = TestStore(initialState: ExecApprovalPromptFeature.State()) {
            ExecApprovalPromptFeature(client: probe.client)
        }

        await store.send(.denyButtonTapped)
        await store.finish()

        #expect(probe.decisions == [.deny])
        #expect(!probe.didDismiss)
    }

    @Test func `cancel button dismisses pending approval without a decision`() async {
        let probe = ExecApprovalPromptProbe()
        let store = TestStore(initialState: ExecApprovalPromptFeature.State()) {
            ExecApprovalPromptFeature(client: probe.client)
        }

        await store.send(.cancelButtonTapped)
        await store.finish()

        #expect(probe.decisions.isEmpty)
        #expect(probe.didDismiss)
    }
}

private final class ExecApprovalPromptProbe: @unchecked Sendable {
    var decisions: [ExecApprovalPromptDecision] = []
    var didDismiss = false

    var client: ExecApprovalPromptClient {
        ExecApprovalPromptClient(
            resolvePendingExecApprovalPrompt: { decision in
                self.decisions.append(decision)
            },
            dismissPendingExecApprovalPrompt: {
                self.didDismiss = true
            })
    }
}
