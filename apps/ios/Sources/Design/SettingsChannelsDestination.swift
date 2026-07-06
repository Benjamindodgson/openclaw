import ComposableArchitecture
import OpenClawKit
import OpenClawProtocol
import SwiftUI

struct SettingsChannelsClient {
    var status: @Sendable @MainActor () async throws -> ChannelsStatusResult
    var start: @Sendable @MainActor (SettingsChannelOperationTarget) async throws -> Void
    var stop: @Sendable @MainActor (SettingsChannelOperationTarget) async throws -> Void
    var logout: @Sendable @MainActor (SettingsChannelOperationTarget) async throws -> Void
}

extension SettingsChannelsClient: DependencyKey {
    static let liveValue = SettingsChannelsClient(
        status: { SettingsChannelsClient.emptyStatus() },
        start: { _ in },
        stop: { _ in },
        logout: { _ in })

    static let testValue = SettingsChannelsClient(
        status: { SettingsChannelsClient.emptyStatus() },
        start: { _ in },
        stop: { _ in },
        logout: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsChannelsClient(
            status: {
                let params = ChannelsStatusParams(probe: false, timeoutms: 10000, channel: nil)
                let data = try await Self.request(
                    appModel: appModel,
                    method: "channels.status",
                    params: params,
                    timeoutSeconds: 12)
                return try JSONDecoder().decode(ChannelsStatusResult.self, from: data)
            },
            start: { target in
                let params = ChannelsStartParams(channel: target.channelID, accountid: target.accountID)
                _ = try await Self.request(
                    appModel: appModel,
                    method: "channels.start",
                    params: params,
                    timeoutSeconds: 20)
            },
            stop: { target in
                let params = ChannelsStopParams(channel: target.channelID, accountid: target.accountID)
                _ = try await Self.request(
                    appModel: appModel,
                    method: "channels.stop",
                    params: params,
                    timeoutSeconds: 20)
            },
            logout: { target in
                let params = ChannelsLogoutParams(channel: target.channelID, accountid: target.accountID)
                _ = try await Self.request(
                    appModel: appModel,
                    method: "channels.logout",
                    params: params,
                    timeoutSeconds: 20)
            })
    }

    private static func emptyStatus() -> ChannelsStatusResult {
        ChannelsStatusResult(
            ts: 0,
            channelorder: [],
            channellabels: [:],
            channeldetaillabels: nil,
            channelsystemimages: nil,
            channelmeta: nil,
            channels: [:],
            channelaccounts: [:],
            channeldefaultaccountid: [:],
            eventloop: nil,
            partial: nil,
            warnings: nil)
    }

    @MainActor
    private static func request(
        appModel: NodeAppModel,
        method: String,
        params: some Encodable,
        timeoutSeconds: Int) async throws -> Data
    {
        let data = try JSONEncoder().encode(params)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SettingsChannelError.invalidPayload
        }
        return try await appModel.operatorSession.request(
            method: method,
            paramsJSON: json,
            timeoutSeconds: timeoutSeconds)
    }
}

extension DependencyValues {
    var settingsChannels: SettingsChannelsClient {
        get { self[SettingsChannelsClient.self] }
        set { self[SettingsChannelsClient.self] = newValue }
    }
}

// swiftformat:disable redundantSendable
struct SettingsChannelsFailureMessage: Equatable, Sendable { var value: String }

enum SettingsChannelsError: Error, Equatable, Sendable {
    struct Failure: Equatable, Sendable { var message: SettingsChannelsFailureMessage }

    case failed(Failure)
}

// swiftformat:enable redundantSendable

@Reducer
struct SettingsChannelsFeature {
    private let clientOverride: SettingsChannelsClient?

    init(client: SettingsChannelsClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var entries: [SettingsChannelEntry] = []
        var isLoading = false
        var errorText: String?
        var busyOperation: SettingsChannelOperation?
    }

    enum Action: Equatable, Sendable {
        struct SceneActivity: Equatable, Sendable {
            var isActive: Bool
        }

        struct GatewayReadAccess: Equatable, Sendable {
            var canRead: Bool
        }

        struct OperatorAdminAccess: Equatable, Sendable {
            var canAdmin: Bool
        }

        struct RefreshForce: Equatable, Sendable {
            var isForced: Bool
        }

        struct RefreshRequest: Equatable, Sendable {
            var sceneActivity: SceneActivity
            var readAccess: GatewayReadAccess
            var force: RefreshForce
        }

        struct RefreshResponse: Equatable, Sendable {
            var force: RefreshForce
            var result: Result<[SettingsChannelEntry], SettingsChannelsError>
        }

        struct OperationRequest: Equatable, Sendable {
            var kind: SettingsChannelOperation.Kind
            var target: SettingsChannelOperationTarget
            var readAccess: GatewayReadAccess
            var adminAccess: OperatorAdminAccess
        }

        struct OperationResponse: Equatable, Sendable {
            var result: Result<[SettingsChannelEntry], SettingsChannelsError>
        }

        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)
        case operationRequested(OperationRequest)
        case operationResponse(OperationResponse)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsChannels) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .refreshRequested(request):
                guard request.sceneActivity.isActive else {
                    state.isLoading = false
                    return .none
                }
                guard request.readAccess.canRead else {
                    state.entries = []
                    state.isLoading = false
                    state.errorText = nil
                    return .none
                }
                guard !state.isLoading else { return .none }

                state.isLoading = true
                state.errorText = nil
                return .run { send in
                    do {
                        let snapshot = try await client.status()
                        await send(.refreshResponse(.init(
                            force: request.force,
                            result: .success(Self.entries(from: snapshot)))))
                    } catch {
                        await send(.refreshResponse(.init(
                            force: request.force,
                            result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .refreshResponse(response):
                state.isLoading = false
                switch response.result {
                case let .success(entries):
                    state.entries = entries
                    state.errorText = nil

                case let .failure(error):
                    if response.force.isForced || state.entries.isEmpty {
                        state.errorText = error.message
                    }
                }
                return .none

            case let .operationRequested(request):
                guard SettingsChannelsDestination.shouldEnableChannelOperation(
                    canRead: request.readAccess.canRead,
                    hasOperatorAdminScope: request.adminAccess.canAdmin),
                    state.busyOperation == nil
                else {
                    return .none
                }

                state.busyOperation = SettingsChannelOperation(
                    kind: request.kind,
                    channelID: request.target.channelID,
                    accountID: request.target.accountID)
                state.errorText = nil
                return .run { send in
                    do {
                        switch request.kind {
                        case .start:
                            try await client.start(request.target)
                        case .stop:
                            try await client.stop(request.target)
                        case .logout:
                            try await client.logout(request.target)
                        }
                        let snapshot = try await client.status()
                        await send(.operationResponse(.init(result: .success(Self.entries(from: snapshot)))))
                    } catch {
                        await send(.operationResponse(.init(
                            result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .operationResponse(response):
                switch response.result {
                case let .success(entries):
                    state.busyOperation = nil
                    state.entries = entries
                    state.errorText = nil
                    return .none

                case let .failure(error):
                    state.busyOperation = nil
                    state.errorText = error.message
                    return .none
                }
            }
        }
        .autoLogActions()
    }

    static func entries(from snapshot: ChannelsStatusResult) -> [SettingsChannelEntry] {
        let ids = snapshot.channelorder.isEmpty ? Array(snapshot.channels.keys).sorted() : snapshot.channelorder
        return ids.map { self.entry(channelID: $0, snapshot: snapshot) }
    }

    private static func entry(channelID: String, snapshot: ChannelsStatusResult) -> SettingsChannelEntry {
        let summary = snapshot.channels[channelID]?.dictionaryValue ?? [:]
        let accounts = self.accounts(channelID: channelID, snapshot: snapshot)
        let configured = accounts.contains(where: \.configured) || summary["configured"]?.boolValue == true
        let running = accounts.contains(where: \.running)
        let connected = accounts.contains(where: \.connected)
        let linked = accounts.contains(where: \.linked)
        let label = snapshot.channellabels[channelID]?.stringValue ?? SettingsChannelsDestination
            .fallbackLabel(channelID)
        let detail = snapshot.channeldetaillabels?[channelID]?.stringValue ?? SettingsChannelsDestination
            .fallbackDetail(channelID)
        let systemImage = snapshot.channelsystemimages?[channelID]?.stringValue ?? SettingsChannelsDestination
            .fallbackSystemImage(channelID)
        let lastActivity = accounts.compactMap(\.lastActivityMs).max()
        let lastError = accounts.compactMap(\.lastError).first ?? summary["lastError"]?.stringValue
        return SettingsChannelEntry(
            id: channelID,
            label: label,
            detail: detail,
            systemImage: systemImage,
            configured: configured,
            running: running,
            connected: connected,
            linked: linked,
            lastActivityText: lastActivity.map(Self.relativeTime),
            lastError: lastError,
            unavailableReason: configured ? nil : "Configure this channel on the gateway.",
            accounts: accounts)
    }

    private static func accounts(channelID: String, snapshot: ChannelsStatusResult) -> [SettingsChannelAccount] {
        let rawAccounts = snapshot.channelaccounts[channelID]?.arrayValue ?? []
        return rawAccounts.compactMap { raw in
            guard let dict = raw.dictionaryValue else { return nil }
            let accountID = dict["accountId"]?.stringValue ?? "default"
            let name = dict["name"]?.stringValue
            let lastActivity = [
                dict["lastInboundAt"]?.intValue,
                dict["lastOutboundAt"]?.intValue,
                dict["lastTransportActivityAt"]?.intValue,
            ]
                .compactMap(\.self)
                .max()
            return SettingsChannelAccount(
                id: accountID,
                name: name,
                configured: dict["configured"]?.boolValue == true,
                enabled: dict["enabled"]?.boolValue != false,
                running: dict["running"]?.boolValue == true,
                connected: dict["connected"]?.boolValue == true,
                linked: dict["linked"]?.boolValue == true,
                healthState: dict["healthState"]?.stringValue,
                lastError: dict["lastError"]?.stringValue,
                lastActivityMs: lastActivity)
        }
    }

    private static func relativeTime(_ milliseconds: Int) -> String {
        let age = max(0, Int(Date().timeIntervalSince1970 * 1000) - milliseconds)
        let minutes = age / 60000
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    private static func message(for error: Error) -> String {
        if let channelError = error as? SettingsChannelError {
            return channelError.message
        }
        return error.localizedDescription
    }

    private static func failure(for error: Error) -> SettingsChannelsError {
        .failed(.init(message: .init(value: self.message(for: error))))
    }
}

extension SettingsChannelsError {
    var message: String {
        switch self {
        case let .failed(failure):
            failure.message.value
        }
    }
}

enum SettingsChannelsStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<SettingsChannelsFeature> {
        Store(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: .live(appModel: appModel))
        }
    }
}

struct SettingsChannelsDestination: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    let showsSummaryCard: Bool
    @State private var store: StoreOf<SettingsChannelsFeature>

    init(
        showsSummaryCard: Bool = true,
        store: StoreOf<SettingsChannelsFeature> = Store(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature()
        })
    {
        self.showsSummaryCard = showsSummaryCard
        self._store = State(wrappedValue: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if self.showsSummaryCard {
                self.summaryCard
            }
            self.channelsCard
        }
        .task(id: self.refreshID) {
            await self.refreshChannels(force: false)
        }
        .refreshable {
            await self.refreshChannels(force: true)
        }
    }

    private var summaryCard: some View {
        ProCard(radius: SettingsLayout.cardRadius) {
            HStack(spacing: 12) {
                ProIconBadge(systemName: "point.3.connected.trianglepath.dotted", color: self.summaryColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Channels / Integrations")
                        .font(.headline)
                    Text(self.summaryDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                ProValuePill(value: self.summaryValue, color: self.summaryColor)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var channelsCard: some View {
        ProCard(padding: 0, radius: SettingsLayout.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: "Message Routing",
                    value: self.headerValue,
                    actionIcon: self.store.isLoading ? "hourglass" : "arrow.clockwise",
                    actionAccessibilityLabel: "Refresh Channels",
                    isActionDisabled: self.store.isLoading,
                    action: {
                        Task { await self.refreshChannels(force: true) }
                    })

                if let errorText = self.store.errorText {
                    ProStatusRow(
                        icon: "exclamationmark.triangle",
                        title: "Channel status unavailable",
                        detail: errorText,
                        value: "error",
                        color: OpenClawBrand.warn)
                } else if !self.canRead {
                    ProStatusRow(
                        icon: "wifi.slash",
                        title: "Gateway offline",
                        detail: "Connect to the gateway to load installed channels, accounts, and routing status.",
                        value: "offline",
                        color: .secondary)
                } else if self.store.isLoading, self.store.entries.isEmpty {
                    ProStatusRow(
                        icon: "hourglass",
                        title: "Loading channels",
                        detail: "Fetching installed channels, accounts, and routing status from the gateway.",
                        value: "loading",
                        color: OpenClawBrand.accent)
                } else if self.channelEntries.isEmpty {
                    ProStatusRow(
                        icon: "tray",
                        title: "No channel plugins reported",
                        detail: "Install or enable channel plugins on the gateway, then refresh.",
                        value: "empty",
                        color: .secondary)
                } else {
                    ForEach(Array(self.channelEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().padding(.leading, 58)
                        }
                        SettingsChannelRow(
                            entry: entry,
                            canAdmin: self.canAdmin,
                            busyOperation: self.store.busyOperation,
                            start: { accountID in
                                Task { await self.run(.start, channelID: entry.id, accountID: accountID) }
                            },
                            stop: { accountID in
                                Task { await self.run(.stop, channelID: entry.id, accountID: accountID) }
                            },
                            logout: { accountID in
                                Task { await self.run(.logout, channelID: entry.id, accountID: accountID) }
                            })
                    }
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var refreshID: String {
        [
            self.canRead ? "connected" : "offline",
            self.scenePhase == .active ? "active" : "inactive",
        ].joined(separator: ":")
    }

    private var canRead: Bool {
        self.appModel.isOperatorGatewayConnected
    }

    private var canAdmin: Bool {
        self.appModel.hasOperatorAdminScope
    }

    nonisolated static func shouldEnableChannelOperation(canRead: Bool, hasOperatorAdminScope: Bool) -> Bool {
        canRead && hasOperatorAdminScope
    }

    private var headerValue: String? {
        if self.store.isLoading { return "Loading" }
        guard self.canRead else { return "Offline" }
        return "\(self.channelEntries.count)"
    }

    private var summaryDetail: String {
        guard self.canRead else {
            return "Connect to load channel integrations."
        }
        if let errorText = self.store.errorText {
            return errorText
        }
        return "Installed channel clients, account state, and message-routing readiness."
    }

    private var summaryValue: String {
        guard self.canRead else { return "offline" }
        if self.store.isLoading { return "loading" }
        if self.store.errorText != nil { return "error" }
        let configured = self.channelEntries.count(where: { $0.configured })
        return "\(configured)/\(self.channelEntries.count)"
    }

    private var summaryColor: Color {
        guard self.canRead else { return .secondary }
        if self.store.errorText != nil { return OpenClawBrand.warn }
        return self.channelEntries.contains(where: { $0.running || $0.connected }) ? OpenClawBrand.ok : OpenClawBrand
            .accent
    }

    private var channelEntries: [SettingsChannelEntry] {
        self.store.entries
    }

    private func refreshChannels(force: Bool) async {
        await self.store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: self.scenePhase == .active),
            readAccess: .init(canRead: self.canRead),
            force: .init(isForced: force)))).finish()
    }

    private func run(_ kind: SettingsChannelOperation.Kind, channelID: String, accountID: String?) async {
        await self.store.send(.operationRequested(.init(
            kind: kind,
            target: .init(channelID: channelID, accountID: accountID),
            readAccess: .init(canRead: self.canRead),
            adminAccess: .init(canAdmin: self.canAdmin)))).finish()
    }

    nonisolated static func fallbackLabel(_ id: String) -> String {
        if let metadata = self.fallbackMetadata[id.lowercased()] {
            return metadata.label
        }
        return id.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    nonisolated static func fallbackDetail(_ id: String) -> String {
        self.fallbackMetadata[id.lowercased()]?.detail ?? "Channel integration"
    }

    nonisolated static func fallbackSystemImage(_ id: String) -> String {
        self.fallbackMetadata[id.lowercased()]?.systemImage ?? "bubble.left.and.text.bubble.right"
    }

    private nonisolated static let fallbackMetadata: [String: SettingsChannelFallbackMetadata] = [
        "clickclack": SettingsChannelFallbackMetadata(
            label: "ClickClack",
            detail: "Self-hosted chat bot routing.",
            systemImage: "bubble.left.and.bubble.right"),
    ]
}

private struct SettingsChannelRow: View {
    let entry: SettingsChannelEntry
    let canAdmin: Bool
    let busyOperation: SettingsChannelOperation?
    let start: (String?) -> Void
    let stop: (String?) -> Void
    let logout: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ProIconBadge(systemName: self.entry.systemImage, color: self.entry.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.entry.label)
                        .font(.subheadline.weight(.semibold))
                    Text(self.entry.detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let lastError = self.entry.lastError {
                        Text(lastError)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(OpenClawBrand.warn)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                ProValuePill(value: self.entry.statusValue, color: self.entry.color)
            }

            if !self.entry.accounts.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(self.entry.accounts.enumerated()), id: \.element.id) { index, account in
                        if index > 0 {
                            Divider().padding(.leading, 38)
                        }
                        self.accountRow(account)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func accountRow(_ account: SettingsChannelAccount) -> some View {
        HStack(spacing: 10) {
            Image(systemName: account.running || account.connected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(account.color)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.caption.weight(.semibold))
                Text(account.detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Menu {
                if account.running {
                    Button("Stop") {
                        self.stop(account.id)
                    }
                } else {
                    Button("Start") {
                        self.start(account.id)
                    }
                    .disabled(!account.configured || !account.enabled)
                }
                if account.linked {
                    Button("Logout", role: .destructive) {
                        self.logout(account.id)
                    }
                }
            } label: {
                Image(systemName: self.actionMenuIcon(account))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!self.canAdmin || self.isBusy(account))
        }
        .padding(.vertical, 8)
    }

    private func actionMenuIcon(_ account: SettingsChannelAccount) -> String {
        if self.isBusy(account) {
            return "hourglass"
        }
        if !self.canAdmin {
            return "lock.shield"
        }
        return "ellipsis.circle"
    }

    private func isBusy(_ account: SettingsChannelAccount) -> Bool {
        self.busyOperation?.channelID == self.entry.id && self.busyOperation?.accountID == account.id
    }
}

// swiftformat:disable redundantSendable
struct SettingsChannelEntry: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let detail: String
    let systemImage: String
    let configured: Bool
    let running: Bool
    let connected: Bool
    let linked: Bool
    let lastActivityText: String?
    let lastError: String?
    let unavailableReason: String?
    let accounts: [SettingsChannelAccount]

    var color: Color {
        if self.connected || self.running { return OpenClawBrand.ok }
        if self.lastError != nil { return OpenClawBrand.warn }
        return self.configured ? OpenClawBrand.accent : .secondary
    }

    var statusValue: String {
        if self.connected { return "connected" }
        if self.running { return "running" }
        if self.linked { return "linked" }
        if self.configured { return "configured" }
        return "not set"
    }

    var detailText: String {
        if let lastActivityText {
            return "\(self.detail) • active \(lastActivityText)"
        }
        if let unavailableReason {
            return unavailableReason
        }
        return self.detail
    }
}

// swiftformat:enable redundantSendable

private struct SettingsChannelFallbackMetadata {
    let label: String
    let detail: String
    let systemImage: String
}

// swiftformat:disable redundantSendable
struct SettingsChannelAccount: Equatable, Identifiable, Sendable {
    let id: String
    let name: String?
    let configured: Bool
    let enabled: Bool
    let running: Bool
    let connected: Bool
    let linked: Bool
    let healthState: String?
    let lastError: String?
    let lastActivityMs: Int?

    var displayName: String {
        let trimmedName = self.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? self.id : "\(trimmedName) (\(self.id))"
    }

    var detailText: String {
        let state = if self.connected {
            "connected"
        } else if self.running {
            "running"
        } else if self.linked {
            "linked"
        } else if self.configured {
            "configured"
        } else {
            "not configured"
        }
        let enabledText = self.enabled ? "enabled" : "disabled"
        if let healthState, !healthState.isEmpty {
            return "\(state), \(enabledText), \(healthState)"
        }
        if let lastError, !lastError.isEmpty {
            return "\(state), \(enabledText), error"
        }
        return "\(state), \(enabledText)"
    }

    var color: Color {
        if self.connected || self.running { return OpenClawBrand.ok }
        if self.lastError != nil { return OpenClawBrand.warn }
        return self.configured ? OpenClawBrand.accent : .secondary
    }
}

struct SettingsChannelOperation: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case start
        case stop
        case logout
    }

    let kind: Kind
    let channelID: String
    let accountID: String?
}

struct SettingsChannelOperationTarget: Equatable, Sendable {
    var channelID: String
    var accountID: String?
}

// swiftformat:enable redundantSendable

private enum SettingsChannelError: Error {
    case invalidPayload

    var message: String {
        switch self {
        case .invalidPayload:
            "Could not encode channel request."
        }
    }
}

#if DEBUG
#Preview("Channels states") {
    SettingsChannelsStatesPreview()
}

private struct SettingsChannelsStatesPreview: View {
    var body: some View {
        ZStack {
            OpenClawProBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    self.stateSection("Connected") {
                        SettingsChannelRow(
                            entry: Self.telegramEntry,
                            canAdmin: true,
                            busyOperation: nil,
                            start: { _ in },
                            stop: { _ in },
                            logout: { _ in })
                    }

                    self.stateSection("Loading") {
                        ProPanelHeader(
                            title: "Message Routing",
                            value: "Loading",
                            actionIcon: "hourglass",
                            actionAccessibilityLabel: "Refresh Channels",
                            isActionDisabled: true,
                            action: {})
                        ProStatusRow(
                            icon: "hourglass",
                            title: "Loading channel status",
                            detail: "Checking installed channel clients and account state.",
                            value: "loading",
                            color: OpenClawBrand.accent)
                    }

                    self.stateSection("Empty") {
                        ProPanelHeader(
                            title: "Message Routing",
                            value: "0",
                            actionIcon: "arrow.clockwise",
                            actionAccessibilityLabel: "Refresh Channels",
                            action: {})
                        ProStatusRow(
                            icon: "tray",
                            title: "No channel plugins reported",
                            detail: "Install or enable channel plugins on the gateway, then refresh.",
                            value: "empty",
                            color: .secondary)
                    }

                    self.stateSection("Error") {
                        ProStatusRow(
                            icon: "exclamationmark.triangle",
                            title: "Channel status unavailable",
                            detail: "Gateway returned an unexpected channel status response.",
                            value: "error",
                            color: OpenClawBrand.warn)
                    }

                    self.stateSection("Offline") {
                        ProStatusRow(
                            icon: "wifi.slash",
                            title: "Gateway offline",
                            detail: "Connect to the gateway to load installed channels, accounts, and routing status.",
                            value: "offline",
                            color: .secondary)
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
            ProCard(padding: 0, radius: SettingsLayout.cardRadius) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private static let telegramEntry = SettingsChannelEntry(
        id: "telegram",
        label: "Telegram",
        detail: "Message routing client",
        systemImage: "paperplane",
        configured: true,
        running: true,
        connected: true,
        linked: true,
        lastActivityText: "4m ago",
        lastError: nil,
        unavailableReason: nil,
        accounts: [
            SettingsChannelAccount(
                id: "main",
                name: "OpenClaw Ops",
                configured: true,
                enabled: true,
                running: true,
                connected: true,
                linked: true,
                healthState: "healthy",
                lastError: nil,
                lastActivityMs: nil),
        ])
}
#endif
