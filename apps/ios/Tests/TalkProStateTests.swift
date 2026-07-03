import Testing
@testable import OpenClaw

@Suite struct TalkProStateTests {
    @Test func disabledTalkWithoutLoadedConfigCanStartAndRetryLoad() {
        let state = TalkProState(
            gatewayConnected: true,
            isDemoMode: false,
            isEnabled: false,
            statusText: "Offline",
            isConfigLoaded: false,
            isListening: false,
            isSpeaking: false,
            isUserSpeechDetected: false,
            permissionState: .unknown,
            voiceModeSubtitle: nil,
            agentName: "Joshtimus Prime")

        #expect(state.title == "Voice config unavailable")
        #expect(state.chipText == "Config")
        #expect(state.primaryAction == .start)
        #expect(state.primaryButtonTitle == "Start Talk")
        #expect(state.heroSubtitle == "Open Voice settings after the gateway loads Talk configuration.")
        #expect(state.waveformMode(micLevel: 0.8) == .still)
    }

    @Test func enabledTalkWithoutLoadedConfigCanBeStopped() {
        let state = TalkProState(
            gatewayConnected: true,
            isDemoMode: false,
            isEnabled: true,
            statusText: "Offline",
            isConfigLoaded: false,
            isListening: false,
            isSpeaking: false,
            isUserSpeechDetected: false,
            permissionState: .unknown,
            voiceModeSubtitle: nil,
            agentName: "Joshtimus Prime")

        #expect(state.title == "Voice config unavailable")
        #expect(state.chipText == "Config")
        #expect(state.primaryAction == .stop)
        #expect(state.primaryButtonTitle == "Stop Talk")
        #expect(state.waveformMode(micLevel: 0.8) == .still)
    }

    @Test func enabledTalkWithLoadedConfigCanBeStopped() {
        let state = TalkProState(
            gatewayConnected: true,
            isDemoMode: false,
            isEnabled: true,
            statusText: "Ready",
            isConfigLoaded: true,
            isListening: false,
            isSpeaking: false,
            isUserSpeechDetected: false,
            permissionState: .ready,
            voiceModeSubtitle: nil,
            agentName: "Joshtimus Prime")

        #expect(state.title == "Ready to talk")
        #expect(state.chipText == "Ready")
        #expect(state.primaryAction == .stop)
    }

    @Test func missingScopeTakesPriorityOverUnloadedConfig() {
        let state = TalkProState(
            gatewayConnected: true,
            isDemoMode: false,
            isEnabled: false,
            statusText: "Offline",
            isConfigLoaded: false,
            isListening: false,
            isSpeaking: false,
            isUserSpeechDetected: false,
            permissionState: .missingScope("operator.talk.secrets"),
            voiceModeSubtitle: nil,
            agentName: "Joshtimus Prime")

        #expect(state.title == "Gateway permission required")
        #expect(state.chipText == "Needs approval")
        #expect(state.primaryAction == .enablePermission)
        #expect(state.primaryButtonTitle == "Enable Talk")
        #expect(state.heroSubtitle == "Gateway approval is required before this phone can capture voice.")
    }

    @Test func demoModeKeepsTalkDisabled() {
        let state = TalkProState(
            gatewayConnected: true,
            isDemoMode: true,
            isEnabled: true,
            statusText: "Ready",
            isConfigLoaded: true,
            isListening: true,
            isSpeaking: true,
            isUserSpeechDetected: true,
            permissionState: .ready,
            voiceModeSubtitle: nil,
            agentName: "Joshtimus Prime")

        #expect(state.title == "Demo mode only")
        #expect(state.chipText == "Demo")
        #expect(state.icon == "waveform.slash")
        #expect(state.primaryAction == .waiting)
        #expect(state.primaryButtonTitle == "Demo Mode Only")
        #expect(state.primaryButtonIcon == "lock.fill")
        #expect(state.heroSubtitle == "Voice is disabled in Apple Review demo mode.")
        #expect(state.waveformMode(micLevel: 0.8) == .still)
    }

    @Test func loadedConfigUsesVoiceSubtitleOrAgentForHeroSubtitle() {
        let stateWithSubtitle = TalkProState(
            gatewayConnected: true,
            isDemoMode: false,
            isEnabled: false,
            statusText: "Ready",
            isConfigLoaded: true,
            isListening: false,
            isSpeaking: false,
            isUserSpeechDetected: false,
            permissionState: .ready,
            voiceModeSubtitle: "  Realtime voice from the gateway  ",
            agentName: "Joshtimus Prime")

        #expect(stateWithSubtitle.heroSubtitle == "Realtime voice from the gateway")

        let stateWithoutSubtitle = TalkProState(
            gatewayConnected: true,
            isDemoMode: false,
            isEnabled: false,
            statusText: "Ready",
            isConfigLoaded: true,
            isListening: false,
            isSpeaking: false,
            isUserSpeechDetected: false,
            permissionState: .ready,
            voiceModeSubtitle: nil,
            agentName: "Joshtimus Prime")

        #expect(stateWithoutSubtitle.heroSubtitle == "Routes voice to Joshtimus Prime.")
    }

    @Test func offlineGatewayOwnsHeroSubtitle() {
        let state = TalkProState(
            gatewayConnected: false,
            isDemoMode: false,
            isEnabled: false,
            statusText: "Offline",
            isConfigLoaded: false,
            isListening: false,
            isSpeaking: false,
            isUserSpeechDetected: false,
            permissionState: .ready,
            voiceModeSubtitle: "Configured voice",
            agentName: "Joshtimus Prime")

        #expect(state.heroSubtitle == "Connect to your gateway to start a voice conversation.")
    }
}
