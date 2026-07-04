import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct GatewayProblemDetailsFeatureTests {
    @Test func `copy request ID publishes feedback and copies request ID`() async {
        let probe = GatewayProblemClipboardProbe()
        let store = TestStore(initialState: GatewayProblemDetailsFeature.State()) {
            GatewayProblemDetailsFeature(clipboard: probe.client)
        }

        await store.send(.copyRequestIDButtonTapped(.init(requestID: "req-123"))) {
            $0.copyFeedback = "Copied request ID"
        }
        await store.finish()

        #expect(probe.copiedText == "req-123")
    }

    @Test func `copy command publishes feedback and copies command`() async {
        let probe = GatewayProblemClipboardProbe()
        let store = TestStore(initialState: GatewayProblemDetailsFeature.State()) {
            GatewayProblemDetailsFeature(clipboard: probe.client)
        }

        await store.send(.copyCommandButtonTapped(.init(command: "openclaw gateway approve req-123"))) {
            $0.copyFeedback = "Copied command"
        }
        await store.finish()

        #expect(probe.copiedText == "openclaw gateway approve req-123")
    }
}

private final class GatewayProblemClipboardProbe: @unchecked Sendable {
    var copiedText: String?

    var client: GatewayProblemClipboardClient {
        GatewayProblemClipboardClient(copy: { text in
            self.copiedText = text
        })
    }
}
