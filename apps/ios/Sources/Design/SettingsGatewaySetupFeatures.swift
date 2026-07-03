import ComposableArchitecture
import Foundation
import OpenClawKit

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
        case gatewayStatusSynced(problemMessage: String?, gatewayStatusText: String)
        case statusChanged(String?)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .gatewayStatusSynced(problemMessage, gatewayStatusText):
                state.gatewayProblemMessage = problemMessage
                state.gatewayStatusText = gatewayStatusText
                return .none

            case let .statusChanged(statusText):
                state.statusText = statusText
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
}

@Reducer
struct SettingsManualGatewayEndpointFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var manualConnectionResult: ManualConnectionResult?
        var manualGatewayEnabled = false
        var manualGatewayHost = ""
        var manualGatewayTLS = true

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
        case failure(String)
        case request(ManualConnectionRequest)
    }

    enum Action: Equatable, Sendable {
        case endpointClearedForOnboardingReset
        case endpointSynced(enabled: Bool, host: String, tls: Bool)
        case manualConnectionRequested(port: Int, isPortValid: Bool)
        case manualConnectionResultHandled
        case manualGatewayEnabledChanged(Bool)
        case manualGatewayHostChanged(String)
        case manualGatewayTLSChanged(Bool)
        case setupLinkApplied(host: String, tls: Bool)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .endpointClearedForOnboardingReset:
                state.manualGatewayEnabled = false
                state.manualGatewayHost = ""
                return .none

            case let .endpointSynced(enabled, host, tls):
                state.manualGatewayEnabled = enabled
                state.manualGatewayHost = host
                state.manualGatewayTLS = tls
                return .none

            case let .manualConnectionRequested(port, isPortValid):
                state.manualConnectionResult = nil
                let host = state.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !host.isEmpty else {
                    state.manualConnectionResult = .failure("Failed: host required")
                    return .none
                }
                guard isPortValid else {
                    state.manualConnectionResult = .failure("Failed: invalid port")
                    return .none
                }
                state.manualConnectionResult = .request(ManualConnectionRequest(
                    host: host,
                    port: port,
                    useTLS: state.manualGatewayTLS))
                return .none

            case .manualConnectionResultHandled:
                state.manualConnectionResult = nil
                return .none

            case let .manualGatewayEnabledChanged(enabled):
                state.manualGatewayEnabled = enabled
                return .none

            case let .manualGatewayHostChanged(host):
                state.manualGatewayHost = host
                return .none

            case let .manualGatewayTLSChanged(tls):
                state.manualGatewayTLS = tls
                return .none

            case let .setupLinkApplied(host, tls):
                state.manualGatewayHost = host
                state.manualGatewayTLS = tls
                return .none
            }
        }
        .autoLogActions()
    }
}
