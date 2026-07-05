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
        var providerSelectionRaw = TalkModeProviderSelection.gatewayDefault.rawValue
        var realtimeVoiceSelectionRaw = ""
        var speechLocale = TalkSpeechLocale.automaticID
        var talkButtonEnabled = true
        var talkBackgroundEnabled = false
        var talkSpeakerphoneEnabled = TalkDefaults.speakerphoneEnabledByDefault
        var gatewayTalkConfigLoaded = false
        var gatewayTalkApiKeyConfigured = false
        var gatewayTalkTransportLabel = "Not loaded"
        var gatewayTalkUsesRealtime = false
        var isAppleReviewDemoModeEnabled = false
        var gatewayTalkActiveModeTitle = "Not active"
        var gatewayTalkActiveModeSubtitle: String?
        var gatewayTalkLastIssueText: String?

        var providerSelection: TalkModeProviderSelection {
            TalkModeProviderSelection.resolved(self.providerSelectionRaw)
        }

        var talkApiKeyStatus: String {
            Self.talkApiKeyStatus(
                configLoaded: self.gatewayTalkConfigLoaded,
                apiKeyConfigured: self.gatewayTalkApiKeyConfigured)
        }

        var gatewayDiagnosticTalkConfigLoaded: Bool {
            self.isAppleReviewDemoModeEnabled || self.gatewayTalkConfigLoaded
        }

        var gatewayTalkConfigDetail: String {
            if self.isAppleReviewDemoModeEnabled { return "Demo mode only" }
            return self.gatewayTalkTransportLabel
        }

        var gatewayTalkConfigValue: String {
            if self.isAppleReviewDemoModeEnabled { return "demo" }
            return self.gatewayTalkConfigLoaded ? "loaded" : "missing"
        }

        var gatewayTalkConfigColor: Color {
            if self.isAppleReviewDemoModeEnabled { return .secondary }
            return self.gatewayTalkConfigLoaded ? OpenClawBrand.ok : .secondary
        }

        var gatewayTalkActiveVoiceDetail: String {
            Self.gatewayTalkActiveVoiceDetail(
                title: self.gatewayTalkActiveModeTitle,
                subtitle: self.gatewayTalkActiveModeSubtitle)
        }

        var gatewayTalkLastIssueDetail: String? {
            Self.gatewayTalkLastIssueDetail(self.gatewayTalkLastIssueText)
        }

        var shouldShowRealtimeVoicePicker: Bool {
            Self.shouldShowRealtimeVoicePicker(
                providerSelectionRaw: self.providerSelectionRaw,
                gatewayTalkUsesRealtime: self.gatewayTalkUsesRealtime)
        }

        static func shouldShowRealtimeVoicePicker(
            providerSelectionRaw: String,
            gatewayTalkUsesRealtime: Bool) -> Bool
        {
            TalkModeProviderSelection.resolved(providerSelectionRaw) == .openAIRealtime
                || gatewayTalkUsesRealtime
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
            var isAppleReviewDemoModeEnabled: Bool
            var transportLabel: String
        }

        struct GatewayTalkRuntimeSync: Equatable, Sendable {
            var activeModeTitle: String
            var activeModeSubtitle: String?
            var lastIssueText: String?
        }

        struct PreferencesSync: Equatable, Sendable {
            var providerSelectionRaw: String
            var realtimeVoiceSelectionRaw: String
            var speechLocale: String
            var talkButtonEnabled: Bool
            var talkBackgroundEnabled: Bool
            var talkSpeakerphoneEnabled: Bool
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
                state.gatewayTalkConfigLoaded = sync.configLoaded.value
                state.gatewayTalkApiKeyConfigured = sync.apiKeyConfigured.value
                state.gatewayTalkUsesRealtime = sync.usesRealtime.value
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
                state.providerSelectionRaw = TalkModeProviderSelection.resolved(sync.providerSelectionRaw).rawValue
                state.realtimeVoiceSelectionRaw =
                    SettingsTalkRealtimeVoiceSelection(rawValue: sync.realtimeVoiceSelectionRaw).value
                state.speechLocale = sync.speechLocale
                state.talkButtonEnabled = sync.talkButtonEnabled
                state.talkBackgroundEnabled = sync.talkBackgroundEnabled
                state.talkSpeakerphoneEnabled = sync.talkSpeakerphoneEnabled
                return .none

            case let .providerSelectionChanged(change):
                let selection = change.selection
                state.providerSelectionRaw = selection.rawValue
                return .run { _ in
                    await preferencesClient.setProviderSelection(selection)
                }

            case let .realtimeVoiceSelectionChanged(change):
                let voice = change.voice
                state.realtimeVoiceSelectionRaw = voice.value
                return .run { _ in
                    await preferencesClient.setRealtimeVoiceSelection(voice)
                }

            case let .speechLocaleChanged(change):
                state.speechLocale = change.locale.value
                return .none

            case let .talkBackgroundEnabledChanged(change):
                state.talkBackgroundEnabled = change.enabled.isEnabled
                return .none

            case let .talkButtonEnabledChanged(change):
                state.talkButtonEnabled = change.enabled.isEnabled
                return .none

            case let .talkSpeakerphoneEnabledChanged(change):
                let enabled = change.enabled
                state.talkSpeakerphoneEnabled = enabled.isEnabled
                return .run { _ in
                    await preferencesClient.setSpeakerphoneEnabled(enabled)
                }
            }
        }
        .autoLogActions()
    }
}
