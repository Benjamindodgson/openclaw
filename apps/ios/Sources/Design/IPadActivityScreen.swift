import ComposableArchitecture
import OpenClawChatUI
import OpenClawKit
import SwiftUI

struct IPadActivitySessionsClient {
    var listSessions: @Sendable @MainActor (_ limit: Int) async throws -> [OpenClawChatSessionEntry]
}

extension IPadActivitySessionsClient: DependencyKey {
    static let liveValue = IPadActivitySessionsClient(listSessions: { _ in [] })
    static let testValue = IPadActivitySessionsClient(listSessions: { _ in [] })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        IPadActivitySessionsClient(listSessions: { limit in
            let transport = appModel.makeChatTransport()
            let response = try await transport.listSessions(limit: limit)
            return response.sessions
        })
    }
}

extension DependencyValues {
    var iPadActivitySessions: IPadActivitySessionsClient {
        get { self[IPadActivitySessionsClient.self] }
        set { self[IPadActivitySessionsClient.self] = newValue }
    }
}

// swiftformat:disable redundantSendable
struct IPadActivitySessionsFailureMessage: Equatable, Sendable { var value: String }

enum IPadActivitySessionsLoadingPhase: Equatable, Sendable {
    case idle
    case inFlight
}

struct IPadActivitySceneActive: Equatable, Sendable { var value: Bool }
struct IPadActivitySessionsAvailable: Equatable, Sendable { var value: Bool }
struct IPadActivitySessionsMode: Equatable, Sendable { var value: String }
struct IPadActivitySessionReferenceKey: Equatable, Sendable { var value: String }
struct IPadActivityShareEventText: Equatable, Sendable { var value: String }
struct IPadActivityPendingApprovalCommandText: Equatable, Sendable { var value: String }
struct IPadActivityPendingApprovalCommandPreview: Equatable, Sendable { var value: String? }
struct IPadActivityPendingApprovalSnapshot: Equatable, Sendable {
    var commandText: IPadActivityPendingApprovalCommandText
    var commandPreview: IPadActivityPendingApprovalCommandPreview
}

struct IPadActivitySessionEntries: Equatable, Sendable {
    var entries: [OpenClawChatSessionEntry] = []
}

enum IPadActivitySessionsError: Error, Equatable, Sendable {
    case failed
}

// swiftformat:enable redundantSendable

@Reducer
struct IPadActivitySessionsFeature {
    private let clientOverride: IPadActivitySessionsClient?

    init(client: IPadActivitySessionsClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var sessionEntries = IPadActivitySessionEntries()
        var currentSession = IPadActivitySessionReferenceKey(value: "")
        var defaultSession = IPadActivitySessionReferenceKey(value: "")
        var loadingPhase = IPadActivitySessionsLoadingPhase.idle
        var loadErrorText: IPadActivitySessionsFailureMessage?
        var gatewayPresentation = IPadActivityGatewayPresentationState()

        var sessions: [OpenClawChatSessionEntry] {
            self.sessionEntries.entries
        }

        var visibleSessions: [OpenClawChatSessionEntry] {
            Array(
                self.sessionEntries.entries
                    .filter {
                        CommandCenterTab.isRecentChatSession($0.key, defaultSessionKey: self.defaultSession.value)
                    }
                    .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
                    .prefix(8))
        }

        var screenChromePresentation: IPadActivityScreenChromePresentation {
            .init(
                title: "Activity",
                subtitle: "Live device and gateway activity.")
        }

        func refreshTaskID(
            sessionsMode: IPadActivitySessionsMode,
            currentSession: IPadActivitySessionReferenceKey,
            defaultSession: IPadActivitySessionReferenceKey,
            sceneActivity: IPadActivitySceneActive) -> String
        {
            [
                sessionsMode.value,
                currentSession.value,
                defaultSession.value,
                sceneActivity.value ? "active" : "inactive",
            ].joined(separator: ":")
        }

        func emptySessionPresentation(
            sessionsAvailability: IPadActivitySessionsAvailable) -> IPadActivityEmptySessionPresentation
        {
            if sessionsAvailability.value {
                return .init(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "No recent sessions",
                    detail: "Start a chat and it will appear here.",
                    value: "empty",
                    actionTitle: "Chat",
                    opensChat: true)
            }
            return .init(
                icon: "bubble.left.and.text.bubble.right",
                title: "Session activity offline",
                detail: "Connect to the gateway to load recent chat activity.",
                value: "offline",
                actionTitle: nil,
                opensChat: false)
        }

        func shareIntakePresentation(
            lastShareEventText: IPadActivityShareEventText) -> IPadActivityShareIntakePresentation
        {
            .init(
                icon: "square.and.arrow.down",
                title: "Share intake",
                detail: lastShareEventText.value,
                value: "iPad")
        }

        func pendingApprovalPresentation(
            pendingApproval: IPadActivityPendingApprovalSnapshot?) -> IPadActivityPendingApprovalPresentation?
        {
            guard let pendingApproval else { return nil }
            return .init(
                icon: "hand.raised.fill",
                title: "Approval needed",
                detail: pendingApproval.commandPreview.value ?? pendingApproval.commandText.value,
                value: "pending")
        }

        func screenPresentation(
            sessionsAvailability: IPadActivitySessionsAvailable,
            sessionsMode: IPadActivitySessionsMode,
            currentSession: IPadActivitySessionReferenceKey,
            defaultSession: IPadActivitySessionReferenceKey,
            sceneActivity: IPadActivitySceneActive,
            lastShareEventText: IPadActivityShareEventText,
            pendingApproval: IPadActivityPendingApprovalSnapshot?) -> IPadActivityScreenPresentation
        {
            let sessionRows = self.visibleSessions.map {
                CommandCenterTab.sessionWorkItem(
                    for: $0,
                    currentSessionKey: self.currentSession.value)
            }
            return .init(
                screenChromePresentation: self.screenChromePresentation,
                gatewayPresentation: self.gatewayPresentation,
                refreshTaskID: self.refreshTaskID(
                    sessionsMode: sessionsMode,
                    currentSession: currentSession,
                    defaultSession: defaultSession,
                    sceneActivity: sceneActivity),
                sessionRows: sessionRows,
                sessionMetricValue: self.loadingPhase == .inFlight ? "..." : "\(sessionRows.count)",
                feedHeaderValue: self.loadingPhase == .inFlight ? "Loading" : nil,
                showsLoadingSessionsPlaceholder: self.loadingPhase == .inFlight && self.sessions.isEmpty,
                loadErrorText: self.loadErrorText,
                emptySessionPresentation: self.emptySessionPresentation(sessionsAvailability: sessionsAvailability),
                shareIntakePresentation: self.shareIntakePresentation(lastShareEventText: lastShareEventText),
                pendingApprovalPresentation: self.pendingApprovalPresentation(pendingApproval: pendingApproval))
        }
    }

    enum Action: Equatable, Sendable {
        struct SceneActivity: Equatable, Sendable {
            var isActive: IPadActivitySceneActive
        }

        struct SessionsAvailability: Equatable, Sendable {
            var isAvailable: IPadActivitySessionsAvailable
        }

        struct RefreshRequest: Equatable, Sendable {
            var sceneActivity: SceneActivity
            var sessionsAvailability: SessionsAvailability
            var currentSession: SessionReference
            var defaultSession: SessionReference
        }

        struct RefreshResponse: Equatable, Sendable {
            var result: Result<IPadActivitySessionEntries, IPadActivitySessionsError>
        }

        struct SessionReference: Equatable, Sendable {
            var key: IPadActivitySessionReferenceKey
        }

        case gatewayPresentationChanged(IPadActivityGatewayPresentationState)
        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.iPadActivitySessions) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .gatewayPresentationChanged(presentation):
                state.gatewayPresentation = presentation
                return .none

            case let .refreshRequested(request):
                state.currentSession = request.currentSession.key
                state.defaultSession = request.defaultSession.key

                guard request.sceneActivity.isActive.value else {
                    state.loadingPhase = .idle
                    return .none
                }
                guard request.sessionsAvailability.isAvailable.value else {
                    state.loadingPhase = .idle
                    state.sessionEntries = .init()
                    state.loadErrorText = nil
                    return .none
                }

                state.loadingPhase = .inFlight
                state.loadErrorText = nil
                return .run { send in
                    do {
                        let sessions = try await client.listSessions(CommandCenterTab.recentSessionsFetchLimit)
                        await send(.refreshResponse(.init(result: .success(.init(entries: sessions)))))
                    } catch {
                        await send(.refreshResponse(.init(result: .failure(.failed))))
                    }
                }

            case let .refreshResponse(response):
                switch response.result {
                case let .success(sessionEntries):
                    state.loadingPhase = .idle
                    state.sessionEntries = sessionEntries
                    state.loadErrorText = nil
                    return .none

                case .failure:
                    state.loadingPhase = .idle
                    state.sessionEntries = .init()
                    state.loadErrorText = .init(value: "Try again after the gateway reconnects.")
                    return .none
                }
            }
        }
        .autoLogActions()
    }
}

enum IPadActivitySessionsStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<IPadActivitySessionsFeature> {
        Store(initialState: IPadActivitySessionsFeature.State()) {
            IPadActivitySessionsFeature(client: .live(appModel: appModel))
        }
    }
}

struct IPadActivityScreen: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: StoreOf<IPadActivitySessionsFeature>
    let headerLeadingAction: OpenClawSidebarHeaderAction?
    let openChat: () -> Void
    let openSettings: () -> Void

    init(
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        openChat: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        store: StoreOf<IPadActivitySessionsFeature>? = nil,
        storeFactory: () -> StoreOf<IPadActivitySessionsFeature> = {
            Store(initialState: IPadActivitySessionsFeature.State()) {
                IPadActivitySessionsFeature()
            }
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.openChat = openChat
        self.openSettings = openSettings
        let resolvedStore = store ?? storeFactory()
        _store = State(wrappedValue: resolvedStore)
    }

    var body: some View {
        IPadSidebarScreenChrome(
            title: self.screenPresentation.screenChromePresentation.title,
            subtitle: self.screenPresentation.screenChromePresentation.subtitle,
            headerLeadingAction: self.headerLeadingAction,
            gatewayAction: self.openSettings)
        {
            ProMetricGrid(metrics: self.metrics)
            self.activityFeed
        }
        .task(id: self.refreshID) {
            self.syncGatewayPresentation()
            await self.refreshSessions()
        }
        .onChange(of: self.currentGatewayPresentation) { _, _ in
            self.syncGatewayPresentation()
        }
        .refreshable {
            await self.refreshSessions()
        }
    }

    private var metrics: [ProMetric] {
        let gatewayPresentation = self.screenPresentation.gatewayPresentation
        return [
            ProMetric(
                icon: gatewayPresentation.metricIcon,
                title: "Gateway",
                value: gatewayPresentation.gatewayStateText,
                color: gatewayPresentation.gatewayStateColor),
            ProMetric(
                icon: "person.2.fill",
                title: "Agents",
                value: gatewayPresentation.agentCountText,
                color: OpenClawBrand.accent),
            ProMetric(
                icon: "bubble.left.and.text.bubble.right",
                title: "Sessions",
                value: self.screenPresentation.sessionMetricValue,
                color: OpenClawBrand.accentHot),
        ]
    }

    private var activityFeed: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: "Recent activity",
                    value: self.screenPresentation.feedHeaderValue,
                    actionTitle: "Refresh",
                    action: {
                        Task { await self.refreshSessions() }
                    })

                if let pendingApprovalPresentation = self.screenPresentation.pendingApprovalPresentation {
                    ProStatusRow(
                        icon: pendingApprovalPresentation.icon,
                        title: pendingApprovalPresentation.title,
                        detail: pendingApprovalPresentation.detail,
                        value: pendingApprovalPresentation.value,
                        color: OpenClawBrand.warn,
                        actionTitle: nil,
                        action: nil)
                    Divider().padding(.leading, 58)
                }

                let gatewayPresentation = self.screenPresentation.gatewayPresentation
                ProStatusRow(
                    icon: gatewayPresentation.rowIcon,
                    title: "Gateway",
                    detail: gatewayPresentation.gatewayDetailText,
                    value: gatewayPresentation.gatewayRowValue,
                    color: gatewayPresentation.gatewayStateColor,
                    actionTitle: gatewayPresentation.settingsActionTitle,
                    action: gatewayPresentation.showsSettingsAction ? self.openSettings : nil)

                Divider().padding(.leading, 58)

                let shareIntakePresentation = self.screenPresentation.shareIntakePresentation
                ProStatusRow(
                    icon: shareIntakePresentation.icon,
                    title: shareIntakePresentation.title,
                    detail: shareIntakePresentation.detail,
                    value: shareIntakePresentation.value,
                    color: OpenClawBrand.accent,
                    actionTitle: nil,
                    action: nil)

                if self.screenPresentation.showsLoadingSessionsPlaceholder {
                    Divider().padding(.leading, 58)
                    ProStatusRow(
                        icon: "hourglass",
                        title: "Loading sessions",
                        detail: "Fetching recent activity from the gateway.",
                        value: "loading",
                        color: OpenClawBrand.accent,
                        actionTitle: nil,
                        action: nil)
                } else if let loadErrorText = self.screenPresentation.loadErrorText {
                    Divider().padding(.leading, 58)
                    ProStatusRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Sessions unavailable",
                        detail: loadErrorText.value,
                        value: "error",
                        color: OpenClawBrand.warn,
                        actionTitle: nil,
                        action: nil)
                } else if self.screenPresentation.sessionRows.isEmpty {
                    Divider().padding(.leading, 58)
                    let presentation = self.screenPresentation.emptySessionPresentation
                    ProStatusRow(
                        icon: presentation.icon,
                        title: presentation.title,
                        detail: presentation.detail,
                        value: presentation.value,
                        color: .secondary,
                        actionTitle: presentation.actionTitle,
                        action: presentation.opensChat ? self.openChat : nil)
                } else {
                    ForEach(self.screenPresentation.sessionRows) { row in
                        Divider().padding(.leading, 58)
                        ProStatusRow(
                            icon: row.icon,
                            title: row.title,
                            detail: row.detail,
                            value: row.state,
                            color: row.color,
                            actionTitle: "Open",
                            action: {
                                self.open(row)
                            })
                    }
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var refreshID: String {
        self.screenPresentation.refreshTaskID
    }

    private var currentGatewayPresentation: IPadActivityGatewayPresentationState {
        IPadActivityGatewayPresentationState(
            gatewayDisplayState: GatewayStatusBuilder.build(appModel: self.appModel),
            gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText,
            gatewayRemoteAddress: self.appModel.gatewayRemoteAddress,
            gatewayServerName: self.appModel.gatewayServerName,
            gatewayAgentCount: self.appModel.gatewayAgents.count)
    }

    private var screenPresentation: IPadActivityScreenPresentation {
        self.store.state.screenPresentation(
            sessionsAvailability: .init(value: self.sessionsAvailable),
            sessionsMode: .init(value: self.sessionsMode),
            currentSession: .init(value: self.appModel.chatSessionKey),
            defaultSession: .init(value: self.appModel.defaultChatSessionKey),
            sceneActivity: .init(value: self.scenePhase == .active),
            lastShareEventText: .init(value: self.appModel.lastShareEventText),
            pendingApproval: self.pendingApprovalSnapshot)
    }

    private func syncGatewayPresentation() {
        let presentation = self.currentGatewayPresentation
        guard self.store.gatewayPresentation != presentation else { return }
        self.store.send(.gatewayPresentationChanged(presentation))
    }

    private var sessionsAvailable: Bool {
        self.appModel.isLocalChatFixtureEnabled || self.appModel.isOperatorGatewayConnected
    }

    private var sessionsMode: String {
        self.appModel.chatTransportModeID
    }

    private var pendingApprovalSnapshot: IPadActivityPendingApprovalSnapshot? {
        self.appModel.pendingExecApprovalPrompt.map {
            .init(
                commandText: .init(value: $0.commandText),
                commandPreview: .init(value: $0.commandPreview))
        }
    }

    private func refreshSessions() async {
        await self.store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: .init(value: self.scenePhase == .active)),
            sessionsAvailability: .init(isAvailable: .init(value: self.sessionsAvailable)),
            currentSession: .init(key: .init(value: self.appModel.chatSessionKey)),
            defaultSession: .init(key: .init(value: self.appModel.defaultChatSessionKey))))).finish()
    }

    private func open(_ item: CommandCenterTab.WorkItem) {
        switch item.route {
        case let .chat(route):
            self.appModel.openChat(sessionKey: route.sessionKey)
            self.openChat()
        case .settings:
            self.openSettings()
        }
    }
}

// swiftformat:disable redundantSendable
struct IPadActivityGatewayRemoteAddress: Equatable, Sendable { var value: String? }
struct IPadActivityGatewayServerName: Equatable, Sendable { var value: String? }
struct IPadActivityGatewayDisplayStatusText: Equatable, Sendable { var value: String }
struct IPadActivityGatewayAgentCount: Equatable, Sendable { var value: Int }

struct IPadActivityScreenPresentation: Equatable, Sendable {
    let screenChromePresentation: IPadActivityScreenChromePresentation
    let gatewayPresentation: IPadActivityGatewayPresentationState
    let refreshTaskID: String
    let sessionRows: [CommandCenterTab.WorkItem]
    let sessionMetricValue: String
    let feedHeaderValue: String?
    let showsLoadingSessionsPlaceholder: Bool
    let loadErrorText: IPadActivitySessionsFailureMessage?
    let emptySessionPresentation: IPadActivityEmptySessionPresentation
    let shareIntakePresentation: IPadActivityShareIntakePresentation
    let pendingApprovalPresentation: IPadActivityPendingApprovalPresentation?
}

struct IPadActivityScreenChromePresentation: Equatable, Sendable {
    let title: String
    let subtitle: String
}

struct IPadActivityEmptySessionPresentation: Equatable, Sendable {
    let icon: String
    let title: String
    let detail: String
    let value: String
    let actionTitle: String?
    let opensChat: Bool
}

struct IPadActivityShareIntakePresentation: Equatable, Sendable {
    let icon: String
    let title: String
    let detail: String
    let value: String
}

struct IPadActivityPendingApprovalPresentation: Equatable, Sendable {
    let icon: String
    let title: String
    let detail: String
    let value: String
}

struct IPadActivityGatewayPresentationState: Equatable, Sendable {
    var gatewayDisplayState: GatewayDisplayState = .disconnected
    var gatewayDisplayStatusTextState = IPadActivityGatewayDisplayStatusText(value: "Offline")
    var gatewayRemoteAddressState = IPadActivityGatewayRemoteAddress(value: nil)
    var gatewayServerNameState = IPadActivityGatewayServerName(value: nil)
    var gatewayAgentCountState = IPadActivityGatewayAgentCount(value: 0)

    init(
        gatewayDisplayState: GatewayDisplayState = .disconnected,
        gatewayDisplayStatusText: String = "Offline",
        gatewayRemoteAddress: String? = nil,
        gatewayServerName: String? = nil,
        gatewayAgentCount: Int = 0)
    {
        self.gatewayDisplayState = gatewayDisplayState
        self.gatewayDisplayStatusTextState = .init(value: gatewayDisplayStatusText)
        self.gatewayRemoteAddressState = .init(value: gatewayRemoteAddress)
        self.gatewayServerNameState = .init(value: gatewayServerName)
        self.gatewayAgentCountState = .init(value: gatewayAgentCount)
    }

    var isConnected: Bool {
        self.gatewayDisplayState == .connected
    }

    var gatewayRemoteAddress: String? {
        self.gatewayRemoteAddressState.value
    }

    var gatewayServerName: String? {
        self.gatewayServerNameState.value
    }

    var gatewayDisplayStatusText: String {
        self.gatewayDisplayStatusTextState.value
    }

    var gatewayAgentCount: Int {
        self.gatewayAgentCountState.value
    }

    var metricIcon: String {
        self.isConnected ? "checkmark.circle.fill" : "wifi.slash"
    }

    var rowIcon: String {
        self.isConnected ? "network" : "wifi.slash"
    }

    var gatewayStateText: String {
        guard !self.isConnected else { return "Online" }
        let status = self.gatewayDisplayStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        return status.isEmpty ? "Offline" : status
    }

    var gatewayRowValue: String {
        self.gatewayStateText.lowercased()
    }

    var gatewayStateColor: Color {
        self.isConnected ? OpenClawBrand.ok : .secondary
    }

    var agentCountText: String {
        self.isConnected ? "\(self.gatewayAgentCount)" : "offline"
    }

    var gatewayDetailText: String {
        Self.normalized(self.gatewayRemoteAddress)
            ?? Self.normalized(self.gatewayServerName)
            ?? "No gateway connection"
    }

    var settingsActionTitle: String? {
        self.showsSettingsAction ? "Settings" : nil
    }

    var showsSettingsAction: Bool {
        !self.isConnected
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// swiftformat:enable redundantSendable
