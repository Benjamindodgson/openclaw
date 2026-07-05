import ComposableArchitecture
import Foundation
import OpenClawKit

// swiftformat:disable redundantSendable
struct SettingsLocalNetworkAccessReason: Equatable, Sendable {
    var value: String

    static let settingsPreflight = Self(value: "settings_preflight")
}

// swiftformat:enable redundantSendable

struct SettingsLocalNetworkAccessClient {
    var requestLocalNetworkAccess: @MainActor @Sendable (_ reason: SettingsLocalNetworkAccessReason) -> Void
}

extension SettingsLocalNetworkAccessClient: DependencyKey {
    static let liveValue = SettingsLocalNetworkAccessClient(requestLocalNetworkAccess: { _ in })
    static let testValue = SettingsLocalNetworkAccessClient(requestLocalNetworkAccess: { _ in })

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        SettingsLocalNetworkAccessClient(requestLocalNetworkAccess: { reason in
            gatewayController.requestLocalNetworkAccess(reason: reason.value)
        })
    }
}

extension DependencyValues {
    var settingsLocalNetworkAccess: SettingsLocalNetworkAccessClient {
        get { self[SettingsLocalNetworkAccessClient.self] }
        set { self[SettingsLocalNetworkAccessClient.self] = newValue }
    }
}

@Reducer
struct SettingsGatewaySetupStatusFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayProblemMessage: String?
        var gatewayStatusText = ""
        var statusText: String?

        var setupStatusLine: String? {
            SettingsGatewaySetupStatusFeature.setupStatusLine(
                problemMessage: self.gatewayProblemMessage,
                setupStatusText: self.statusText,
                gatewayStatusText: self.gatewayStatusText)
        }
    }

    enum Action: Equatable, Sendable {
        struct GatewayStatusSync: Equatable, Sendable {
            var problemMessage: String?
            var gatewayStatusText: String
        }

        struct QRScannerError: Equatable, Sendable { var message: String }
        struct SetupStatusChange: Equatable, Sendable { var statusText: String? }

        case gatewayStatusSynced(GatewayStatusSync)
        case qrScannerErrorReceived(QRScannerError)
        case qrScannerOpeningStarted
        case setupConnectionStarted
        case statusChanged(SetupStatusChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .gatewayStatusSynced(sync):
                state.gatewayProblemMessage = sync.problemMessage
                state.gatewayStatusText = sync.gatewayStatusText
                return .none

            case let .qrScannerErrorReceived(error):
                state.statusText = Self.qrScannerErrorStatusText(error.message)
                return .none

            case .qrScannerOpeningStarted:
                state.statusText = Self.qrScannerOpeningStartedStatusText
                return .none

            case .setupConnectionStarted:
                state.statusText = Self.setupConnectionStartedStatusText
                return .none

            case let .statusChanged(change):
                state.statusText = change.statusText
                return .none
            }
        }
        .autoLogActions()
    }

    static func setupStatusLine(
        problemMessage: String?,
        setupStatusText: String?,
        gatewayStatusText: String) -> String?
    {
        if let problemMessage {
            return problemMessage
        }
        let trimmedSetup = setupStatusText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let gatewayStatus = gatewayStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let friendly = Self.friendlyGatewayMessage(from: gatewayStatus) { return friendly }
        if let friendly = Self.friendlyGatewayMessage(from: trimmedSetup) { return friendly }
        if Self.isTransientSetupStatus(trimmedSetup),
           !gatewayStatus.isEmpty,
           gatewayStatus != "Offline"
        {
            return gatewayStatus
        }
        if !trimmedSetup.isEmpty { return trimmedSetup }
        if gatewayStatus.isEmpty || gatewayStatus == "Offline" { return nil }
        return gatewayStatus
    }

    static func friendlyGatewayMessage(from raw: String) -> String? {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("pairing required") {
            return "Pairing required. Run /pair approve in your OpenClaw chat, then connect again."
        }
        if lower.contains("device nonce required") || lower.contains("device nonce mismatch") {
            return "Secure handshake failed. Check Tailscale, then connect again."
        }
        if lower.contains("tls fingerprint verification timed out")
            || lower.contains("no tls endpoint detected")
        {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if lower.contains("timed out") {
            return "Connection timed out. Make sure Tailscale is connected, then try again."
        }
        if lower.contains("unauthorized role") {
            return "Connected, but some controls are restricted for nodes. This is expected."
        }
        return nil
    }

    static func isTransientSetupStatus(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower == "setup code applied. connecting..."
            || lower.hasPrefix("qr loaded. connecting to ")
            || lower == "checking gateway reachability..."
    }

    private static let setupConnectionStartedStatusText = "Setup code applied. Connecting..."
    private static let qrScannerOpeningStartedStatusText = "Opening QR scanner..."

    private static func qrScannerErrorStatusText(_ error: String) -> String {
        "Scanner error: \(error)"
    }
}

@Reducer
struct SettingsManualGatewayEndpointFeature {
    private let localNetworkAccessClientOverride: SettingsLocalNetworkAccessClient?

    init(localNetworkAccessClient: SettingsLocalNetworkAccessClient? = nil) {
        self.localNetworkAccessClientOverride = localNetworkAccessClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var manualConnectionResult: ManualConnectionResult?
        var manualGatewayEnabled = false
        var manualGatewayHost = ""
        var manualGatewayTLS = true
        var preflightResult: GatewayPreflightResult?

        func tailnetWarningText(hasTailnetIPv4: Bool) -> String? {
            Self.tailnetWarningText(
                host: self.manualGatewayHost,
                hasTailnetIPv4: hasTailnetIPv4)
        }

        static func tailnetWarningText(host: String, hasTailnetIPv4: Bool) -> String? {
            let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, Self.isTailnetHostOrIP(trimmed), !hasTailnetIPv4 else { return nil }
            return "This gateway is on your tailnet. Turn on Tailscale on this device, then tap Connect."
        }

        static func isTailnetHostOrIP(_ host: String) -> Bool {
            let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.hasSuffix(".ts.net") || trimmed.hasSuffix(".ts.net.") { return true }
            return self.isTailnetIPv4(trimmed)
        }

        static func isTailnetIPv4(_ ip: String) -> Bool {
            let parts = ip.split(separator: ".")
            guard parts.count == 4 else { return false }
            let octets = parts.compactMap { Int($0) }
            guard octets.count == 4 else { return false }
            let a = octets[0]
            let b = octets[1]
            guard (0...255).contains(a), (0...255).contains(b) else { return false }
            return a == 100 && b >= 64 && b <= 127
        }
    }

    struct ManualConnectionRequest: Equatable, Sendable {
        var host: String
        var port: Int
        var useTLS: Bool
    }

    enum ManualConnectionResult: Equatable, Sendable {
        struct Failure: Equatable, Sendable { var message: String }

        case failure(Failure)
        case request(ManualConnectionRequest)
    }

    enum GatewayPreflightResult: Equatable, Sendable {
        struct Blocked: Equatable, Sendable {
            var statusText: String?
        }

        struct LocalNetworkAccess: Equatable, Sendable {
            var reason: SettingsLocalNetworkAccessReason
        }

        case blocked(Blocked)
        case requestLocalNetworkAccess(LocalNetworkAccess)
    }

    enum Action: Equatable, Sendable {
        struct EndpointSync: Equatable, Sendable {
            var enabled: Bool
            var host: String
            var useTLS: Bool
        }

        struct ManualGatewayEnabled: Equatable, Sendable { var value: Bool }
        struct ManualGatewayEnabledChange: Equatable, Sendable { var enabled: ManualGatewayEnabled }
        struct ManualGatewayHostDraft: Equatable, Sendable { var value: String }
        struct ManualGatewayHostChange: Equatable, Sendable { var draft: ManualGatewayHostDraft }
        struct ManualGatewayTLS: Equatable, Sendable { var value: Bool }
        struct ManualGatewayTLSChange: Equatable, Sendable { var tls: ManualGatewayTLS }
        struct SetupLinkApplication: Equatable, Sendable {
            var host: String
            var useTLS: Bool
        }

        struct ManualConnectionAttempt: Equatable, Sendable {
            var port: Int
            var isPortValid: Bool
        }

        struct GatewayPreflightRequest: Equatable, Sendable {
            var host: String
            var hasTailnetIPv4: Bool
        }

        struct LocalNetworkAccessRequest: Equatable, Sendable { var reason: SettingsLocalNetworkAccessReason }

        case endpointClearedForOnboardingReset
        case endpointSynced(EndpointSync)
        case manualConnectionRequested(ManualConnectionAttempt)
        case manualConnectionResultHandled
        case manualGatewayEnabledChanged(ManualGatewayEnabledChange)
        case manualGatewayHostChanged(ManualGatewayHostChange)
        case manualGatewayTLSChanged(ManualGatewayTLSChange)
        case preflightRequested(GatewayPreflightRequest)
        case preflightResultHandled
        case localNetworkAccessRequested(LocalNetworkAccessRequest)
        case setupLinkApplied(SetupLinkApplication)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsLocalNetworkAccess) var dependencyLocalNetworkAccessClient
            let localNetworkAccessClient = self.localNetworkAccessClientOverride ?? dependencyLocalNetworkAccessClient

            switch action {
            case .endpointClearedForOnboardingReset:
                state.manualGatewayEnabled = false
                state.manualGatewayHost = ""
                return .none

            case let .endpointSynced(sync):
                state.manualGatewayEnabled = sync.enabled
                state.manualGatewayHost = sync.host
                state.manualGatewayTLS = sync.useTLS
                return .none

            case let .manualConnectionRequested(request):
                state.manualConnectionResult = nil
                let host = state.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !host.isEmpty else {
                    state.manualConnectionResult = .failure(.init(message: "Failed: host required"))
                    return .none
                }
                guard request.isPortValid else {
                    state.manualConnectionResult = .failure(.init(message: "Failed: invalid port"))
                    return .none
                }
                state.manualConnectionResult = .request(ManualConnectionRequest(
                    host: host,
                    port: request.port,
                    useTLS: state.manualGatewayTLS))
                return .none

            case .manualConnectionResultHandled:
                state.manualConnectionResult = nil
                return .none

            case let .preflightRequested(request):
                state.preflightResult = nil
                let trimmed = request.host.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    state.preflightResult = .blocked(.init(statusText: nil))
                    return .none
                }
                if State.isTailnetHostOrIP(trimmed), !request.hasTailnetIPv4 {
                    state.preflightResult = .blocked(.init(
                        statusText: "Tailscale is off on this device. Turn it on, then try again."))
                    return .none
                }
                state.preflightResult = .requestLocalNetworkAccess(.init(reason: .settingsPreflight))
                return .none

            case .preflightResultHandled:
                state.preflightResult = nil
                return .none

            case let .localNetworkAccessRequested(request):
                return .run { _ in
                    await localNetworkAccessClient.requestLocalNetworkAccess(request.reason)
                }

            case let .manualGatewayEnabledChanged(change):
                state.manualGatewayEnabled = change.enabled.value
                return .none

            case let .manualGatewayHostChanged(change):
                state.manualGatewayHost = change.draft.value
                return .none

            case let .manualGatewayTLSChanged(change):
                state.manualGatewayTLS = change.tls.value
                return .none

            case let .setupLinkApplied(application):
                state.manualGatewayHost = application.host
                state.manualGatewayTLS = application.useTLS
                return .none
            }
        }
        .autoLogActions()
    }
}
