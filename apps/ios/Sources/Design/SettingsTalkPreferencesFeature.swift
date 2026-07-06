import ComposableArchitecture
import Foundation
import OpenClawKit
import SwiftUI

// swiftformat:disable redundantSendable
struct SettingsTalkPreferencesClient: Sendable {
    var setProviderSelection: @MainActor @Sendable (TalkModeProviderSelection) -> Void
    var setRealtimeVoiceSelection: @MainActor @Sendable (SettingsTalkRealtimeVoiceSelection) -> Void
    var setSpeakerphoneEnabled: @MainActor @Sendable (SettingsTalkSpeakerphoneEnabled) -> Void
}

struct SettingsTalkRealtimeVoiceSelection: Equatable, Sendable {
    var value: String

    init(rawValue: String?) {
        self.value = TalkModeRealtimeVoiceSelection.resolvedOverride(rawValue) ?? ""
    }
}

struct SettingsTalkSpeechLocale: Equatable, Sendable {
    var value: String
}

struct SettingsTalkBackgroundEnabled: Equatable, Sendable {
    var isEnabled: Bool
}

struct SettingsTalkButtonEnabled: Equatable, Sendable {
    var isEnabled: Bool
}

struct SettingsTalkSpeakerphoneEnabled: Equatable, Sendable {
    var isEnabled: Bool
}

struct SettingsGatewayTalkConfigLoaded: Equatable, Sendable {
    var value: Bool
}

struct SettingsGatewayTalkApiKeyConfigured: Equatable, Sendable {
    var value: Bool
}

struct SettingsGatewayTalkUsesRealtime: Equatable, Sendable {
    var value: Bool
}

struct SettingsGatewayTalkAppleReviewDemoModeEnabled: Equatable, Sendable {
    var value: Bool
}

struct SettingsGatewayTalkTransportLabel: Equatable, Sendable {
    var value: String
}

struct SettingsGatewayTalkActiveModeTitle: Equatable, Sendable {
    var value: String
}

struct SettingsGatewayTalkActiveModeSubtitle: Equatable, Sendable {
    var value: String?
}

struct SettingsGatewayTalkLastIssueText: Equatable, Sendable {
    var value: String?
}

// swiftformat:enable redundantSendable

extension SettingsTalkPreferencesClient: DependencyKey {
    static let liveValue = SettingsTalkPreferencesClient(
        setProviderSelection: { _ in },
        setRealtimeVoiceSelection: { _ in },
        setSpeakerphoneEnabled: { _ in })
    static let testValue = SettingsTalkPreferencesClient(
        setProviderSelection: { _ in },
        setRealtimeVoiceSelection: { _ in },
        setSpeakerphoneEnabled: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsTalkPreferencesClient(
            setProviderSelection: { selection in
                appModel.setTalkProviderSelection(selection.rawValue)
            },
            setRealtimeVoiceSelection: { voice in
                appModel.setTalkRealtimeVoiceSelection(voice.value)
            },
            setSpeakerphoneEnabled: { enabled in
                appModel.setTalkSpeakerphoneEnabled(enabled.isEnabled)
            })
    }
}

extension DependencyValues {
    var settingsTalkPreferences: SettingsTalkPreferencesClient {
        get { self[SettingsTalkPreferencesClient.self] }
        set { self[SettingsTalkPreferencesClient.self] = newValue }
    }
}

@Reducer
struct SettingsTalkPreferencesFeature {
    private let preferencesClientOverride: SettingsTalkPreferencesClient?

    init(preferencesClient: SettingsTalkPreferencesClient? = nil) {
        self.preferencesClientOverride = preferencesClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var providerSelection = TalkModeProviderSelection.gatewayDefault
        var realtimeVoiceSelection = SettingsTalkRealtimeVoiceSelection(rawValue: nil)
        var speechLocale = SettingsTalkSpeechLocale(value: TalkSpeechLocale.automaticID)
        var talkButtonEnabled = SettingsTalkButtonEnabled(isEnabled: true)
        var talkBackgroundEnabled = SettingsTalkBackgroundEnabled(isEnabled: false)
        var talkSpeakerphoneEnabled = SettingsTalkSpeakerphoneEnabled(
            isEnabled: TalkDefaults.speakerphoneEnabledByDefault)
        var gatewayTalkConfigLoaded = SettingsGatewayTalkConfigLoaded(value: false)
        var gatewayTalkApiKeyConfigured = SettingsGatewayTalkApiKeyConfigured(value: false)
        var gatewayTalkTransportLabel = SettingsGatewayTalkTransportLabel(value: "Not loaded")
        var gatewayTalkUsesRealtime = SettingsGatewayTalkUsesRealtime(value: false)
        var isAppleReviewDemoModeEnabled = SettingsGatewayTalkAppleReviewDemoModeEnabled(value: false)
        var gatewayTalkActiveModeTitle = SettingsGatewayTalkActiveModeTitle(value: "Not active")
        var gatewayTalkActiveModeSubtitle = SettingsGatewayTalkActiveModeSubtitle(value: nil)
        var gatewayTalkLastIssueText = SettingsGatewayTalkLastIssueText(value: nil)

        var talkApiKeyStatus: String {
            Self.talkApiKeyStatus(
                configLoaded: self.gatewayTalkConfigLoaded.value,
                apiKeyConfigured: self.gatewayTalkApiKeyConfigured.value)
        }

        var gatewayDiagnosticTalkConfigLoaded: Bool {
            self.isAppleReviewDemoModeEnabled.value || self.gatewayTalkConfigLoaded.value
        }

        var gatewayTalkConfigDetail: String {
            if self.isAppleReviewDemoModeEnabled.value { return "Demo mode only" }
            return self.gatewayTalkTransportLabel.value
        }

        var gatewayTalkConfigValue: String {
            if self.isAppleReviewDemoModeEnabled.value { return "demo" }
            return self.gatewayTalkConfigLoaded.value ? "loaded" : "missing"
        }

        var gatewayTalkConfigColor: Color {
            if self.isAppleReviewDemoModeEnabled.value { return .secondary }
            return self.gatewayTalkConfigLoaded.value ? OpenClawBrand.ok : .secondary
        }

        var gatewayTalkActiveVoiceDetail: String {
            Self.gatewayTalkActiveVoiceDetail(
                title: self.gatewayTalkActiveModeTitle.value,
                subtitle: self.gatewayTalkActiveModeSubtitle.value)
        }

        var gatewayTalkLastIssueDetail: String? {
            Self.gatewayTalkLastIssueDetail(self.gatewayTalkLastIssueText.value)
        }

        var shouldShowRealtimeVoicePicker: Bool {
            Self.shouldShowRealtimeVoicePicker(
                providerSelection: self.providerSelection,
                gatewayTalkUsesRealtime: self.gatewayTalkUsesRealtime)
        }

        static func shouldShowRealtimeVoicePicker(
            providerSelection: TalkModeProviderSelection,
            gatewayTalkUsesRealtime: SettingsGatewayTalkUsesRealtime) -> Bool
        {
            providerSelection == .openAIRealtime || gatewayTalkUsesRealtime.value
        }

        static func talkApiKeyStatus(configLoaded: Bool, apiKeyConfigured: Bool) -> String {
            guard configLoaded else { return "Not loaded" }
            return apiKeyConfigured ? "Configured" : "Not configured"
        }

        static func gatewayTalkActiveVoiceDetail(title: String, subtitle: String?) -> String {
            let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = (subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty { return "Not active" }
            if subtitle.isEmpty { return title }
            return "\(title) • \(subtitle)"
        }

        static func gatewayTalkLastIssueDetail(_ text: String?) -> String? {
            let detail = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? nil : detail
        }
    }

    enum Action: Equatable, Sendable {
        struct ProviderSelectionChange: Equatable, Sendable {
            var selection: TalkModeProviderSelection
        }

        struct RealtimeVoiceSelectionChange: Equatable, Sendable {
            var voice: SettingsTalkRealtimeVoiceSelection
        }

        struct SpeechLocaleChange: Equatable, Sendable {
            var locale: SettingsTalkSpeechLocale
        }

        struct TalkBackgroundEnabledChange: Equatable, Sendable {
            var enabled: SettingsTalkBackgroundEnabled
        }

        struct TalkButtonEnabledChange: Equatable, Sendable {
            var enabled: SettingsTalkButtonEnabled
        }

        struct TalkSpeakerphoneEnabledChange: Equatable, Sendable {
            var enabled: SettingsTalkSpeakerphoneEnabled
        }

        struct GatewayTalkConfigSync: Equatable, Sendable {
            var configLoaded: SettingsGatewayTalkConfigLoaded
            var apiKeyConfigured: SettingsGatewayTalkApiKeyConfigured
            var usesRealtime: SettingsGatewayTalkUsesRealtime
        }

        struct GatewayTalkDisplayContextSync: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: SettingsGatewayTalkAppleReviewDemoModeEnabled
            var transportLabel: SettingsGatewayTalkTransportLabel
        }

        struct GatewayTalkRuntimeSync: Equatable, Sendable {
            var activeModeTitle: SettingsGatewayTalkActiveModeTitle
            var activeModeSubtitle: SettingsGatewayTalkActiveModeSubtitle
            var lastIssueText: SettingsGatewayTalkLastIssueText
        }

        struct PreferencesSync: Equatable, Sendable {
            var providerSelection: TalkModeProviderSelection
            var realtimeVoiceSelection: SettingsTalkRealtimeVoiceSelection
            var speechLocale: SettingsTalkSpeechLocale
            var talkButtonEnabled: SettingsTalkButtonEnabled
            var talkBackgroundEnabled: SettingsTalkBackgroundEnabled
            var talkSpeakerphoneEnabled: SettingsTalkSpeakerphoneEnabled
        }

        case gatewayTalkConfigSynced(GatewayTalkConfigSync)
        case gatewayTalkDisplayContextSynced(GatewayTalkDisplayContextSync)
        case gatewayTalkRuntimeSynced(GatewayTalkRuntimeSync)
        case preferencesSynced(PreferencesSync)
        case providerSelectionChanged(ProviderSelectionChange)
        case realtimeVoiceSelectionChanged(RealtimeVoiceSelectionChange)
        case speechLocaleChanged(SpeechLocaleChange)
        case talkBackgroundEnabledChanged(TalkBackgroundEnabledChange)
        case talkButtonEnabledChanged(TalkButtonEnabledChange)
        case talkSpeakerphoneEnabledChanged(TalkSpeakerphoneEnabledChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsTalkPreferences) var dependencyPreferencesClient
            let preferencesClient = self.preferencesClientOverride ?? dependencyPreferencesClient

            switch action {
            case let .gatewayTalkConfigSynced(sync):
                state.gatewayTalkConfigLoaded = sync.configLoaded
                state.gatewayTalkApiKeyConfigured = sync.apiKeyConfigured
                state.gatewayTalkUsesRealtime = sync.usesRealtime
                return .none

            case let .gatewayTalkDisplayContextSynced(sync):
                state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled
                state.gatewayTalkTransportLabel = sync.transportLabel
                return .none

            case let .gatewayTalkRuntimeSynced(sync):
                state.gatewayTalkActiveModeTitle = sync.activeModeTitle
                state.gatewayTalkActiveModeSubtitle = sync.activeModeSubtitle
                state.gatewayTalkLastIssueText = sync.lastIssueText
                return .none

            case let .preferencesSynced(sync):
                state.providerSelection = sync.providerSelection
                state.realtimeVoiceSelection = sync.realtimeVoiceSelection
                state.speechLocale = sync.speechLocale
                state.talkButtonEnabled = sync.talkButtonEnabled
                state.talkBackgroundEnabled = sync.talkBackgroundEnabled
                state.talkSpeakerphoneEnabled = sync.talkSpeakerphoneEnabled
                return .none

            case let .providerSelectionChanged(change):
                let selection = change.selection
                state.providerSelection = selection
                return .run { _ in
                    await preferencesClient.setProviderSelection(selection)
                }

            case let .realtimeVoiceSelectionChanged(change):
                let voice = change.voice
                state.realtimeVoiceSelection = voice
                return .run { _ in
                    await preferencesClient.setRealtimeVoiceSelection(voice)
                }

            case let .speechLocaleChanged(change):
                state.speechLocale = change.locale
                return .none

            case let .talkBackgroundEnabledChanged(change):
                state.talkBackgroundEnabled = change.enabled
                return .none

            case let .talkButtonEnabledChanged(change):
                state.talkButtonEnabled = change.enabled
                return .none

            case let .talkSpeakerphoneEnabledChanged(change):
                let enabled = change.enabled
                state.talkSpeakerphoneEnabled = enabled
                return .run { _ in
                    await preferencesClient.setSpeakerphoneEnabled(enabled)
                }
            }
        }
        .autoLogActions()
    }
}
