import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@Suite struct VoiceWakePreferencesTests {
    @Test func sanitizeTriggerWordsTrimsAndDropsEmpty() {
        #expect(VoiceWakePreferences.sanitizeTriggerWords([" openclaw ", "", " \nclaude\t"]) == ["openclaw", "claude"])
    }

    @Test func sanitizeTriggerWordsFallsBackToDefaultsWhenEmpty() {
        #expect(VoiceWakePreferences.sanitizeTriggerWords(["", "  "]) == VoiceWakePreferences.defaultTriggerWords)
    }

    @Test func sanitizeTriggerWordsLimitsWordLength() {
        let long = String(repeating: "x", count: VoiceWakePreferences.maxWordLength + 5)
        let cleaned = VoiceWakePreferences.sanitizeTriggerWords(["ok", long])
        #expect(cleaned[1].count == VoiceWakePreferences.maxWordLength)
    }

    @Test func sanitizeTriggerWordsLimitsWordCount() {
        let words = (1...VoiceWakePreferences.maxWords + 3).map { "w\($0)" }
        let cleaned = VoiceWakePreferences.sanitizeTriggerWords(words)
        #expect(cleaned.count == VoiceWakePreferences.maxWords)
    }

    @Test func displayStringUsesSanitizedWords() {
        #expect(VoiceWakePreferences.displayString(for: ["", " "]) == "openclaw, claude")
    }

    @Test func loadAndSaveTriggerWordsRoundTrip() {
        let suiteName = "VoiceWakePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        #expect(VoiceWakePreferences.loadTriggerWords(defaults: defaults) == VoiceWakePreferences.defaultTriggerWords)
        VoiceWakePreferences.saveTriggerWords(["computer"], defaults: defaults)
        #expect(VoiceWakePreferences.loadTriggerWords(defaults: defaults) == ["computer"])
    }

    @Test @MainActor func `reducer commit publishes sanitized snapshot`() async {
        let store = TestStore(initialState: VoiceWakeWordsSettingsFeature.State(
            triggerWords: [" openclaw ", "", "claude"]))
        {
            VoiceWakeWordsSettingsFeature(preferences: Self.preferencesClient())
        }

        await store.send(.commitTriggerWords) {
            $0.syncSnapshot = ["openclaw", "claude"]
            $0.syncRequestID = 1
        }
    }

    @Test @MainActor func `reducer restores defaults when appearing with empty words`() async {
        let store = TestStore(initialState: VoiceWakeWordsSettingsFeature.State(triggerWords: [])) {
            VoiceWakeWordsSettingsFeature(
                preferences: Self.preferencesClient(defaultTriggerWords: ["openclaw", "computer"]))
        }

        await store.send(.appeared) {
            $0.triggerWords = ["openclaw", "computer"]
            $0.syncSnapshot = ["openclaw", "computer"]
            $0.syncRequestID = 1
        }
    }

    @Test @MainActor func `reducer commits when focus leaves edited word`() async {
        let store = TestStore(initialState: VoiceWakeWordsSettingsFeature.State(triggerWords: ["openclaw"])) {
            VoiceWakeWordsSettingsFeature(preferences: Self.preferencesClient())
        }

        await store.send(.focusedTriggerIndexChanged(0)) {
            $0.focusedTriggerIndex = 0
        }
        await store.send(.triggerWordChanged(index: 0, value: " openclaw ")) {
            $0.triggerWords = [" openclaw "]
        }
        await store.send(.focusedTriggerIndexChanged(nil)) {
            $0.focusedTriggerIndex = nil
            $0.syncRequestID = 1
        }
    }

    @Test @MainActor func `reducer refreshes from external preference changes`() async {
        let store = TestStore(initialState: VoiceWakeWordsSettingsFeature.State(triggerWords: ["computer"])) {
            VoiceWakeWordsSettingsFeature(preferences: Self.preferencesClient(loadedWords: [" openclaw "]))
        }

        await store.send(.externalPreferencesChanged) {
            $0.triggerWords = [" openclaw "]
            $0.syncSnapshot = ["openclaw"]
        }
    }

    private static func preferencesClient(
        defaultTriggerWords: [String] = ["openclaw"],
        loadedWords: [String] = ["openclaw"],
        save: @escaping @Sendable ([String]) -> Void = { _ in })
        -> VoiceWakeWordsPreferencesClient
    {
        VoiceWakeWordsPreferencesClient(
            defaultTriggerWords: { defaultTriggerWords },
            load: { loadedWords },
            save: save,
            sanitize: { VoiceWakePreferences.sanitizeTriggerWords($0) })
    }
}
