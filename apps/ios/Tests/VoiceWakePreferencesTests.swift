import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

struct VoiceWakePreferencesTests {
    @Test func `sanitize trigger words trims and drops empty`() {
        #expect(VoiceWakePreferences.sanitizeTriggerWords([" openclaw ", "", " \nclaude\t"]) == ["openclaw", "claude"])
    }

    @Test func `sanitize trigger words falls back to defaults when empty`() {
        #expect(VoiceWakePreferences.sanitizeTriggerWords(["", "  "]) == VoiceWakePreferences.defaultTriggerWords)
    }

    @Test func `sanitize trigger words limits word length`() {
        let long = String(repeating: "x", count: VoiceWakePreferences.maxWordLength + 5)
        let cleaned = VoiceWakePreferences.sanitizeTriggerWords(["ok", long])
        #expect(cleaned[1].count == VoiceWakePreferences.maxWordLength)
    }

    @Test func `sanitize trigger words limits word count`() {
        let words = (1...VoiceWakePreferences.maxWords + 3).map { "w\($0)" }
        let cleaned = VoiceWakePreferences.sanitizeTriggerWords(words)
        #expect(cleaned.count == VoiceWakePreferences.maxWords)
    }

    @Test func `display string uses sanitized words`() {
        #expect(VoiceWakePreferences.displayString(for: ["", " "]) == "openclaw, claude")
    }

    @Test func `load and save trigger words round trip`() throws {
        let suiteName = "VoiceWakePreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))

        #expect(VoiceWakePreferences.loadTriggerWords(defaults: defaults) == VoiceWakePreferences.defaultTriggerWords)
        VoiceWakePreferences.saveTriggerWords(["computer"], defaults: defaults)
        #expect(VoiceWakePreferences.loadTriggerWords(defaults: defaults) == ["computer"])
    }

    @Test @MainActor func `reducer commit publishes sanitized words to gateway`() async {
        let gatewayProbe = VoiceWakeWordsGatewayProbe()
        let store: TestStoreOf<VoiceWakeWordsSettingsFeature> = TestStore(initialState: VoiceWakeWordsSettingsFeature
            .State(
                triggerWords: [" openclaw ", "", "claude"]))
        {
            VoiceWakeWordsSettingsFeature(
                preferences: Self.preferencesClient(),
                gateway: gatewayProbe.client())
        }

        await store.send(.commitTriggerWords)
        await store.finish()

        #expect(await gatewayProbe.values() == [["openclaw", "claude"]])
    }

    @Test @MainActor func `reducer restores defaults when appearing with empty words`() async {
        let gatewayProbe = VoiceWakeWordsGatewayProbe()
        let store: TestStoreOf<VoiceWakeWordsSettingsFeature> = TestStore(
            initialState: VoiceWakeWordsSettingsFeature.State(triggerWords: []))
        {
            VoiceWakeWordsSettingsFeature(
                preferences: Self.preferencesClient(defaultTriggerWords: ["openclaw", "computer"]),
                gateway: gatewayProbe.client())
        }

        await store.send(.appeared) {
            $0.triggerWords = ["openclaw", "computer"]
        }
        await store.finish()

        #expect(await gatewayProbe.values() == [["openclaw", "computer"]])
    }

    @Test @MainActor func `reducer commits when focus leaves edited word`() async {
        let gatewayProbe = VoiceWakeWordsGatewayProbe()
        let store: TestStoreOf<VoiceWakeWordsSettingsFeature> = TestStore(
            initialState: VoiceWakeWordsSettingsFeature.State(triggerWords: ["openclaw"]))
        {
            VoiceWakeWordsSettingsFeature(
                preferences: Self.preferencesClient(),
                gateway: gatewayProbe.client())
        }

        await store.send(.focusedTriggerIndexChanged(0)) {
            $0.focusedTriggerIndex = 0
        }
        await store.send(.triggerWordChanged(.init(index: 0, value: " openclaw "))) {
            $0.triggerWords = [" openclaw "]
        }
        await store.send(.focusedTriggerIndexChanged(nil)) {
            $0.focusedTriggerIndex = nil
        }
        await store.finish()

        #expect(await gatewayProbe.values() == [["openclaw"]])
    }

    @Test @MainActor func `reducer cancels pending gateway sync when words are recommitted`() async {
        let gatewayProbe = VoiceWakeWordsGatewayProbe()
        let store: TestStoreOf<VoiceWakeWordsSettingsFeature> = TestStore(
            initialState: VoiceWakeWordsSettingsFeature.State(triggerWords: ["openclaw"]))
        {
            VoiceWakeWordsSettingsFeature(
                preferences: Self.preferencesClient(),
                gateway: gatewayProbe.client(delayNanoseconds: 50_000_000))
        }

        await store.send(.commitTriggerWords)
        await store.send(.triggerWordChanged(.init(index: 0, value: " claude "))) {
            $0.triggerWords = [" claude "]
        }
        await store.send(.commitTriggerWords)
        await store.finish()

        #expect(await gatewayProbe.values() == [["claude"]])
    }

    @Test @MainActor func `reducer refreshes from external preference changes`() async {
        let store: TestStoreOf<VoiceWakeWordsSettingsFeature> = TestStore(
            initialState: VoiceWakeWordsSettingsFeature.State(triggerWords: ["computer"]))
        {
            VoiceWakeWordsSettingsFeature(preferences: Self.preferencesClient(loadedWords: [" openclaw "]))
        }

        await store.send(.externalPreferencesChanged) {
            $0.triggerWords = [" openclaw "]
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

private actor VoiceWakeWordsGatewayProbe {
    private var syncedWords: [[String]] = []

    nonisolated func client(delayNanoseconds: UInt64? = nil) -> VoiceWakeWordsGatewayClient {
        VoiceWakeWordsGatewayClient(
            waitBeforeSync: {
                if let delayNanoseconds {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                }
            },
            setGlobalWakeWords: { words in await self.record(words) })
    }

    func values() -> [[String]] {
        self.syncedWords
    }

    private func record(_ words: [String]) {
        self.syncedWords.append(words)
    }
}
