import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct TalkRuntimeIssueDetailsFeatureTests {
    @Test func `copy diagnostics publishes feedback and copies details`() async {
        let probe = ClipboardProbe()
        let issue = TalkRuntimeIssue.realtimeUnavailable(
            message: "Realtime unavailable",
            provider: "openai",
            model: "gpt-realtime-2",
            transport: "webrtc",
            phase: "connect")
        let store = TestStore(initialState: TalkRuntimeIssueDetailsFeature.State(issue: issue)) {
            TalkRuntimeIssueDetailsFeature(clipboard: probe.client)
        }

        await store.send(.copyDiagnosticsButtonTapped) {
            $0.copyFeedback = "Copied diagnostics"
        }
        await store.finish()

        #expect(probe.copiedText == issue.technicalDetails)
    }

    @Test func `changed issue clears feedback and copies updated diagnostics`() async {
        let probe = ClipboardProbe()
        let firstIssue = TalkRuntimeIssue.realtimeUnavailable(
            message: "First issue",
            provider: "openai",
            model: "gpt-realtime-2",
            transport: "webrtc",
            phase: "connect")
        let secondIssue = TalkRuntimeIssue.realtimeUnavailable(
            message: "Second issue",
            provider: "openai",
            model: "gpt-realtime-2",
            transport: "relay",
            phase: "fallback")
        let store = TestStore(initialState: TalkRuntimeIssueDetailsFeature.State(
            issue: firstIssue,
            copyFeedback: "Copied diagnostics"))
        {
            TalkRuntimeIssueDetailsFeature(clipboard: probe.client)
        }

        await store.send(.issueChanged(secondIssue)) {
            $0.issue = secondIssue
            $0.copyFeedback = nil
        }
        await store.send(.copyDiagnosticsButtonTapped) {
            $0.copyFeedback = "Copied diagnostics"
        }
        await store.finish()

        #expect(probe.copiedText == secondIssue.technicalDetails)
    }
}

private final class ClipboardProbe: @unchecked Sendable {
    var copiedText: String?

    var client: TalkRuntimeIssueClipboardClient {
        TalkRuntimeIssueClipboardClient(copy: { text in
            self.copiedText = text.value
        })
    }
}
