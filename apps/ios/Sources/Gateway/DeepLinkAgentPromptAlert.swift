import ComposableArchitecture
import SwiftUI

struct DeepLinkAgentPromptClient {
    var approvePendingAgentDeepLinkPrompt: @Sendable @MainActor () async -> Void
    var declinePendingAgentDeepLinkPrompt: @Sendable @MainActor () async -> Void
}

extension DeepLinkAgentPromptClient: DependencyKey {
    static let liveValue = DeepLinkAgentPromptClient(
        approvePendingAgentDeepLinkPrompt: {},
        declinePendingAgentDeepLinkPrompt: {})

    static let testValue = DeepLinkAgentPromptClient(
        approvePendingAgentDeepLinkPrompt: {},
        declinePendingAgentDeepLinkPrompt: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        DeepLinkAgentPromptClient(
            approvePendingAgentDeepLinkPrompt: {
                await appModel.approvePendingAgentDeepLinkPrompt()
            },
            declinePendingAgentDeepLinkPrompt: {
                appModel.declinePendingAgentDeepLinkPrompt()
            })
    }
}

extension DependencyValues {
    var deepLinkAgentPrompt: DeepLinkAgentPromptClient {
        get { self[DeepLinkAgentPromptClient.self] }
        set { self[DeepLinkAgentPromptClient.self] = newValue }
    }
}

@Reducer
struct DeepLinkAgentPromptFeature {
    private let clientOverride: DeepLinkAgentPromptClient?

    init(client: DeepLinkAgentPromptClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case cancelButtonTapped
        case runButtonTapped
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.deepLinkAgentPrompt) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case .cancelButtonTapped:
                return .run { _ in
                    await client.declinePendingAgentDeepLinkPrompt()
                }

            case .runButtonTapped:
                return .run { _ in
                    await client.approvePendingAgentDeepLinkPrompt()
                }
            }
        }
        .autoLogActions()
    }
}

struct DeepLinkAgentPromptAlert: ViewModifier {
    @Environment(NodeAppModel.self) private var appModel: NodeAppModel
    @State private var store: StoreOf<DeepLinkAgentPromptFeature>

    init(store: StoreOf<DeepLinkAgentPromptFeature> = Store(
        initialState: DeepLinkAgentPromptFeature.State())
    {
        DeepLinkAgentPromptFeature()
    }) {
        self._store = State(wrappedValue: store)
    }

    private var promptBinding: Binding<NodeAppModel.AgentDeepLinkPrompt?> {
        Binding(
            get: { self.appModel.pendingAgentDeepLinkPrompt },
            set: { _ in
                // Keep prompt state until explicit user action.
            })
    }

    func body(content: Content) -> some View {
        content.alert(item: self.promptBinding) { prompt in
            Alert(
                title: Text("Run OpenClaw agent?"),
                message: Text(
                    """
                    Message:
                    \(prompt.messagePreview)

                    URL:
                    \(prompt.urlPreview)
                    """),
                primaryButton: .cancel(Text("Cancel")) {
                    self.store.send(.cancelButtonTapped)
                },
                secondaryButton: .default(Text("Run")) {
                    self.store.send(.runButtonTapped)
                })
        }
    }
}

extension View {
    func deepLinkAgentPromptAlert(
        store: StoreOf<DeepLinkAgentPromptFeature> = Store(
            initialState: DeepLinkAgentPromptFeature.State())
        {
            DeepLinkAgentPromptFeature()
        }) -> some View
    {
        self.modifier(DeepLinkAgentPromptAlert(store: store))
    }
}
