import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct TalkRuntimeIssueDetailsFeatureTests {
    @Test func `copy diagnostics publishes feedback and copies details`() async {
        let probe = ClipboardProbe()
        let store = TestStore(initialState: TalkRuntimeIssueDetailsFeature.State()) {
            TalkRuntimeIssueDetailsFeature(clipboard: probe.client)
        }

        await store.send(.copyDiagnosticsButtonTapped("diagnostic payload")) {
            $0.copyFeedback = "Copied diagnostics"
        }
        await store.finish()

        #expect(probe.copiedText == "diagnostic payload")
    }
}

private final class ClipboardProbe: @unchecked Sendable {
    var copiedText: String?

    var client: TalkRuntimeIssueClipboardClient {
        TalkRuntimeIssueClipboardClient(copy: { text in
            self.copiedText = text
        })
    }
}
