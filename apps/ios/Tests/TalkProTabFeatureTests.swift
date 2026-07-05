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

        await store.send(.speakerphoneEnabledChanged(.init(enabled: false))) {
            $0.speakerphoneEnabled = false
        }
        await store.finish()

        #expect(probe.speakerphoneEnabledValues == [false])
    }

    @Test func `talk enabled change persists through client`() async {
        let probe = TalkProTabProbe()
        let store = TestStore(initialState: TalkProTabFeature.State()) {
            TalkProTabFeature(client: probe.client)
        }

        await store.send(.talkEnabledChanged(.init(enabled: true))) {
            $0.talkEnabled = true
        }
        await store.send(.talkEnabledChanged(.init(enabled: false))) {
            $0.talkEnabled = false
        }
        await store.finish()

        #expect(probe.talkEnabledValues == [true, false])
    }

    @Test func `start talk updates main session through client`() async {
        let probe = TalkProTabProbe()
        let store = TestStore(initialState: TalkProTabFeature.State()) {
            TalkProTabFeature(client: probe.client)
        }

        await store.send(.startTalkRequested(.init(sessionKey: "session-1"))) {
            $0.talkEnabled = true
        }
        await store.finish()

        #expect(probe.startedSessionKeys == ["session-1"])
    }
}

private final class TalkProTabProbe: @unchecked Sendable {
    var speakerphoneEnabledValues: [Bool] = []
    var talkEnabledValues: [Bool] = []
    var startedSessionKeys: [String?] = []

    var client: TalkProTabClient {
        TalkProTabClient(
            setSpeakerphoneEnabled: { enabled in
                self.speakerphoneEnabledValues.append(enabled)
            },
            setTalkEnabled: { enabled in
                self.talkEnabledValues.append(enabled)
            },
            startTalk: { sessionKey in
                self.startedSessionKeys.append(sessionKey?.value)
            })
    }
}
