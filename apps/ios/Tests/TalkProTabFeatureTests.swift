import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct TalkProTabFeatureTests {
    @Test func `permission prompt presentation opens and closes`() async {
        let store = TestStore(initialState: TalkProTabFeature.State()) {
            TalkProTabFeature()
        }

        await store.send(.permissionRequired) {
            $0.showPermissionPrompt = true
        }
        await store.send(.permissionPromptDismissed) {
            $0.showPermissionPrompt = false
        }
    }

    @Test func `permission ready dismisses permission prompt`() async {
        let store = TestStore(initialState: TalkProTabFeature.State(showPermissionPrompt: true)) {
            TalkProTabFeature()
        }

        await store.send(.permissionReady) {
            $0.showPermissionPrompt = false
        }
    }

    @Test func `runtime issue details presentation opens and closes`() async {
        let store = TestStore(initialState: TalkProTabFeature.State()) {
            TalkProTabFeature()
        }

        await store.send(.runtimeIssueDetailsButtonTapped) {
            $0.showTalkIssueDetails = true
        }
        await store.send(.runtimeIssueDetailsDismissed) {
            $0.showTalkIssueDetails = false
        }
    }

    @Test func `speakerphone toggle persists through client`() async {
        let probe = TalkProTabProbe()
        let store = TestStore(initialState: TalkProTabFeature.State()) {
            TalkProTabFeature(client: probe.client)
        }

        await store.send(.speakerphoneEnabledChanged(false)) {
            $0.speakerphoneEnabled = false
        }
        await store.finish()

        #expect(probe.speakerphoneEnabledValues == [false])
    }
}

private final class TalkProTabProbe: @unchecked Sendable {
    var speakerphoneEnabledValues: [Bool] = []

    var client: TalkProTabClient {
        TalkProTabClient(setSpeakerphoneEnabled: { enabled in
            self.speakerphoneEnabledValues.append(enabled)
        })
    }
}
