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
    }

    enum Action: Equatable, Sendable {
        case refreshRequested(sceneActive: Bool, sessionsAvailable: Bool)
        case refreshResponse(Result<[OpenClawChatSessionEntry], IPadActivitySessionsError>)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.iPadActivitySessions) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
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
            await self.refreshSessions()
        }
        .refreshable {
            await self.refreshSessions()
        }
    }

    private var metrics: [ProMetric] {
        [
            ProMetric(
                icon: self.gatewayConnected ? "checkmark.circle.fill" : "wifi.slash",
                title: "Gateway",
                value: self.gatewayStateText,
                color: self.gatewayConnected ? OpenClawBrand.ok : .secondary),
            ProMetric(
                icon: "person.2.fill",
                title: "Agents",
                value: self.gatewayConnected ? "\(self.appModel.gatewayAgents.count)" : "offline",
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
                    icon: self.gatewayConnected ? "network" : "wifi.slash",
                    title: "Gateway",
                    detail: self.gatewayDetailText,
                    value: self.gatewayStateText.lowercased(),
                    color: self.gatewayConnected ? OpenClawBrand.ok : .secondary,
                    actionTitle: self.gatewayConnected ? nil : "Settings",
                    action: self.gatewayConnected ? nil : self.openSettings)

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

    private var gatewayConnected: Bool {
        GatewayStatusBuilder.build(appModel: self.appModel) == .connected
    }

    private var gatewayStateText: String {
        guard !self.gatewayConnected else { return "Online" }
        let status = self.appModel.gatewayDisplayStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        return status.isEmpty ? "Offline" : status
    }

    private var gatewayDetailText: String {
        self.normalized(self.appModel.gatewayRemoteAddress)
            ?? self.normalized(self.appModel.gatewayServerName)
            ?? "No gateway connection"
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

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
