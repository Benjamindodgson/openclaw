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
        var sessions: [OpenClawChatSessionEntry] = []
        var isLoading = false
        var loadErrorText: String?
        var gatewayPresentation = IPadActivityGatewayPresentationState()
    }

    enum Action: Equatable, Sendable {
        case gatewayPresentationChanged(IPadActivityGatewayPresentationState)
        case refreshRequested(sceneActive: Bool, sessionsAvailable: Bool)
        case refreshResponse(Result<[OpenClawChatSessionEntry], IPadActivitySessionsError>)
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

            case let .refreshRequested(sceneActive, sessionsAvailable):
                guard sceneActive else {
                    state.isLoading = false
                    return .none
                }
                guard sessionsAvailable else {
                    state.isLoading = false
                    state.sessions = []
                    state.loadErrorText = nil
                    return .none
                }

                state.isLoading = true
                state.loadErrorText = nil
                return .run { send in
                    do {
                        let sessions = try await client.listSessions(CommandCenterTab.recentSessionsFetchLimit)
                        await send(.refreshResponse(.success(sessions)))
                    } catch {
                        await send(.refreshResponse(.failure(.failed)))
                    }
                }

            case let .refreshResponse(.success(sessions)):
                state.isLoading = false
                state.sessions = sessions
                state.loadErrorText = nil
                return .none

            case .refreshResponse(.failure):
                state.isLoading = false
                state.sessions = []
                state.loadErrorText = "Try again after the gateway reconnects."
                return .none
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
        store: StoreOf<IPadActivitySessionsFeature> = Store(
            initialState: IPadActivitySessionsFeature.State())
        {
            IPadActivitySessionsFeature()
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.openChat = openChat
        self.openSettings = openSettings
        self._store = State(wrappedValue: store)
    }

    var body: some View {
        IPadSidebarScreenChrome(
            title: "Activity",
            subtitle: "Live device and gateway activity.",
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
        [
            ProMetric(
                icon: self.store.gatewayPresentation.metricIcon,
                title: "Gateway",
                value: self.store.gatewayPresentation.gatewayStateText,
                color: self.store.gatewayPresentation.gatewayStateColor),
            ProMetric(
                icon: "person.2.fill",
                title: "Agents",
                value: self.store.gatewayPresentation.agentCountText,
                color: OpenClawBrand.accent),
            ProMetric(
                icon: "bubble.left.and.text.bubble.right",
                title: "Sessions",
                value: self.store.isLoading ? "..." : "\(self.sessionRows.count)",
                color: OpenClawBrand.accentHot),
        ]
    }

    private var activityFeed: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: "Recent activity",
                    value: self.store.isLoading ? "Loading" : nil,
                    actionTitle: "Refresh",
                    action: {
                        Task { await self.refreshSessions() }
                    })

                if let pendingExecApprovalPrompt = self.appModel.pendingExecApprovalPrompt {
                    ProStatusRow(
                        icon: "hand.raised.fill",
                        title: "Approval needed",
                        detail: pendingExecApprovalPrompt.commandPreview ?? pendingExecApprovalPrompt.commandText,
                        value: "pending",
                        color: OpenClawBrand.warn,
                        actionTitle: nil,
                        action: nil)
                    Divider().padding(.leading, 58)
                }

                ProStatusRow(
                    icon: self.store.gatewayPresentation.rowIcon,
                    title: "Gateway",
                    detail: self.store.gatewayPresentation.gatewayDetailText,
                    value: self.store.gatewayPresentation.gatewayRowValue,
                    color: self.store.gatewayPresentation.gatewayStateColor,
                    actionTitle: self.store.gatewayPresentation.settingsActionTitle,
                    action: self.store.gatewayPresentation.showsSettingsAction ? self.openSettings : nil)

                Divider().padding(.leading, 58)

                ProStatusRow(
                    icon: "square.and.arrow.down",
                    title: "Share intake",
                    detail: self.appModel.lastShareEventText,
                    value: "iPad",
                    color: OpenClawBrand.accent,
                    actionTitle: nil,
                    action: nil)

                if self.store.isLoading, self.store.sessions.isEmpty {
                    Divider().padding(.leading, 58)
                    ProStatusRow(
                        icon: "hourglass",
                        title: "Loading sessions",
                        detail: "Fetching recent activity from the gateway.",
                        value: "loading",
                        color: OpenClawBrand.accent,
                        actionTitle: nil,
                        action: nil)
                } else if let loadErrorText = self.store.loadErrorText {
                    Divider().padding(.leading, 58)
                    ProStatusRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Sessions unavailable",
                        detail: loadErrorText,
                        value: "error",
                        color: OpenClawBrand.warn,
                        actionTitle: nil,
                        action: nil)
                } else if self.sessionRows.isEmpty {
                    Divider().padding(.leading, 58)
                    ProStatusRow(
                        icon: "bubble.left.and.text.bubble.right",
                        title: self.sessionsAvailable ? "No recent sessions" : "Session activity offline",
                        detail: self.sessionsAvailable
                            ? "Start a chat and it will appear here."
                            : "Connect to the gateway to load recent chat activity.",
                        value: self.sessionsAvailable ? "empty" : "offline",
                        color: .secondary,
                        actionTitle: self.sessionsAvailable ? "Chat" : nil,
                        action: self.sessionsAvailable ? self.openChat : nil)
                } else {
                    ForEach(self.sessionRows) { row in
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
        [
            self.sessionsMode,
            self.appModel.chatSessionKey,
            self.scenePhase == .active ? "active" : "inactive",
        ].joined(separator: ":")
    }

    private var currentGatewayPresentation: IPadActivityGatewayPresentationState {
        IPadActivityGatewayPresentationState(
            gatewayDisplayState: GatewayStatusBuilder.build(appModel: self.appModel),
            gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText,
            gatewayRemoteAddress: self.appModel.gatewayRemoteAddress,
            gatewayServerName: self.appModel.gatewayServerName,
            gatewayAgentCount: self.appModel.gatewayAgents.count)
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

    private var sessionRows: [CommandCenterTab.WorkItem] {
        self.store.sessions
            .filter { CommandCenterTab.isRecentChatSession(
                $0.key,
                defaultSessionKey: self.appModel.defaultChatSessionKey) }
            .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
            .prefix(8)
            .map {
                CommandCenterTab.sessionWorkItem(
                    for: $0,
                    currentSessionKey: self.appModel.chatSessionKey)
            }
    }

    private func refreshSessions() async {
        await self.store.send(.refreshRequested(
            sceneActive: self.scenePhase == .active,
            sessionsAvailable: self.sessionsAvailable)).finish()
    }

    private func open(_ item: CommandCenterTab.WorkItem) {
        switch item.route {
        case let .chat(sessionKey):
            self.appModel.openChat(sessionKey: sessionKey)
            self.openChat()
        case .settings:
            self.openSettings()
        }
    }
}

struct IPadActivityGatewayPresentationState: Equatable {
    var gatewayDisplayState: GatewayDisplayState = .disconnected
    var gatewayDisplayStatusText = "Offline"
    var gatewayRemoteAddress: String?
    var gatewayServerName: String?
    var gatewayAgentCount = 0

    var isConnected: Bool {
        self.gatewayDisplayState == .connected
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
