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
        var loadingPhase = IPadActivitySessionsLoadingPhase.idle
        var loadErrorText: IPadActivitySessionsFailureMessage?
        var gatewayPresentation = IPadActivityGatewayPresentationState()

        var sessions: [OpenClawChatSessionEntry] {
            self.sessionEntries.entries
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
        }

        struct RefreshResponse: Equatable, Sendable {
            var result: Result<IPadActivitySessionEntries, IPadActivitySessionsError>
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
                value: self.store.loadingPhase == .inFlight ? "..." : "\(self.sessionRows.count)",
                color: OpenClawBrand.accentHot),
        ]
    }

    private var activityFeed: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: "Recent activity",
                    value: self.store.loadingPhase == .inFlight ? "Loading" : nil,
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

                if self.store.loadingPhase == .inFlight, self.store.sessions.isEmpty {
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
                        detail: loadErrorText.value,
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
        await self.store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: .init(value: self.scenePhase == .active)),
            sessionsAvailability: .init(isAvailable: .init(value: self.sessionsAvailable))))).finish()
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
// swiftformat:enable redundantSendable

struct IPadActivityGatewayPresentationState: Equatable {
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
