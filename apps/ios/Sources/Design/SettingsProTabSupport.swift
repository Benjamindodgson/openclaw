import ComposableArchitecture
import Darwin
import OpenClawKit
import SwiftUI
import UserNotifications

enum SettingsRoute: Hashable {
    case gateway
    case approvals
    case permissions
    case channels
    case voice
    case diagnostics
    case privacy
    case notifications
    case about
}

enum SettingsLayout {
    static let cardRadius: CGFloat = OpenClawProMetric.cardRadius
    static let rowHeight: CGFloat = 58
}

// swiftformat:disable redundantSendable
struct SettingsGatewayStoredCredentials: Equatable, Sendable {
    var token: String
    var password: String
}

struct SettingsGatewayCredentialValue: Equatable, Sendable {
    var value: String

    init(rawValue: String) {
        self.value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SettingsGatewayCredentialDraft: Equatable, Sendable {
    var value: String
}

struct SettingsGatewayCurrentInstanceID: Equatable, Sendable {
    var value: String

    var trimmedValue: String? {
        let trimmed = self.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct SettingsGatewayStableID: Equatable, Sendable {
    var value: String

    var trimmedValue: String? {
        let trimmed = self.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct SettingsDeviceDisplayName: Equatable, Sendable { var value: String }

struct SettingsManualGatewayPortText: Equatable, Sendable { var value: String }

struct SettingsOnboardingRequestID: Equatable, Sendable { var value: Int }

struct SettingsGatewaySetupCode: Equatable, Sendable { var value: String }

struct SettingsDefaultShareInstruction: Equatable, Sendable { var value: String }

// swiftformat:enable redundantSendable

struct SettingsGatewayCredentialsPersistenceClient {
    var loadCredentials: @Sendable (_ instanceId: SettingsGatewayCurrentInstanceID)
        -> SettingsGatewayStoredCredentials
    var saveGatewayPassword: @MainActor @Sendable (
        _ value: SettingsGatewayCredentialValue,
        _ instanceId: SettingsGatewayCurrentInstanceID)
        -> Void
    var saveGatewayToken: @MainActor @Sendable (
        _ value: SettingsGatewayCredentialValue,
        _ instanceId: SettingsGatewayCurrentInstanceID)
        -> Void
}

extension SettingsGatewayCredentialsPersistenceClient: DependencyKey {
    static let liveValue = SettingsGatewayCredentialsPersistenceClient(
        loadCredentials: { instanceId in
            guard let instanceId = instanceId.trimmedValue else {
                return .init(token: "", password: "")
            }
            return SettingsGatewayStoredCredentials(
                token: GatewaySettingsStore.loadGatewayToken(instanceId: instanceId) ?? "",
                password: GatewaySettingsStore.loadGatewayPassword(instanceId: instanceId) ?? "")
        },
        saveGatewayPassword: { value, instanceId in
            guard let instanceId = instanceId.trimmedValue else { return }
            GatewaySettingsStore.saveGatewayPassword(value.value, instanceId: instanceId)
        },
        saveGatewayToken: { value, instanceId in
            guard let instanceId = instanceId.trimmedValue else { return }
            GatewaySettingsStore.saveGatewayToken(value.value, instanceId: instanceId)
        })

    static let testValue = SettingsGatewayCredentialsPersistenceClient(
        loadCredentials: { _ in .init(token: "", password: "") },
        saveGatewayPassword: { _, _ in },
        saveGatewayToken: { _, _ in })
}

extension DependencyValues {
    var settingsGatewayCredentialsPersistence: SettingsGatewayCredentialsPersistenceClient {
        get { self[SettingsGatewayCredentialsPersistenceClient.self] }
        set { self[SettingsGatewayCredentialsPersistenceClient.self] = newValue }
    }
}

struct SettingsGatewaySetupAuthPersistenceClient {
    var currentInstanceID: @Sendable () -> SettingsGatewayCurrentInstanceID
    var prepareForBootstrapPairing: @MainActor @Sendable (_ instanceId: SettingsGatewayCurrentInstanceID) -> Void
    var saveSetupAuth: @MainActor @Sendable (_ request: SettingsGatewaySetupAuthPersistenceRequest) -> Void

    init(
        currentInstanceID: @escaping @Sendable () -> SettingsGatewayCurrentInstanceID,
        prepareForBootstrapPairing: @escaping @MainActor @Sendable (
            _ instanceId: SettingsGatewayCurrentInstanceID) -> Void = { _ in },
        saveSetupAuth: @escaping @MainActor @Sendable (_ request: SettingsGatewaySetupAuthPersistenceRequest) -> Void)
    {
        self.currentInstanceID = currentInstanceID
        self.prepareForBootstrapPairing = prepareForBootstrapPairing
        self.saveSetupAuth = saveSetupAuth
    }
}

struct SettingsGatewaySetupAuthPersistenceRequest: Equatable {
    let setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth
    let instanceId: SettingsGatewayCurrentInstanceID

    var hasBootstrapToken: Bool {
        self.setupAuth.hasBootstrapToken
    }

    var trimmedInstanceId: String? {
        self.instanceId.trimmedValue
    }
}

extension SettingsGatewaySetupAuthPersistenceClient: DependencyKey {
    static let liveValue = SettingsGatewaySetupAuthPersistenceClient(
        currentInstanceID: {
            .init(value: GatewaySettingsStore.currentInstanceID())
        },
        saveSetupAuth: { request in
            guard let instanceId = request.trimmedInstanceId else { return }

            GatewaySettingsStore.saveGatewayBootstrapToken(
                request.setupAuth.bootstrapToken,
                instanceId: instanceId)
            if request.setupAuth.shouldApplyTokenField {
                GatewaySettingsStore.saveGatewayToken(request.setupAuth.token, instanceId: instanceId)
            }
            if request.setupAuth.shouldApplyPasswordField {
                GatewaySettingsStore.saveGatewayPassword(request.setupAuth.password, instanceId: instanceId)
            }
        })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsGatewaySetupAuthPersistenceClient(
            currentInstanceID: {
                .init(value: GatewaySettingsStore.currentInstanceID())
            },
            prepareForBootstrapPairing: { instanceId in
                guard let instanceId = instanceId.trimmedValue else { return }
                GatewayOnboardingReset.prepareForBootstrapPairing(appModel: appModel, instanceId: instanceId)
            },
            saveSetupAuth: self.liveValue.saveSetupAuth)
    }

    static let testValue = SettingsGatewaySetupAuthPersistenceClient(
        currentInstanceID: { .init(value: "") },
        saveSetupAuth: { _ in })
}

extension DependencyValues {
    var settingsGatewaySetupAuthPersistence: SettingsGatewaySetupAuthPersistenceClient {
        get { self[SettingsGatewaySetupAuthPersistenceClient.self] }
        set { self[SettingsGatewaySetupAuthPersistenceClient.self] = newValue }
    }
}

struct SettingsOnboardingResetClient {
    var reset: @MainActor @Sendable (_ instanceId: SettingsGatewayCurrentInstanceID) -> Void
}

extension SettingsOnboardingResetClient: DependencyKey {
    static let liveValue = SettingsOnboardingResetClient(reset: { _ in })
    static let testValue = SettingsOnboardingResetClient(reset: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsOnboardingResetClient(reset: { instanceId in
            GatewayOnboardingReset.reset(appModel: appModel, instanceId: instanceId.value)
        })
    }
}

extension DependencyValues {
    var settingsOnboardingReset: SettingsOnboardingResetClient {
        get { self[SettingsOnboardingResetClient.self] }
        set { self[SettingsOnboardingResetClient.self] = newValue }
    }
}

struct SettingsAppleReviewDemoClient {
    var enter: @MainActor @Sendable () -> Void
}

extension SettingsAppleReviewDemoClient: DependencyKey {
    static let liveValue = SettingsAppleReviewDemoClient(enter: {})
    static let testValue = SettingsAppleReviewDemoClient(enter: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsAppleReviewDemoClient(enter: {
            appModel.enterAppleReviewDemoMode()
        })
    }
}

extension DependencyValues {
    var settingsAppleReviewDemo: SettingsAppleReviewDemoClient {
        get { self[SettingsAppleReviewDemoClient.self] }
        set { self[SettingsAppleReviewDemoClient.self] = newValue }
    }
}

struct SettingsShareInstructionPersistenceClient {
    var loadDefaultInstruction: @Sendable () -> SettingsDefaultShareInstruction
    var saveDefaultInstruction: @MainActor @Sendable (_ instruction: SettingsDefaultShareInstruction) -> Void
}

extension SettingsShareInstructionPersistenceClient: DependencyKey {
    static let liveValue = SettingsShareInstructionPersistenceClient(
        loadDefaultInstruction: {
            .init(value: ShareToAgentSettings.loadDefaultInstruction())
        },
        saveDefaultInstruction: { instruction in
            ShareToAgentSettings.saveDefaultInstruction(instruction.value)
        })

    static let testValue = SettingsShareInstructionPersistenceClient(
        loadDefaultInstruction: { .init(value: "") },
        saveDefaultInstruction: { _ in })
}

extension DependencyValues {
    var settingsShareInstructionPersistence: SettingsShareInstructionPersistenceClient {
        get { self[SettingsShareInstructionPersistenceClient.self] }
        set { self[SettingsShareInstructionPersistenceClient.self] = newValue }
    }
}

struct SettingsDiscoveredGatewayPersistenceClient {
    var saveSelectedGatewayStableID: @MainActor @Sendable (_ stableID: SettingsGatewayStableID) -> Void
}

extension SettingsDiscoveredGatewayPersistenceClient: DependencyKey {
    static let liveValue = SettingsDiscoveredGatewayPersistenceClient(
        saveSelectedGatewayStableID: { stableID in
            guard let stableID = stableID.trimmedValue else { return }
            GatewaySettingsStore.savePreferredGatewayStableID(stableID)
            GatewaySettingsStore.saveLastDiscoveredGatewayStableID(stableID)
        })

    static let testValue = SettingsDiscoveredGatewayPersistenceClient(
        saveSelectedGatewayStableID: { _ in })
}

extension DependencyValues {
    var settingsDiscoveredGatewayPersistence: SettingsDiscoveredGatewayPersistenceClient {
        get { self[SettingsDiscoveredGatewayPersistenceClient.self] }
        set { self[SettingsDiscoveredGatewayPersistenceClient.self] = newValue }
    }
}

struct SettingsGatewayDisconnectClient {
    var disconnect: @MainActor @Sendable () -> Void
}

extension SettingsGatewayDisconnectClient: DependencyKey {
    static let liveValue = SettingsGatewayDisconnectClient(disconnect: {})
    static let testValue = SettingsGatewayDisconnectClient(disconnect: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsGatewayDisconnectClient(disconnect: {
            appModel.disconnectGateway()
        })
    }
}

extension DependencyValues {
    var settingsGatewayDisconnect: SettingsGatewayDisconnectClient {
        get { self[SettingsGatewayDisconnectClient.self] }
        set { self[SettingsGatewayDisconnectClient.self] = newValue }
    }
}

struct SettingsGatewayReconnectClient {
    var reconnect: @MainActor @Sendable () async -> Void
}

extension SettingsGatewayReconnectClient: DependencyKey {
    static let liveValue = SettingsGatewayReconnectClient(reconnect: {})
    static let testValue = SettingsGatewayReconnectClient(reconnect: {})

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        SettingsGatewayReconnectClient(reconnect: {
            await gatewayController.connectLastKnown()
        })
    }
}

extension DependencyValues {
    var settingsGatewayReconnect: SettingsGatewayReconnectClient {
        get { self[SettingsGatewayReconnectClient.self] }
        set { self[SettingsGatewayReconnectClient.self] = newValue }
    }
}

struct SettingsGatewayProblemTrustClient {
    var trustRotatedCertificate: @MainActor @Sendable (GatewayConnectionProblem) async -> Bool
}

extension SettingsGatewayProblemTrustClient: DependencyKey {
    static let liveValue = SettingsGatewayProblemTrustClient(trustRotatedCertificate: { _ in false })
    static let testValue = SettingsGatewayProblemTrustClient(trustRotatedCertificate: { _ in false })

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        SettingsGatewayProblemTrustClient(trustRotatedCertificate: { problem in
            await gatewayController.trustRotatedGatewayCertificate(from: problem)
        })
    }
}

extension DependencyValues {
    var settingsGatewayProblemTrust: SettingsGatewayProblemTrustClient {
        get { self[SettingsGatewayProblemTrustClient.self] }
        set { self[SettingsGatewayProblemTrustClient.self] = newValue }
    }
}

struct SettingsGatewayDiagnosticsRefreshClient {
    var refreshGateway: @MainActor @Sendable () async -> Void
}

extension SettingsGatewayDiagnosticsRefreshClient: DependencyKey {
    static let liveValue = SettingsGatewayDiagnosticsRefreshClient(refreshGateway: {})
    static let testValue = SettingsGatewayDiagnosticsRefreshClient(refreshGateway: {})

    @MainActor
    static func live(appModel: NodeAppModel, gatewayController: GatewayConnectionController) -> Self {
        SettingsGatewayDiagnosticsRefreshClient(refreshGateway: {
            gatewayController.refreshActiveGatewayRegistrationFromSettings()
            gatewayController.restartDiscovery()
            await appModel.refreshGatewayOverviewIfConnected()
        })
    }
}

extension DependencyValues {
    var settingsGatewayDiagnosticsRefresh: SettingsGatewayDiagnosticsRefreshClient {
        get { self[SettingsGatewayDiagnosticsRefreshClient.self] }
        set { self[SettingsGatewayDiagnosticsRefreshClient.self] = newValue }
    }
}

struct SettingsApprovalItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let priority: String
    let color: Color
}

struct SettingsApprovalRow: View {
    let item: SettingsApprovalItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: self.item.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(self.item.color)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(self.item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(self.item.detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(self.item.priority)
                .font(.caption.weight(.bold))
                .foregroundStyle(self.item.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(self.item.color.opacity(0.10))
                }
        }
        .padding(.vertical, 7)
    }
}

enum SettingsNotificationStatus: Equatable {
    case checking
    case allowed
    case notAllowed
    case notSet
    case unknown

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            self = .allowed
        case .denied:
            self = .notAllowed
        case .notDetermined:
            self = .notSet
        @unknown default:
            self = .unknown
        }
    }

    var text: String {
        switch self {
        case .checking: "Checking"
        case .allowed: "Enabled"
        case .notAllowed: "Denied"
        case .notSet: "Not Enabled"
        case .unknown: "Unknown"
        }
    }

    var actionTitle: String {
        switch self {
        case .notSet:
            "Enable Notifications"
        case .checking:
            "Checking"
        case .allowed:
            "Manage in iOS Settings"
        case .notAllowed, .unknown:
            "Open iOS Settings"
        }
    }

    var actionIcon: String {
        switch self {
        case .allowed:
            "gear"
        case .notAllowed, .unknown:
            "gear.badge"
        case .checking:
            "hourglass"
        case .notSet:
            "bell.badge"
        }
    }

    var color: Color {
        switch self {
        case .allowed:
            OpenClawBrand.ok
        case .notAllowed, .unknown:
            OpenClawBrand.warn
        case .checking, .notSet:
            .secondary
        }
    }

    var shouldOpenNotificationSettings: Bool {
        switch self {
        case .allowed, .notAllowed, .unknown:
            true
        case .checking, .notSet:
            false
        }
    }

    var allowsNotifications: Bool {
        self == .allowed
    }
}

enum SettingsDiagnosticIssue: String, Equatable, CaseIterable {
    case gatewayOffline
    case discoveryUnavailable
    case talkConfigMissing
    case notificationsUnavailable
}

enum SettingsDiagnostics {
    static func issues(
        gatewayConnected: Bool,
        discoveredGatewayCount: Int,
        talkConfigLoaded: Bool,
        notificationsAllowed: Bool) -> [SettingsDiagnosticIssue]
    {
        var issues: [SettingsDiagnosticIssue] = []
        if !gatewayConnected { issues.append(.gatewayOffline) }
        if discoveredGatewayCount == 0 { issues.append(.discoveryUnavailable) }
        if gatewayConnected, !talkConfigLoaded { issues.append(.talkConfigMissing) }
        if !notificationsAllowed { issues.append(.notificationsUnavailable) }
        return issues
    }

    static func issueCount(
        gatewayConnected: Bool,
        discoveredGatewayCount: Int,
        talkConfigLoaded: Bool,
        notificationsAllowed: Bool) -> Int
    {
        self.issues(
            gatewayConnected: gatewayConnected,
            discoveredGatewayCount: discoveredGatewayCount,
            talkConfigLoaded: talkConfigLoaded,
            notificationsAllowed: notificationsAllowed).count
    }

    static func timestamp(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

extension SettingsProTab {
    static func hasTailnetIPv4() -> Bool {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0, let first = addrList else { return false }
        defer { freeifaddrs(addrList) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard let addrPtr = ptr.pointee.ifa_addr else { continue }
            let family = addrPtr.pointee.sa_family
            if !isUp || isLoopback || family != UInt8(AF_INET) { continue }
            var addr = addrPtr.pointee
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                &addr,
                socklen_t(addrPtr.pointee.sa_len),
                &buffer,
                socklen_t(buffer.count),
                nil,
                0,
                NI_NUMERICHOST)
            guard result == 0 else { continue }
            let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            guard let ip = String(bytes: bytes, encoding: .utf8) else { continue }
            if SettingsManualGatewayEndpointFeature.State.isTailnetIPv4(ip) { return true }
        }
        return false
    }
}

#if DEBUG
#Preview("Gateway settings states") {
    SettingsGatewayStatesPreview()
}

private struct SettingsGatewayStatesPreview: View {
    var body: some View {
        ZStack {
            OpenClawProBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    self.stateSection("Connected") {
                        self.gatewayStatusCard(
                            title: "Gateway online",
                            detail: "Connected to openclaw-gateway.tailnet.ts.net.",
                            value: "online",
                            color: OpenClawBrand.ok)
                        self.gatewayFactsCard(
                            address: "100.88.41.20:18789",
                            server: "openclaw-gateway",
                            discovered: "3",
                            agent: "Aiden")
                    }

                    self.stateSection("Loading") {
                        self.gatewayStatusCard(
                            title: "Checking gateway",
                            detail: "Refreshing connection, discovery, and device trust state.",
                            value: "loading",
                            color: OpenClawBrand.accent)
                        self.gatewayActionsCard(isBusy: true)
                    }

                    self.stateSection("Empty") {
                        self.gatewayStatusCard(
                            title: "No gateway configured",
                            detail: "Scan a setup QR code, paste a setup code, or choose a discovered gateway.",
                            value: "setup",
                            color: .secondary)
                        self.setupActionsCard
                    }

                    self.stateSection("Error") {
                        GatewayProblemBanner(
                            problem: Self.pairingProblem,
                            primaryActionTitle: "Retry",
                            onPrimaryAction: {},
                            onShowDetails: {})
                        self.gatewayStatusCard(
                            title: "Tailscale warning",
                            detail: "Tailscale is off on this device. Turn it on, then try again.",
                            value: "network",
                            color: OpenClawBrand.warn)
                    }
                }
                .padding(.horizontal, OpenClawProMetric.pagePadding)
                .padding(.vertical, 18)
            }
        }
    }

    private func stateSection(
        _ title: String,
        @ViewBuilder content: () -> some View) -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func gatewayStatusCard(
        title: String,
        detail: String,
        value: String,
        color: Color) -> some View
    {
        ProCard(padding: 0, radius: SettingsLayout.cardRadius) {
            ProStatusRow(
                icon: value == "online" ? "antenna.radiowaves.left.and.right" : "wifi.slash",
                title: title,
                detail: detail,
                value: value,
                color: color,
                actionTitle: value == "setup" ? "Scan QR" : nil,
                action: value == "setup" ? {} : nil)
        }
    }

    private func gatewayFactsCard(
        address: String,
        server: String,
        discovered: String,
        agent: String) -> some View
    {
        ProCard(radius: SettingsLayout.cardRadius) {
            VStack(spacing: 0) {
                self.factRow("Address", value: address)
                Divider()
                self.factRow("Server", value: server)
                Divider()
                self.factRow("Discovered", value: discovered)
                Divider()
                self.factRow("Default Agent", value: agent)
            }
        }
    }

    private func factRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(height: SettingsLayout.rowHeight)
    }

    private func gatewayActionsCard(isBusy: Bool) -> some View {
        ProCard(radius: SettingsLayout.cardRadius) {
            HStack(spacing: 10) {
                self.previewButton("Reconnect", systemImage: "arrow.triangle.2.circlepath", isBusy: isBusy)
                self.previewButton("Diagnose", systemImage: "cross.case", isBusy: isBusy)
            }
        }
    }

    private var setupActionsCard: some View {
        ProCard(radius: SettingsLayout.cardRadius) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    self.previewButton("Scan QR", systemImage: "qrcode.viewfinder", isBusy: false)
                    self.previewButton("Connect", systemImage: "link", isBusy: false)
                }
                Text("Discovered gateways and manual setup live here when the gateway has not connected yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func previewButton(
        _ title: String,
        systemImage: String,
        isBusy: Bool) -> some View
    {
        Button {} label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isBusy)
    }

    private static let pairingProblem = GatewayConnectionProblem(
        kind: .pairingRequired,
        owner: .gateway,
        title: "Pairing required",
        message: "Run /pair approve in your OpenClaw chat before this iPad can connect.",
        actionCommand: "/pair approve req-ipad-preview",
        requestId: "req-ipad-preview",
        retryable: false,
        pauseReconnect: true)
}
#endif
