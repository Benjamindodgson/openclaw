import Combine
import ComposableArchitecture
import SwiftUI

struct VoiceWakeWordsPreferencesClient {
    var defaultTriggerWords: @Sendable () -> [String]
    var load: @Sendable () -> [String]
    var save: @Sendable ([String]) -> Void
    var sanitize: @Sendable ([String]) -> [String]
}

struct VoiceWakeWordsGatewayClient {
    var waitBeforeSync: @Sendable () async throws -> Void
    var setGlobalWakeWords: @Sendable @MainActor ([String]) async -> Void
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
                await appModel.setGlobalWakeWords(words)
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
        var triggerWords: [String]
        var focusedTriggerIndex: Int?

        init(triggerWords: [String]) {
            self.triggerWords = triggerWords
            self.focusedTriggerIndex = nil
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
            @Dependency(\.voiceWakeWordsGateway) var dependencyGateway
            let preferences = self.preferencesOverride ?? dependencyPreferences
            let gateway = self.gatewayOverride ?? dependencyGateway

            switch action {
            case .appeared:
                guard state.triggerWords.isEmpty else { return .none }
                state.triggerWords = preferences.defaultTriggerWords()
                return self.commit(&state, preferences: preferences, gateway: gateway)

            case .addWordButtonTapped:
                state.triggerWords.append("")
                return .none

            case let .removeWords(offsets):
                state.triggerWords.remove(atOffsets: offsets)
                if state.triggerWords.isEmpty {
                    state.triggerWords = preferences.defaultTriggerWords()
                }
                return self.commit(&state, preferences: preferences, gateway: gateway)

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
                return shouldCommit ? self.commit(&state, preferences: preferences, gateway: gateway) : .none

            case .commitTriggerWords:
                return self.commit(&state, preferences: preferences, gateway: gateway)

            case .externalPreferencesChanged:
                let updated = preferences.load()
                guard updated != state.triggerWords else { return .none }
                state.triggerWords = updated
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
        let words = state.triggerWords
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
}
