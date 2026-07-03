import ComposableArchitecture
import Foundation
import OpenClawKit
import SwiftUI

@Reducer
struct SettingsTalkPreferencesFeature {
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
        case gatewayTalkConfigSynced(
            configLoaded: Bool,
            apiKeyConfigured: Bool,
            usesRealtime: Bool)
        case gatewayTalkDisplayContextSynced(
            isAppleReviewDemoModeEnabled: Bool,
            transportLabel: String)
        case gatewayTalkRuntimeSynced(
            activeModeTitle: String,
            activeModeSubtitle: String?,
            lastIssueText: String?)
        case preferencesSynced(
            providerSelectionRaw: String,
            realtimeVoiceSelectionRaw: String,
            speechLocale: String,
            talkButtonEnabled: Bool,
            talkBackgroundEnabled: Bool,
            talkSpeakerphoneEnabled: Bool)
        case providerSelectionChanged(String)
        case realtimeVoiceSelectionChanged(String)
        case speechLocaleChanged(String)
        case talkBackgroundEnabledChanged(Bool)
        case talkButtonEnabledChanged(Bool)
        case talkSpeakerphoneEnabledChanged(Bool)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .gatewayTalkConfigSynced(configLoaded, apiKeyConfigured, usesRealtime):
                state.gatewayTalkConfigLoaded = configLoaded
                state.gatewayTalkApiKeyConfigured = apiKeyConfigured
                state.gatewayTalkUsesRealtime = usesRealtime
                return .none

            case let .gatewayTalkDisplayContextSynced(isAppleReviewDemoModeEnabled, transportLabel):
                state.isAppleReviewDemoModeEnabled = isAppleReviewDemoModeEnabled
                state.gatewayTalkTransportLabel = transportLabel
                return .none

            case let .gatewayTalkRuntimeSynced(activeModeTitle, activeModeSubtitle, lastIssueText):
                state.gatewayTalkActiveModeTitle = activeModeTitle
                state.gatewayTalkActiveModeSubtitle = activeModeSubtitle
                state.gatewayTalkLastIssueText = lastIssueText
                return .none

            case let .preferencesSynced(
                providerSelectionRaw,
                realtimeVoiceSelectionRaw,
                speechLocale,
                talkButtonEnabled,
                talkBackgroundEnabled,
                talkSpeakerphoneEnabled):
                state.providerSelectionRaw = TalkModeProviderSelection.resolved(providerSelectionRaw).rawValue
                state.realtimeVoiceSelectionRaw = Self.normalizedRealtimeVoice(realtimeVoiceSelectionRaw)
                state.speechLocale = speechLocale
                state.talkButtonEnabled = talkButtonEnabled
                state.talkBackgroundEnabled = talkBackgroundEnabled
                state.talkSpeakerphoneEnabled = talkSpeakerphoneEnabled
                return .none

            case let .providerSelectionChanged(rawValue):
                state.providerSelectionRaw = TalkModeProviderSelection.resolved(rawValue).rawValue
                return .none

            case let .realtimeVoiceSelectionChanged(rawValue):
                state.realtimeVoiceSelectionRaw = Self.normalizedRealtimeVoice(rawValue)
                return .none

            case let .speechLocaleChanged(speechLocale):
                state.speechLocale = speechLocale
                return .none

            case let .talkBackgroundEnabledChanged(enabled):
                state.talkBackgroundEnabled = enabled
                return .none

            case let .talkButtonEnabledChanged(enabled):
                state.talkButtonEnabled = enabled
                return .none

            case let .talkSpeakerphoneEnabledChanged(enabled):
                state.talkSpeakerphoneEnabled = enabled
                return .none
            }
        }
        .autoLogActions()
    }

    private static func normalizedRealtimeVoice(_ rawValue: String) -> String {
        TalkModeRealtimeVoiceSelection.resolvedOverride(rawValue) ?? ""
    }
}
