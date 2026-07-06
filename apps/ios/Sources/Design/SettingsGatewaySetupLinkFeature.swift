import ComposableArchitecture
import Foundation
import OpenClawKit

// swiftformat:disable redundantSendable
struct SettingsGatewaySetupLinkFailureMessage: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

@Reducer
struct SettingsGatewaySetupLinkFeature {
    static let emptySetupCodeFailureMessage = SettingsGatewaySetupLinkFailureMessage(
        value: "Paste a setup code to continue.")
    static let invalidSetupCodeFailureMessage = SettingsGatewaySetupLinkFailureMessage(
        value: "Setup code not recognized or uses an insecure ws:// gateway URL.")

    private let appleReviewDemoClientOverride: SettingsAppleReviewDemoClient?

    init(appleReviewDemoClient: SettingsAppleReviewDemoClient? = nil) {
        self.appleReviewDemoClientOverride = appleReviewDemoClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var applyResult: ApplyResult?
        var scannedGatewayLinkStatusText: String?
        var setupCode = ""
        var setupLinkStatusText: String?
        var stagedGatewaySetupLink: GatewayConnectDeepLink?

        var canApplyGatewaySetup: Bool {
            !self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || self.stagedGatewaySetupLink != nil
        }
    }

    enum ApplyResult: Equatable, Sendable {
        struct AppleReviewDemo: Equatable, Sendable {
            var statusText: String
        }

        struct Failure: Equatable, Sendable { var message: SettingsGatewaySetupLinkFailureMessage }

        case appleReviewDemo(AppleReviewDemo)
        case failure(Failure)
        case gatewayLink(GatewayConnectDeepLink)
    }

    enum Action: Equatable, Sendable {
        struct ScannedGatewayLink: Equatable, Sendable { var link: GatewayConnectDeepLink }

        struct ScannedSetupCode: Equatable, Sendable { var code: SettingsGatewaySetupCode }

        struct SetupCodeChange: Equatable, Sendable { var setupCode: SettingsGatewaySetupCode }

        struct SetupCodeSync: Equatable, Sendable { var setupCode: SettingsGatewaySetupCode }

        struct SetupLinkStage: Equatable, Sendable { var link: GatewayConnectDeepLink? }

        case applyRequested
        case applyResultHandled
        case scannedGatewayLinkReceived(ScannedGatewayLink)
        case scannedGatewayLinkStatusHandled
        case scannedSetupCodeReceived(ScannedSetupCode)
        case setupCodeChanged(SetupCodeChange)
        case setupCodeSynced(SetupCodeSync)
        case setupLinkStaged(SetupLinkStage)
        case setupLinkStatusHandled
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsAppleReviewDemo) var dependencyAppleReviewDemoClient
            let appleReviewDemoClient = self.appleReviewDemoClientOverride ?? dependencyAppleReviewDemoClient

            switch action {
            case .applyRequested:
                let raw = state.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
                let stagedLink = state.stagedGatewaySetupLink
                guard !raw.isEmpty || stagedLink != nil else {
                    state.applyResult = .failure(.init(message: Self.emptySetupCodeFailureMessage))
                    return .none
                }

                if AppleReviewDemoMode.isSetupCode(raw) {
                    state.setupCode = ""
                    state.stagedGatewaySetupLink = nil
                    state.applyResult = .appleReviewDemo(.init(statusText: Self.appleReviewDemoStatusText))
                    return .run { _ in
                        await appleReviewDemoClient.enter()
                    }
                }

                guard let link = raw.isEmpty ? stagedLink : GatewayConnectDeepLink.fromSetupInput(raw) else {
                    state.applyResult = .failure(.init(message: Self.invalidSetupCodeFailureMessage))
                    return .none
                }
                state.stagedGatewaySetupLink = nil
                state.applyResult = .gatewayLink(link)
                return .none

            case .applyResultHandled:
                state.applyResult = nil
                return .none

            case let .scannedGatewayLinkReceived(scan):
                let link = scan.link
                state.applyResult = nil
                state.setupCode = ""
                state.stagedGatewaySetupLink = nil
                state.scannedGatewayLinkStatusText = Self.scannedGatewayLinkStatusText(link)
                state.applyResult = .gatewayLink(link)
                return .none

            case .scannedGatewayLinkStatusHandled:
                state.scannedGatewayLinkStatusText = nil
                return .none

            case let .scannedSetupCodeReceived(scan):
                state.applyResult = nil
                guard AppleReviewDemoMode.isSetupCode(scan.code.value) else {
                    return .none
                }
                state.setupCode = ""
                state.stagedGatewaySetupLink = nil
                state.applyResult = .appleReviewDemo(.init(statusText: Self.appleReviewDemoStatusText))
                return .run { _ in
                    await appleReviewDemoClient.enter()
                }

            case let .setupCodeChanged(change):
                let setupCode = change.setupCode.value
                state.setupCode = setupCode
                if !setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.stagedGatewaySetupLink = nil
                }
                return .none

            case let .setupCodeSynced(sync):
                let setupCode = sync.setupCode.value
                state.setupCode = setupCode
                if !setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.stagedGatewaySetupLink = nil
                }
                return .none

            case let .setupLinkStaged(stage):
                state.stagedGatewaySetupLink = stage.link
                if let link = stage.link {
                    state.setupCode = ""
                    state.setupLinkStatusText = Self.setupLinkLoadedStatusText(link)
                } else {
                    state.setupLinkStatusText = nil
                }
                return .none

            case .setupLinkStatusHandled:
                state.setupLinkStatusText = nil
                return .none
            }
        }
        .autoLogActions()
    }

    private static func setupLinkLoadedStatusText(_ link: GatewayConnectDeepLink) -> String {
        let security = link.tls ? "TLS" : "plain"
        return "Setup link loaded for \(link.host):\(link.port) (\(security)). Tap Connect to apply."
    }

    private static func scannedGatewayLinkStatusText(_ link: GatewayConnectDeepLink) -> String {
        "QR loaded. Connecting to \(link.host):\(link.port)..."
    }

    private static let appleReviewDemoStatusText = "Apple Review demo mode enabled."
}
