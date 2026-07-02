import Combine
import ComposableArchitecture
import SwiftUI

struct VoiceWakeWordsPreferencesClient {
    var defaultTriggerWords: @Sendable () -> [String]
    var load: @Sendable () -> [String]
    var save: @Sendable ([String]) -> Void
    var sanitize: @Sendable ([String]) -> [String]
}

extension VoiceWakeWordsPreferencesClient: DependencyKey {
    static let liveValue = VoiceWakeWordsPreferencesClient(
        defaultTriggerWords: { VoiceWakePreferences.defaultTriggerWords },
        load: { VoiceWakePreferences.loadTriggerWords() },
        save: { VoiceWakePreferences.saveTriggerWords($0) },
        sanitize: { VoiceWakePreferences.sanitizeTriggerWords($0) })

    static let testValue = VoiceWakeWordsPreferencesClient(
        defaultTriggerWords: { VoiceWakePreferences.defaultTriggerWords },
        load: { VoiceWakePreferences.defaultTriggerWords },
        save: { _ in },
        sanitize: { VoiceWakePreferences.sanitizeTriggerWords($0) })
}

extension DependencyValues {
    var voiceWakeWordsPreferences: VoiceWakeWordsPreferencesClient {
        get { self[VoiceWakeWordsPreferencesClient.self] }
        set { self[VoiceWakeWordsPreferencesClient.self] = newValue }
    }
}

@Reducer
struct VoiceWakeWordsSettingsFeature {
    private let preferencesOverride: VoiceWakeWordsPreferencesClient?

    init(preferences: VoiceWakeWordsPreferencesClient? = nil) {
        self.preferencesOverride = preferences
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var triggerWords: [String]
        var focusedTriggerIndex: Int?
        var syncSnapshot: [String]
        var syncRequestID: Int

        init(triggerWords: [String]) {
            self.triggerWords = triggerWords
            self.focusedTriggerIndex = nil
            self.syncSnapshot = VoiceWakePreferences.sanitizeTriggerWords(triggerWords)
            self.syncRequestID = 0
        }

        var canAddWord: Bool {
            !self.triggerWords
                .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    enum Action: Equatable, Sendable {
        case appeared
        case addWordButtonTapped
        case removeWords(IndexSet)
        case triggerWordChanged(index: Int, value: String)
        case resetDefaultsButtonTapped
        case focusedTriggerIndexChanged(Int?)
        case commitTriggerWords
        case externalPreferencesChanged
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.voiceWakeWordsPreferences) var dependencyPreferences
            let preferences = self.preferencesOverride ?? dependencyPreferences

            switch action {
            case .appeared:
                guard state.triggerWords.isEmpty else { return .none }
                state.triggerWords = preferences.defaultTriggerWords()
                return self.commit(&state, preferences: preferences)

            case .addWordButtonTapped:
                state.triggerWords.append("")
                return .none

            case let .removeWords(offsets):
                state.triggerWords.remove(atOffsets: offsets)
                if state.triggerWords.isEmpty {
                    state.triggerWords = preferences.defaultTriggerWords()
                }
                return self.commit(&state, preferences: preferences)

            case let .triggerWordChanged(index, value):
                guard state.triggerWords.indices.contains(index) else { return .none }
                state.triggerWords[index] = value
                return .none

            case .resetDefaultsButtonTapped:
                state.triggerWords = preferences.defaultTriggerWords()
                return .none

            case let .focusedTriggerIndexChanged(index):
                let shouldCommit = state.focusedTriggerIndex != nil && state.focusedTriggerIndex != index
                state.focusedTriggerIndex = index
                return shouldCommit ? self.commit(&state, preferences: preferences) : .none

            case .commitTriggerWords:
                return self.commit(&state, preferences: preferences)

            case .externalPreferencesChanged:
                let updated = preferences.load()
                guard updated != state.triggerWords else { return .none }
                state.triggerWords = updated
                state.syncSnapshot = preferences.sanitize(updated)
                return .none
            }
        }
        .autoLogActions()
    }

    private func commit(_ state: inout State, preferences: VoiceWakeWordsPreferencesClient) -> Effect<Action> {
        let words = state.triggerWords
        let snapshot = preferences.sanitize(words)
        state.syncSnapshot = snapshot
        state.syncRequestID += 1
        return .run { _ in
            preferences.save(words)
        }
    }
}

struct VoiceWakeWordsSettingsView: View {
    @Environment(NodeAppModel.self) private var appModel
    let store: StoreOf<VoiceWakeWordsSettingsFeature>
    @FocusState private var focusedTriggerIndex: Int?
    @State private var syncTask: Task<Void, Never>?

    init(store: StoreOf<VoiceWakeWordsSettingsFeature> = Store(
        initialState: VoiceWakeWordsSettingsFeature.State(
            triggerWords: VoiceWakePreferences.loadTriggerWords()))
    {
        VoiceWakeWordsSettingsFeature()
    }) {
        self.store = store
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
                    self.store.send(.removeWords(offsets))
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
            self.store.send(.focusedTriggerIndexChanged(newValue))
        }
        .onChange(of: self.store.syncRequestID) { _, _ in
            self.scheduleGatewaySync(words: self.store.syncSnapshot)
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
                self.store.send(.triggerWordChanged(index: index, value: newValue))
            })
    }

    private func scheduleGatewaySync(words: [String]) {
        self.syncTask?.cancel()
        self.syncTask = Task { [words, weak appModel = self.appModel] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            await appModel?.setGlobalWakeWords(words)
        }
    }
}
