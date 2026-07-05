import ComposableArchitecture
import OpenClawKit
import SwiftUI

struct GatewayQuickSetupConnectFailure: Equatable {
    var message: String
}

struct GatewayQuickSetupClient {
    var connect: @Sendable @MainActor (GatewayDiscoveryModel.DiscoveredGateway) async
        -> GatewayQuickSetupConnectFailure?
    var trustRotatedGatewayCertificate: @Sendable @MainActor (GatewayConnectionProblem) async -> Bool
    var openProtocolMismatchHelpIfNeeded: @Sendable @MainActor (GatewayConnectionProblem) -> Bool
}

extension GatewayQuickSetupClient: DependencyKey {
    static let liveValue = GatewayQuickSetupClient(
        connect: { _ in nil },
        trustRotatedGatewayCertificate: { _ in false },
        openProtocolMismatchHelpIfNeeded: { GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded($0) })

    static let testValue = GatewayQuickSetupClient(
        connect: { _ in nil },
        trustRotatedGatewayCertificate: { _ in false },
        openProtocolMismatchHelpIfNeeded: { _ in false })

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        GatewayQuickSetupClient(
            connect: { candidate in
                let result = await gatewayController.connectWithDiagnostics(candidate)
                return result.failure.map { .init(message: $0.message) }
            },
            trustRotatedGatewayCertificate: { problem in
                await gatewayController.trustRotatedGatewayCertificate(from: problem)
            },
            openProtocolMismatchHelpIfNeeded: { problem in
                GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem)
            })
    }
}

extension DependencyValues {
    var gatewayQuickSetup: GatewayQuickSetupClient {
        get { self[GatewayQuickSetupClient.self] }
        set { self[GatewayQuickSetupClient.self] = newValue }
    }
}

@Reducer
struct GatewayQuickSetupFeature {
    private let clientOverride: GatewayQuickSetupClient?

    init(client: GatewayQuickSetupClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var connecting = false
        var connectError: String?
        var showGatewayProblemDetails = false
    }

    enum Action: Equatable, Sendable {
        struct ConnectRequest: Equatable, Sendable {
            var candidate: GatewayDiscoveryModel.DiscoveredGateway
        }

        struct ConnectResponse: Equatable, Sendable { var failure: GatewayQuickSetupConnectFailure? }

        struct GatewayProblemPrimaryAction: Equatable, Sendable {
            var problem: GatewayConnectionProblem
            var candidate: GatewayDiscoveryModel.DiscoveredGateway?
        }

        case connectButtonTapped(ConnectRequest)
        case connectResponse(ConnectResponse)
        case gatewayProblemDetailsButtonTapped
        case gatewayProblemDetailsDismissed
        case gatewayProblemPrimaryActionTapped(GatewayProblemPrimaryAction)
    }

    // swiftformat:enable redundantSendable

    private enum CancelID { case connect }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.gatewayQuickSetup) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .connectButtonTapped(request):
                return self.connect(candidate: request.candidate, state: &state, client: client)

            case let .connectResponse(response):
                state.connecting = false
                state.connectError = response.failure?.message
                return .none

            case .gatewayProblemDetailsButtonTapped:
                state.showGatewayProblemDetails = true
                return .none

            case .gatewayProblemDetailsDismissed:
                state.showGatewayProblemDetails = false
                return .none

            case let .gatewayProblemPrimaryActionTapped(action):
                if action.problem.canTrustRotatedCertificate {
                    return .run { _ in
                        _ = await client.trustRotatedGatewayCertificate(action.problem)
                    }
                }
                if action.problem.kind == .protocolMismatch {
                    return .run { _ in
                        _ = await client.openProtocolMismatchHelpIfNeeded(action.problem)
                    }
                }
                guard action.problem.retryable, let candidate = action.candidate else { return .none }
                return self.connect(candidate: candidate, state: &state, client: client)
            }
        }
        .autoLogActions()
    }

    private func connect(
        candidate: GatewayDiscoveryModel.DiscoveredGateway,
        state: inout State,
        client: GatewayQuickSetupClient) -> Effect<Action>
    {
        state.connectError = nil
        state.connecting = true
        return .run { send in
            let failure = await client.connect(candidate)
            await send(.connectResponse(.init(failure: failure)))
        }
        .cancellable(id: CancelID.connect, cancelInFlight: true)
    }
}

struct GatewayQuickSetupSheet: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(GatewayConnectionController.self) private var gatewayController
    @Environment(\.dismiss) private var dismiss

    @AppStorage("onboarding.quickSetupDismissed") private var quickSetupDismissed: Bool = false
    @State private var store: StoreOf<GatewayQuickSetupFeature>

    init(store: StoreOf<GatewayQuickSetupFeature> = Store(
        initialState: GatewayQuickSetupFeature.State())
    {
        GatewayQuickSetupFeature()
    }) {
        self._store = SwiftUI.State(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect to a Gateway?")
                    .font(.title2.bold())

                if let gatewayProblem = self.appModel.lastGatewayProblem {
                    GatewayProblemBanner(
                        problem: gatewayProblem,
                        primaryActionTitle: self.gatewayProblemPrimaryActionTitle(gatewayProblem),
                        onPrimaryAction: {
                            self.store.send(.gatewayProblemPrimaryActionTapped(.init(
                                problem: gatewayProblem,
                                candidate: self.bestCandidate)))
                        },
                        onShowDetails: {
                            self.store.send(.gatewayProblemDetailsButtonTapped)
                        })
                }

                if let candidate = self.bestCandidate {
                    GatewayQuickSetupCandidatePanel(
                        name: candidate.name,
                        debugID: candidate.debugID,
                        discoveryStatusText: self.gatewayController.discoveryStatusText,
                        gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText,
                        nodeStatusText: self.appModel.nodeStatusText,
                        operatorStatusText: self.appModel.operatorStatusText)

                    Button {
                        self.store.send(.connectButtonTapped(.init(candidate: candidate)))
                    } label: {
                        Group {
                            if self.store.connecting {
                                HStack(spacing: 8) {
                                    ProgressView().progressViewStyle(.circular)
                                    Text("Connecting…")
                                }
                            } else {
                                Text("Connect")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(self.store.connecting)

                    if let connectError = self.store.connectError {
                        Text(connectError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Button {
                        self.dismiss()
                    } label: {
                        Text("Not now")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(self.store.connecting)

                    self.fullRowToggle("Don’t show this again", isOn: self.$quickSetupDismissed)
                        .padding(.top, 4)
                } else {
                    Text("No gateways found yet. Make sure your gateway is running and Bonjour discovery is enabled.")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Quick Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.quickSetupDismissed = true
                        self.dismiss()
                    } label: {
                        Text("Close")
                    }
                }
            }
        }
        .sheet(isPresented: self.gatewayProblemDetailsBinding) {
            if let gatewayProblem = self.appModel.lastGatewayProblem {
                GatewayProblemDetailsSheet(
                    problem: gatewayProblem,
                    primaryActionTitle: self.gatewayProblemPrimaryActionTitle(gatewayProblem),
                    onPrimaryAction: {
                        self.store.send(.gatewayProblemPrimaryActionTapped(.init(
                            problem: gatewayProblem,
                            candidate: self.bestCandidate)))
                    })
            }
        }
    }

    private var bestCandidate: GatewayDiscoveryModel.DiscoveredGateway? {
        // Prefer whatever discovery says is first; the list is already name-sorted.
        self.gatewayController.gateways.first
    }

    private func fullRowToggle(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .contentShape(Rectangle())
            .overlay {
                // Keep Toggle semantics for accessibility while making the full visual row tappable.
                Button {
                    isOn.wrappedValue.toggle()
                } label: {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
    }

    private func gatewayProblemPrimaryActionTitle(_ problem: GatewayConnectionProblem) -> String? {
        GatewayProblemPrimaryAction.title(for: problem, retryTitle: "Connect")
    }

    private var gatewayProblemDetailsBinding: Binding<Bool> {
        Binding(
            get: { self.store.showGatewayProblemDetails },
            set: { isPresented in
                if isPresented {
                    self.store.send(.gatewayProblemDetailsButtonTapped)
                } else {
                    self.store.send(.gatewayProblemDetailsDismissed)
                }
            })
    }
}

private struct GatewayQuickSetupCandidatePanel: View {
    private static let readableMonospaceWidth: CGFloat = 72 * 8

    let name: String
    let debugID: String
    let discoveryStatusText: String
    let gatewayDisplayStatusText: String
    let nodeStatusText: String
    let operatorStatusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: self.name)
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(.primary)
            Text(verbatim: self.debugID)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                // Use verbatim strings so Bonjour-provided values can't be interpreted as
                // localized format strings (which can crash with Objective-C exceptions).
                Text(verbatim: "Discovery: \(self.discoveryStatusText)")
                Text(verbatim: "Status: \(self.gatewayDisplayStatusText)")
                Text(verbatim: "Node: \(self.nodeStatusText)")
                Text(verbatim: "Operator: \(self.operatorStatusText)")
            }
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: Self.readableMonospaceWidth, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
