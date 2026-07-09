import ComposableArchitecture
import Foundation
import OpenClawKit

@Reducer
struct OnboardingSetupCodeFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var applyResult: ApplyResult?
        var gatewayLinkTransitionRequest: GatewayLinkTransitionRequest?
        var scannedGatewayLinkTransitionRequest: ScannedGatewayLinkTransitionRequest?
        var setupCodeState = OnboardingSetupCode(value: "")
        var statusState = OnboardingSetupCodeStatusMessage(value: nil)

        var setupCode: String {
            self.setupCodeState.value
        }

        var status: String? {
            self.statusState.value
        }

        var trimmedSetupCode: String {
            self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canApply: Bool {
            !self.trimmedSetupCode.isEmpty
        }
    }

    struct AppleReviewDemoActivation: Equatable, Sendable {
        var appleReviewDemoAction: OnboardingAppleReviewDemoFeature.Action
        var presentationAction: OnboardingPresentationFeature.Action
        var statusAction: OnboardingStatusFeature.Action
        var connectionFormAction: OnboardingConnectionFormFeature.Action
    }

    struct GatewayLinkTransitionRequest: Equatable, Sendable {
        var statusAction: OnboardingStatusFeature.Action
        var stepAction: OnboardingStepFeature.Action
    }

    struct ScannedGatewayLinkTransitionRequest: Equatable, Sendable {
        var presentationAction: OnboardingPresentationFeature.Action
        var statusAction: OnboardingStatusFeature.Action
        var stepAction: OnboardingStepFeature.Action
    }

    enum ApplyResult: Equatable, Sendable {
        struct AppleReviewDemoSetupCode: Equatable, Sendable {
            var code: OnboardingSetupCode
            var activation: AppleReviewDemoActivation
        }

        case appleReviewDemoSetupCode(AppleReviewDemoSetupCode)
        case gatewayLink(GatewayConnectDeepLink)
    }

    enum Action: Equatable, Sendable {
        struct ScannedGatewayLink: Equatable, Sendable { var link: GatewayConnectDeepLink }
        struct ScannedSetupCode: Equatable, Sendable { var code: OnboardingSetupCode }
        struct SetupCodeChange: Equatable, Sendable { var code: OnboardingSetupCode }

        case appleReviewDemoCodeAccepted
        case applyRequested
        case applyResultHandled
        case applyStarted
        case emptyCodeSubmitted
        case invalidSetupCodeSubmitted
        case scannedGatewayLinkReceived(ScannedGatewayLink)
        case scannedSetupCodeReceived(ScannedSetupCode)
        case setupCodeAccepted
        case setupCodeChanged(SetupCodeChange)
        case statusCleared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appleReviewDemoCodeAccepted:
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                state.setupCodeState = .init(value: "")
                state.statusState = .init(value: "Apple Review demo mode enabled.")
                return .none

            case .applyRequested:
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                state.statusState = .init(value: nil)
                let raw = state.trimmedSetupCode
                guard !raw.isEmpty else {
                    state.statusState = .init(value: "Paste a setup code to continue.")
                    return .none
                }

                if AppleReviewDemoMode.isSetupCode(raw) {
                    state.setupCodeState = .init(value: "")
                    state.statusState = .init(value: "Apple Review demo mode enabled.")
                    state.applyResult = Self.appleReviewDemoSetupCode(raw)
                    return .none
                }

                guard let link = GatewayConnectDeepLink.fromSetupInput(raw) else {
                    state.statusState = .init(value: "Setup code not recognized or uses an insecure ws:// gateway URL.")
                    return .none
                }
                state.setupCodeState = .init(value: "")
                state.statusState = .init(value: "Setup code applied. Connecting...")
                state.applyResult = .gatewayLink(link)
                state.gatewayLinkTransitionRequest = Self.gatewayLinkTransitionRequest(for: link)
                return .none

            case .applyResultHandled:
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                return .none

            case .applyStarted:
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                state.statusState = .init(value: nil)
                return .none

            case .emptyCodeSubmitted:
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                state.statusState = .init(value: "Paste a setup code to continue.")
                return .none

            case .invalidSetupCodeSubmitted:
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                state.statusState = .init(value: "Setup code not recognized or uses an insecure ws:// gateway URL.")
                return .none

            case let .scannedGatewayLinkReceived(scan):
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                state.statusState = .init(value: nil)
                state.applyResult = .gatewayLink(scan.link)
                state.scannedGatewayLinkTransitionRequest = Self.scannedGatewayLinkTransitionRequest(
                    for: scan.link)
                return .none

            case let .scannedSetupCodeReceived(scan):
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                guard AppleReviewDemoMode.isSetupCode(scan.code.value) else {
                    return .none
                }
                state.applyResult = Self.appleReviewDemoSetupCode(scan.code.value)
                return .none

            case .setupCodeAccepted:
                state.applyResult = nil
                state.gatewayLinkTransitionRequest = nil
                state.scannedGatewayLinkTransitionRequest = nil
                state.setupCodeState = .init(value: "")
                state.statusState = .init(value: "Setup code applied. Connecting...")
                return .none

            case let .setupCodeChanged(change):
                state.setupCodeState = change.code
                return .none

            case .statusCleared:
                state.statusState = .init(value: nil)
                return .none
            }
        }
        .autoLogActions()
    }

    private static func appleReviewDemoSetupCode(_ raw: String) -> ApplyResult {
        .appleReviewDemoSetupCode(.init(
            code: .init(value: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
            activation: self.appleReviewDemoActivation()))
    }

    private static func appleReviewDemoActivation() -> AppleReviewDemoActivation {
        .init(
            appleReviewDemoAction: .enableRequested,
            presentationAction: .qrScannerDismissed,
            statusAction: .appleReviewDemoModeEnabled,
            connectionFormAction: .selectedModeChanged(.init(mode: .homeNetwork)))
    }

    private static func gatewayLinkTransitionRequest(
        for link: GatewayConnectDeepLink)
        -> GatewayLinkTransitionRequest
    {
        .init(
            statusAction: .connectionStarted(self.gatewayLinkConnectionStart(for: link)),
            stepAction: .stepChanged(.init(step: .connect)))
    }

    private static func gatewayLinkConnectionStart(
        for link: GatewayConnectDeepLink)
        -> OnboardingStatusFeature.Action.ConnectionStart
    {
        .init(
            id: .init(value: "setup-code"),
            message: .init(value: "Connecting via setup code..."),
            statusLine: .init(value: "Setup code loaded. Connecting to \(link.host):\(link.port)..."),
            clearsIssue: .init(value: false))
    }

    private static func scannedGatewayLinkTransitionRequest(
        for link: GatewayConnectDeepLink)
        -> ScannedGatewayLinkTransitionRequest
    {
        .init(
            presentationAction: .qrScannerDismissed,
            statusAction: .connectionStatusUpdated(.init(
                message: .init(value: "Connecting via QR code..."),
                statusLine: .init(value: "QR loaded. Connecting to \(link.host):\(link.port)..."))),
            stepAction: .stepChanged(.init(step: .connect)))
    }
}

@Reducer
struct OnboardingConnectionFormFeature {
    private let defaultsClientOverride: OnboardingConnectionFormDefaultsClient?
    private let manualConnectionClientOverride: OnboardingManualConnectionClient?

    init(
        defaultsClient: OnboardingConnectionFormDefaultsClient? = nil,
        manualConnectionClient: OnboardingManualConnectionClient? = nil)
    {
        self.defaultsClientOverride = defaultsClient
        self.manualConnectionClientOverride = manualConnectionClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var manualConnectionRequest: ManualConnectionRequest?
        var selectedMode: OnboardingConnectionMode?
        var manualHostState = OnboardingManualHost(value: "")
        var manualPortState = OnboardingManualPort(value: 18789)
        var manualPortTextState = OnboardingManualPortText(value: "18789")
        var manualTLSState = OnboardingManualTLS(value: true)
        var savedGatewayConnection = OnboardingHasSavedGatewayConnection(value: false)

        var manualHost: String {
            self.manualHostState.value
        }

        var manualPort: Int {
            self.manualPortState.value
        }

        var manualPortText: String {
            self.manualPortTextState.value
        }

        var normalizedManualHost: String {
            self.manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var manualTLS: Bool {
            self.manualTLSState.value
        }

        var hasSavedGatewayConnection: Bool {
            self.savedGatewayConnection.value
        }

        var canConnectManual: Bool {
            !self.normalizedManualHost.isEmpty && self.manualPort > 0 && self.manualPort <= 65535
        }

        mutating func syncManualPortText() {
            self.manualPortTextState = .init(value: self.manualPort > 0 ? String(self.manualPort) : "")
        }

        mutating func applyModeDefaults(_ mode: OnboardingConnectionMode) {
            let host = self.normalizedManualHost.lowercased()
            let hostIsDefaultLike = host.isEmpty || host == "openclaw.local" || host == "localhost"

            switch mode {
            case .homeNetwork:
                if hostIsDefaultLike { self.manualHostState = .init(value: "openclaw.local") }
                self.manualTLSState = .init(value: true)
            case .remoteDomain:
                if host == "openclaw.local" || host == "localhost" { self.manualHostState = .init(value: "") }
                self.manualTLSState = .init(value: true)
            case .developerLocal:
                if hostIsDefaultLike { self.manualHostState = .init(value: "localhost") }
                self.manualTLSState = .init(value: false)
            }

            if self.manualPort <= 0 || self.manualPort > 65535 {
                self.manualPortState = .init(value: 18789)
            }
            self.syncManualPortText()
        }
    }

    struct ManualConnectionRequest: Equatable, Sendable {
        var host: OnboardingManualHost
        var port: OnboardingManualPort
        var useTLS: OnboardingManualTLS
        var statusAction: OnboardingStatusFeature.Action
    }

    enum Action: Equatable, Sendable {
        struct ManualConnectionEffectRequest: Equatable, Sendable {
            var request: ManualConnectionRequest
            var authOverride: GatewayConnectionController.ManualAuthOverride?
        }

        struct ManualHostChange: Equatable, Sendable { var host: OnboardingManualHost }
        struct ManualPortTextChange: Equatable, Sendable { var text: OnboardingManualPortText }
        struct ManualTLSChange: Equatable, Sendable { var useTLS: OnboardingManualTLS }
        struct ModeSelection: Equatable, Sendable { var mode: OnboardingConnectionMode }
        struct SelectedModeChange: Equatable, Sendable { var mode: OnboardingConnectionMode? }
        struct GatewayLinkApplication: Equatable, Sendable {
            var host: OnboardingManualHost
            var port: OnboardingManualPort
            var tls: OnboardingManualTLS
        }

        struct Initialization: Equatable, Sendable {
            var host: OnboardingManualHost
            var port: OnboardingManualPort
            var tls: OnboardingManualTLS
            var lastMode: OnboardingConnectionMode?
        }

        case developerModeDisabled
        case gatewayLinkApplied(GatewayLinkApplication)
        case initialConnectionLoadRequested
        case initialized(Initialization)
        case manualConnectionEffectRequested(ManualConnectionEffectRequest)
        case manualConnectionRequested
        case manualConnectionRequestHandled
        case manualHostChanged(ManualHostChange)
        case manualPortTextChanged(ManualPortTextChange)
        case manualTLSChanged(ManualTLSChange)
        case modeSelected(ModeSelection)
        case selectedModeChanged(SelectedModeChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingConnectionFormDefaults) var dependencyDefaultsClient
            @Dependency(\.onboardingManualConnection) var dependencyManualConnectionClient
            let defaultsClient = self.defaultsClientOverride ?? dependencyDefaultsClient
            let manualConnectionClient = self.manualConnectionClientOverride ?? dependencyManualConnectionClient

            switch action {
            case .developerModeDisabled:
                if state.selectedMode == .developerLocal {
                    state.selectedMode = nil
                }
                return .none

            case let .gatewayLinkApplied(application):
                state.manualHostState = application.host
                state.manualPortState = application.port
                state.syncManualPortText()
                state.manualTLSState = application.tls
                if state.selectedMode == nil {
                    state.selectedMode = application.tls.value ? .remoteDomain : .homeNetwork
                }
                return .none

            case .initialConnectionLoadRequested:
                Self.applyInitialization(defaultsClient.loadDefaults(), to: &state)
                return .none

            case let .initialized(initialization):
                Self.applyInitialization(.init(
                    host: initialization.host,
                    port: initialization.port,
                    tls: initialization.tls,
                    lastMode: initialization.lastMode,
                    hasSavedGatewayConnection: state.savedGatewayConnection), to: &state)
                return .none

            case let .manualConnectionEffectRequested(request):
                return .run { [manualConnectionClient] _ in
                    await manualConnectionClient.connect(
                        request.request.host,
                        request.request.port,
                        request.request.useTLS,
                        request.authOverride)
                }

            case .manualConnectionRequested:
                state.manualConnectionRequest = nil
                let host = state.normalizedManualHost
                guard !host.isEmpty, state.manualPort > 0, state.manualPort <= 65535 else {
                    return .none
                }
                let manualHost = OnboardingManualHost(value: host)
                let manualPort = state.manualPortState
                state.manualConnectionRequest = ManualConnectionRequest(
                    host: manualHost,
                    port: manualPort,
                    useTLS: .init(value: state.manualTLS),
                    statusAction: .connectionStarted(Self.manualConnectionStart(host: manualHost, port: manualPort)))
                return .none

            case .manualConnectionRequestHandled:
                state.manualConnectionRequest = nil
                return .none

            case let .manualHostChanged(change):
                state.manualHostState = change.host
                return .none

            case let .manualPortTextChanged(change):
                let digits = change.text.value.filter(\.isNumber)
                guard let parsed = Int(digits), parsed > 0 else {
                    state.manualPortState = .init(value: 0)
                    state.manualPortTextState = .init(value: "")
                    return .none
                }
                state.manualPortState = .init(value: min(parsed, 65535))
                state.syncManualPortText()
                return .none

            case let .manualTLSChanged(change):
                state.manualTLSState = change.useTLS
                return .none

            case let .modeSelected(selection):
                state.selectedMode = selection.mode
                state.applyModeDefaults(selection.mode)
                return .none

            case let .selectedModeChanged(change):
                state.selectedMode = change.mode
                return .none
            }
        }
        .autoLogActions()
    }

    private static func applyInitialization(
        _ initialization: OnboardingConnectionFormDefaults,
        to state: inout State)
    {
        if state.normalizedManualHost.isEmpty {
            state.manualHostState = initialization.host
            state.manualPortState = initialization.port
            state.manualTLSState = initialization.tls
        }
        state.savedGatewayConnection = initialization.hasSavedGatewayConnection
        state.syncManualPortText()
        if state.selectedMode == nil {
            state.selectedMode = initialization.lastMode
        }
        if state.selectedMode == .developerLocal, state.manualHost == "openclaw.local" {
            state.manualHostState = .init(value: "localhost")
            state.manualTLSState = .init(value: false)
        }
    }

    private static func manualConnectionStart(
        host: OnboardingManualHost,
        port: OnboardingManualPort)
        -> OnboardingStatusFeature.Action.ConnectionStart
    {
        .init(
            id: .init(value: "manual"),
            message: .init(value: "Connecting to \(host.value)…"),
            statusLine: .init(value: "Connecting to \(host.value):\(port.value)…"),
            clearsIssue: .init(value: true))
    }
}

struct OnboardingManualConnectionClient {
    var connect: @MainActor @Sendable (
        OnboardingManualHost,
        OnboardingManualPort,
        OnboardingManualTLS,
        GatewayConnectionController.ManualAuthOverride?) async -> Void
}

extension OnboardingManualConnectionClient: DependencyKey {
    static let liveValue = OnboardingManualConnectionClient(connect: { _, _, _, _ in })
    static let testValue = OnboardingManualConnectionClient(connect: { _, _, _, _ in })

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        OnboardingManualConnectionClient(connect: { host, port, useTLS, authOverride in
            await gatewayController.connectManual(
                host: host.value,
                port: port.value,
                useTLS: useTLS.value,
                authOverride: authOverride)
        })
    }
}

extension DependencyValues {
    var onboardingManualConnection: OnboardingManualConnectionClient {
        get { self[OnboardingManualConnectionClient.self] }
        set { self[OnboardingManualConnectionClient.self] = newValue }
    }
}
