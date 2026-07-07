import Combine
import ComposableArchitecture
import SwiftUI

// swiftformat:disable redundantSendable
struct VoiceWakeWords: Equatable, Sendable {
    var values: [String]
}

struct VoiceWakeTriggerIndex: Equatable, Sendable {
    var value: Int
}

struct VoiceWakeTriggerWord: Equatable, Sendable {
    var value: String
}

// swiftformat:enable redundantSendable

struct VoiceWakeWordsPreferencesClient {
    var defaultTriggerWords: @Sendable () -> VoiceWakeWords
    var load: @Sendable () -> VoiceWakeWords
    var save: @Sendable (VoiceWakeWords) -> Void
    var sanitize: @Sendable (VoiceWakeWords) -> VoiceWakeWords
}

struct VoiceWakeWordsGatewayClient {
    var waitBeforeSync: @Sendable () async throws -> Void
    var setGlobalWakeWords: @Sendable @MainActor (VoiceWakeWords) async -> Void
}

extension VoiceWakeWordsPreferencesClient: DependencyKey {
    static let liveValue = VoiceWakeWordsPreferencesClient(
        defaultTriggerWords: { .init(values: VoiceWakePreferences.defaultTriggerWords) },
        load: { .init(values: VoiceWakePreferences.loadTriggerWords()) },
        save: { VoiceWakePreferences.saveTriggerWords($0.values) },
        sanitize: { .init(values: VoiceWakePreferences.sanitizeTriggerWords($0.values)) })

    static let testValue = VoiceWakeWordsPreferencesClient(
        defaultTriggerWords: { .init(values: VoiceWakePreferences.defaultTriggerWords) },
        load: { .init(values: VoiceWakePreferences.defaultTriggerWords) },
        save: { _ in },
        sanitize: { .init(values: VoiceWakePreferences.sanitizeTriggerWords($0.values)) })
}

extension VoiceWakeWordsGatewayClient: DependencyKey {
    static let liveValue = VoiceWakeWordsGatewayClient(
        waitBeforeSync: {
            try await Task.sleep(nanoseconds: 650_000_000)
        },
        setGlobalWakeWords: { _ in })
    static let testValue = VoiceWakeWordsGatewayClient(
        waitBeforeSync: {},
        setGlobalWakeWords: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        VoiceWakeWordsGatewayClient(
            waitBeforeSync: {
                try await Task.sleep(nanoseconds: 650_000_000)
            },
            setGlobalWakeWords: { words in
                await appModel.setGlobalWakeWords(words.values)
            })
    }
}

extension DependencyValues {
    var voiceWakeWordsPreferences: VoiceWakeWordsPreferencesClient {
        get { self[VoiceWakeWordsPreferencesClient.self] }
        set { self[VoiceWakeWordsPreferencesClient.self] = newValue }
    }

    var voiceWakeWordsGateway: VoiceWakeWordsGatewayClient {
        get { self[VoiceWakeWordsGatewayClient.self] }
        set { self[VoiceWakeWordsGatewayClient.self] = newValue }
    }
}

@Reducer
struct VoiceWakeWordsSettingsFeature {
    private let preferencesOverride: VoiceWakeWordsPreferencesClient?
    private let gatewayOverride: VoiceWakeWordsGatewayClient?

    init(
        preferences: VoiceWakeWordsPreferencesClient? = nil,
        gateway: VoiceWakeWordsGatewayClient? = nil)
    {
        self.preferencesOverride = preferences
        self.gatewayOverride = gateway
    }

    private enum CancelID { case gatewaySync }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var words: VoiceWakeWords
        var focusedTriggerIndex: VoiceWakeTriggerIndex?

        init(triggerWords: [String]) {
            self.words = VoiceWakeWords(values: triggerWords)
            self.focusedTriggerIndex = nil
        }

        var triggerWords: [String] {
            self.words.values
        }

        var canAddWord: Bool {
            !self.words.values
                .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    enum Action: Equatable, Sendable {
        struct TriggerWordChange: Equatable, Sendable {
            var index: VoiceWakeTriggerIndex
            var word: VoiceWakeTriggerWord
        }

        struct FocusedTriggerIndexChange: Equatable, Sendable {
            var index: VoiceWakeTriggerIndex?
        }

        struct WordRemoval: Equatable, Sendable {
            var offsets: IndexSet
        }

        case appeared
        case addWordButtonTapped
        case removeWords(WordRemoval)
        case triggerWordChanged(TriggerWordChange)
        case resetDefaultsButtonTapped
        case focusedTriggerIndexChanged(FocusedTriggerIndexChange)
        case commitTriggerWords
        case externalPreferencesChanged
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.voiceWakeWordsPreferences) var dependencyPreferences
            @Dependency(\.voiceWakeWordsGateway) var dependencyGateway
            let preferences = self.preferencesOverride ?? dependencyPreferences
            let gateway = self.gatewayOverride ?? dependencyGateway

            switch action {
            case .appeared:
                guard state.words.values.isEmpty else { return .none }
                state.words = preferences.defaultTriggerWords()
                return self.commit(&state, preferences: preferences, gateway: gateway)

            case .addWordButtonTapped:
                state.words.values.append("")
                return .none

            case let .removeWords(removal):
                state.words.values.remove(atOffsets: removal.offsets)
                if state.words.values.isEmpty {
                    state.words = preferences.defaultTriggerWords()
                }
                return self.commit(&state, preferences: preferences, gateway: gateway)

            case let .triggerWordChanged(change):
                guard state.words.values.indices.contains(change.index.value) else { return .none }
                state.words.values[change.index.value] = change.word.value
                return .none

            case .resetDefaultsButtonTapped:
                state.words = preferences.defaultTriggerWords()
                return .none

            case let .focusedTriggerIndexChanged(change):
                let shouldCommit = state.focusedTriggerIndex != nil && state.focusedTriggerIndex != change.index
                state.focusedTriggerIndex = change.index
                return shouldCommit ? self.commit(&state, preferences: preferences, gateway: gateway) : .none

            case .commitTriggerWords:
                return self.commit(&state, preferences: preferences, gateway: gateway)

            case .externalPreferencesChanged:
                let updated = preferences.load()
                guard updated != state.words else { return .none }
                state.words = updated
                return .none
            }
        }
        .autoLogActions()
    }

    private func commit(
        _ state: inout State,
        preferences: VoiceWakeWordsPreferencesClient,
        gateway: VoiceWakeWordsGatewayClient) -> Effect<Action>
    {
        let words = state.words
        let snapshot = preferences.sanitize(words)
        return .merge(
            .run { _ in
                preferences.save(words)
            },
            .run { _ in
                try await gateway.waitBeforeSync()
                await gateway.setGlobalWakeWords(snapshot)
            }
            .cancellable(id: CancelID.gatewaySync, cancelInFlight: true))
    }
}

enum VoiceWakeWordsSettingsStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<VoiceWakeWordsSettingsFeature> {
        Store(
            initialState: VoiceWakeWordsSettingsFeature.State(
                triggerWords: VoiceWakePreferences.loadTriggerWords()))
        {
            VoiceWakeWordsSettingsFeature(gateway: .live(appModel: appModel))
        }
    }
}

struct VoiceWakeWordsSettingsView: View {
    @State private var store: StoreOf<VoiceWakeWordsSettingsFeature>
    @FocusState private var focusedTriggerIndex: Int?

    init(store: StoreOf<VoiceWakeWordsSettingsFeature> = Store(
        initialState: VoiceWakeWordsSettingsFeature.State(
            triggerWords: VoiceWakePreferences.loadTriggerWords()))
    {
        VoiceWakeWordsSettingsFeature()
    }) {
        self._store = SwiftUI.State(wrappedValue: store)
    }

    var body: some View {
        Form {
            Section {
                ForEach(self.store.triggerWords.indices, id: \.self) { index in
                    TextField("Wake word", text: self.binding(for: index))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused(self.$focusedTriggerIndex, equals: index)
                        .onSubmit {
                            self.store.send(.commitTriggerWords)
                        }
                }
                .onDelete { offsets in
                    self.store.send(.removeWords(.init(offsets: offsets)))
                }

                Button {
                    self.store.send(.addWordButtonTapped)
                } label: {
                    Label("Add word", systemImage: "plus")
                }
                .disabled(!self.store.canAddWord)

                Button("Reset defaults") {
                    self.store.send(.resetDefaultsButtonTapped)
                }
            } header: {
                Text("Wake Words")
            } footer: {
                Text(
                    "OpenClaw reacts when any trigger appears in a transcription. "
                        + "Keep them short to avoid false positives.")
            }
        }
        .navigationTitle("Wake Words")
        .toolbar { EditButton() }
        .onAppear {
            self.store.send(.appeared)
        }
        .onChange(of: self.focusedTriggerIndex) { _, newValue in
            self.store.send(.focusedTriggerIndexChanged(.init(
                index: newValue.map { VoiceWakeTriggerIndex(value: $0) })))
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            guard self.focusedTriggerIndex == nil else { return }
            self.store.send(.externalPreferencesChanged)
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                guard self.store.triggerWords.indices.contains(index) else { return "" }
                return self.store.triggerWords[index]
            },
            set: { newValue in
                self.store.send(.triggerWordChanged(.init(
                    index: .init(value: index),
                    word: .init(value: newValue))))
            })
    }
}
