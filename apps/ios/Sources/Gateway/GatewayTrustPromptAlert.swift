import ComposableArchitecture
import SwiftUI

struct GatewayTrustPromptClient {
    var acceptPendingTrustPrompt: @Sendable @MainActor () async -> Void
    var declinePendingTrustPrompt: @Sendable @MainActor () async -> Void
}

extension GatewayTrustPromptClient: DependencyKey {
    static let liveValue = GatewayTrustPromptClient(
        acceptPendingTrustPrompt: {},
        declinePendingTrustPrompt: {})

    static let testValue = GatewayTrustPromptClient(
        acceptPendingTrustPrompt: {},
        declinePendingTrustPrompt: {})

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        GatewayTrustPromptClient(
            acceptPendingTrustPrompt: {
                await gatewayController.acceptPendingTrustPrompt()
            },
            declinePendingTrustPrompt: {
                gatewayController.declinePendingTrustPrompt()
            })
    }
}

extension DependencyValues {
    var gatewayTrustPrompt: GatewayTrustPromptClient {
        get { self[GatewayTrustPromptClient.self] }
        set { self[GatewayTrustPromptClient.self] = newValue }
    }
}

@Reducer
struct GatewayTrustPromptFeature {
    private let clientOverride: GatewayTrustPromptClient?

    init(client: GatewayTrustPromptClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case cancelButtonTapped
        case trustAndConnectButtonTapped
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.gatewayTrustPrompt) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case .cancelButtonTapped:
                return .run { _ in
                    await client.declinePendingTrustPrompt()
                }

            case .trustAndConnectButtonTapped:
                return .run { _ in
                    await client.acceptPendingTrustPrompt()
                }
            }
        }
        .autoLogActions()
    }
}

struct GatewayTrustPromptAlert: ViewModifier {
    @Environment(GatewayConnectionController.self) private var gatewayController: GatewayConnectionController
    private let storeOverride: StoreOf<GatewayTrustPromptFeature>?

    init(store: StoreOf<GatewayTrustPromptFeature>? = nil) {
        self.storeOverride = store
    }

    func body(content: Content) -> some View {
        let store = self.storeOverride ?? Store(initialState: GatewayTrustPromptFeature.State()) {
            GatewayTrustPromptFeature(client: .live(gatewayController: self.gatewayController))
        }

        content.alert(
            "Trust this gateway?",
            isPresented: Binding(
                get: { self.gatewayController.pendingTrustPrompt != nil },
                set: { _ in
                    // Keep pending trust state until explicit user action.
                    // SwiftUI may set presentation bindings during dismissal; clearing here can
                    // race with the trust button and make accept no-op.
                }),
            presenting: self.gatewayController.pendingTrustPrompt)
        { _ in
            Button("Cancel", role: .cancel) {
                store.send(.cancelButtonTapped)
            }
            Button("Trust and connect") {
                store.send(.trustAndConnectButtonTapped)
            }
        } message: { prompt in
            Text(String(
                format: NSLocalizedString(
                    "First-time TLS connection.\n\nVerify this SHA-256 fingerprint out-of-band before trusting:\n%@",
                    comment: "Gateway certificate trust instructions"),
                prompt.fingerprintSha256))
        }
    }
}

extension View {
    func gatewayTrustPromptAlert(
        store: StoreOf<GatewayTrustPromptFeature>? = nil) -> some View
    {
        self.modifier(GatewayTrustPromptAlert(store: store))
    }
}
