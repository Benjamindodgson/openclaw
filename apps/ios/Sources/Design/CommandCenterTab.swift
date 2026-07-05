import ComposableArchitecture
import OpenClawChatUI
import SwiftUI

struct CommandCenterTab: View {
    static let recentSessionsFetchLimit = 200

    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var gatewayStore: StoreOf<CommandCenterGatewayPresentationFeature>
    @State private var recentSessionsStore: StoreOf<CommandCenterRecentSessionsFeature>
    var ownsNavigationStack: Bool = true
    var headerTitle: String = "OpenClaw"
    var headerLeadingAction: OpenClawSidebarHeaderAction?
    var showsHeaderMark: Bool = true
    var openChat: () -> Void
    var openSettings: () -> Void
    var openSessions: (() -> Void)?

    struct ChatRoute: Equatable {
        let sessionKey: String?

        static let defaultSession = Self(sessionKey: nil)

        static func recentSession(_ sessionKey: String) -> Self {
            Self(sessionKey: sessionKey)
        }
    }

    enum WorkRoute: Equatable {
        case chat(ChatRoute)
        case settings
    }

    struct WorkItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let state: String
        let trailing: String
        let color: Color
        let progress: Double?
        let route: WorkRoute
    }

    init(
        ownsNavigationStack: Bool = true,
        headerTitle: String = "OpenClaw",
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        showsHeaderMark: Bool = true,
        openChat: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        openSessions: (() -> Void)? = nil,
        gatewayStore: StoreOf<CommandCenterGatewayPresentationFeature> = Store(
            initialState: CommandCenterGatewayPresentationFeature.State())
        {
            CommandCenterGatewayPresentationFeature()
        },
        recentSessionsStore: StoreOf<CommandCenterRecentSessionsFeature> = Store(
            initialState: CommandCenterRecentSessionsFeature.State())
        {
            CommandCenterRecentSessionsFeature()
        })
    {
        self.ownsNavigationStack = ownsNavigationStack
        self.headerTitle = headerTitle
        self.headerLeadingAction = headerLeadingAction
        self.showsHeaderMark = showsHeaderMark
        self.openChat = openChat
        self.openSettings = openSettings
        self.openSessions = openSessions
        self._gatewayStore = State(wrappedValue: gatewayStore)
        self._recentSessionsStore = State(wrappedValue: recentSessionsStore)
    }

    var body: some View {
        Group {
            if self.ownsNavigationStack {
                NavigationStack {
                    self.content
                }
            } else {
                self.content
            }
        }
        .task(id: self.recentSessionsRefreshID) {
            self.syncGatewayPresentation()
            await self.refreshRecentSessionsIfNeeded()
        }
        .onChange(of: self.currentGatewayPresentation) { _, _ in
            self.syncGatewayPresentation()
        }
    }

    private var content: some View {
        GeometryReader { geometry in
            ZStack {
                CommandControlBackground()
                self.commandAmbientOverlay
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        self.header
                        self.gatewayCard
                        if Self.usesSplitSectionsLayout(
                            horizontalSizeClass: self.horizontalSizeClass,
                            containerWidth: geometry.size.width)
                        {
                            HStack(alignment: .top, spacing: 12) {
                                self.defaultChatSessionSection
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                self.recentSessions
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .padding(.horizontal, OpenClawProMetric.pagePadding)
                        } else {
                            self.defaultChatSessionSection
                                .padding(.horizontal, OpenClawProMetric.pagePadding)
                            self.recentSessions
                                .padding(.horizontal, OpenClawProMetric.pagePadding)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 18)
                }
                .safeAreaPadding(.bottom, OpenClawProMetric.bottomScrollInset)
            }
        }
        .navigationBarHidden(true)
    }

    static func usesSplitSectionsLayout(
        horizontalSizeClass: UserInterfaceSizeClass?,
        containerWidth: CGFloat) -> Bool
    {
        guard horizontalSizeClass == .regular else { return false }
        return containerWidth >= 1000
    }

    static func shouldShowHeaderMark(
        hasLeadingAction: Bool,
        showsHeaderMark: Bool) -> Bool
    {
        !hasLeadingAction && showsHeaderMark
    }

    private var header: some View {
        OpenClawAdaptiveHeaderRow(
            title: self.headerTitle,
            subtitle: self.gatewayStore.presentation.gatewaySubtitle,
            titleFont: .title3.weight(.semibold),
            subtitleFont: .caption,
            subtitleLineLimit: 1)
        {
            if let headerLeadingAction {
                OpenClawSidebarHeaderLeadingSlot(action: headerLeadingAction)
            } else if Self.shouldShowHeaderMark(
                hasLeadingAction: headerLeadingAction != nil,
                showsHeaderMark: self.showsHeaderMark)
            {
                OpenClawProMark(size: 28, shadowRadius: 5)
            }
        } accessory: {
            Button(action: self.openSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: OpenClawProMetric.compactControlSize, height: OpenClawProMetric.compactControlSize)
            }
            .openClawGlassButton()
            .accessibilityLabel("Gateway settings")
            .accessibilityHint("Opens gateway settings")
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var commandAmbientOverlay: some View {
        Group {
            if self.colorScheme == .light {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    private var gatewayCard: some View {
        CommandPanel(isProminent: true, padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                self.cardHeader(title: "Gateway")

                HStack(spacing: 0) {
                    self.gatewayFact(
                        icon: "network",
                        title: "Connection",
                        value: self.gatewayStore.presentation.connectionText,
                        color: self.gatewayStore.presentation.statusColor)
                    Divider().frame(height: 38)
                    self.gatewayFact(
                        icon: "server.rack",
                        title: "Address",
                        value: self.gatewayStore.presentation.addressText,
                        color: OpenClawBrand.accent)
                    Divider().frame(height: 38)
                    self.gatewayFact(
                        icon: "person.2.fill",
                        title: "Agents",
                        value: self.gatewayStore.presentation.agentCountText,
                        color: OpenClawBrand.accentHot)
                }
                .padding(.vertical, 7)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private func gatewayFact(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(title == "Connection" ? color : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    private var defaultChatSessionSection: some View {
        CommandPanel(padding: 12) {
            VStack(spacing: 10) {
                self.cardHeader(title: "Agent session")

                Button {
                    self.open(.chat(.defaultSession))
                } label: {
                    CommandSessionRow(item: self.defaultChatWorkItem)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentSessions: some View {
        CommandPanel(padding: 12) {
            VStack(spacing: 10) {
                self.cardHeader(title: "Recent sessions")

                if self.recentSessionPreviewRows.isEmpty {
                    CommandEmptyStateRow(
                        icon: self.gatewayStore.presentation.recentSessionsEmptyIcon,
                        title: self.gatewayStore.presentation.recentSessionsEmptyTitle,
                        detail: self.gatewayStore.presentation.recentSessionsEmptyDetail)
                } else {
                    VStack(spacing: 8) {
                        ForEach(self.recentSessionPreviewRows) { item in
                            Button {
                                self.open(item.route)
                            } label: {
                                CommandSessionRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }

                        if self.hasMoreRecentSessions {
                            if let openSessions {
                                Button(action: openSessions) {
                                    CommandViewMoreRow()
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    CommandSessionsScreen(
                                        openChat: self.openChat,
                                        store: CommandSessionsStoreFactory.live(appModel: self.appModel))
                                } label: {
                                    CommandViewMoreRow()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func cardHeader(title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
        }
    }

    private var currentGatewayPresentation: CommandCenterGatewayPresentationState {
        CommandCenterGatewayPresentationState(
            gatewayDisplayState: GatewayStatusBuilder.build(appModel: self.appModel),
            gatewayRemoteAddress: self.appModel.gatewayRemoteAddress,
            gatewayServerName: self.appModel.gatewayServerName,
            gatewayAgentCount: self.appModel.gatewayAgents.count,
            activeAgentName: self.appModel.activeAgentName,
            gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText)
    }

    private func syncGatewayPresentation() {
        let presentation = self.currentGatewayPresentation
        guard self.gatewayStore.presentation != presentation else { return }
        self.gatewayStore.send(.presentationChanged(.init(presentation: presentation)))
    }

    private var defaultChatWorkItem: WorkItem {
        let isOpen = self.appModel.chatSessionKey == self.appModel.defaultChatSessionKey
        return WorkItem(
            id: "default-chat",
            icon: isOpen ? "bubble.left.and.text.bubble.right.fill" : "bubble.left.fill",
            title: self.appModel.activeAgentName,
            detail: self.defaultChatActivityText,
            state: isOpen ? "open" : "default",
            trailing: "chat",
            color: isOpen ? OpenClawBrand.accent : OpenClawBrand.ok,
            progress: nil,
            route: .chat(.defaultSession))
    }

    private var defaultChatActivityText: String {
        guard let updatedAt = recentSessionsStore.defaultChatSessionEntry?.updatedAt, updatedAt > 0 else {
            return "No recent activity"
        }
        return Self.relativeTimeText(forMilliseconds: updatedAt)
    }

    private var recentSessionRows: [WorkItem] {
        self.sessionItems
    }

    private var recentSessionPreviewRows: [WorkItem] {
        Array(self.recentSessionRows.prefix(3))
    }

    private var hasMoreRecentSessions: Bool {
        self.sessionWorkItems.count > self.recentSessionPreviewRows.count
    }

    private var recentSessionsRefreshID: String {
        [
            self.sessionListMode,
            self.appModel.chatSessionKey,
            self.scenePhase == .active ? "active" : "inactive",
        ].joined(separator: ":")
    }

    private var sessionListAvailable: Bool {
        self.appModel.isLocalChatFixtureEnabled || self.appModel.isOperatorGatewayConnected
    }

    private var sessionListMode: String {
        self.appModel.chatTransportModeID
    }

    private var sessionItems: [WorkItem] {
        self.sessionWorkItems
    }

    private var sessionWorkItems: [WorkItem] {
        let currentSessionKey = self.appModel.chatSessionKey
        return self.recentSessionsStore.recentChatSessions
            .filter { Self.isRecentChatSession($0.key, defaultSessionKey: self.appModel.defaultChatSessionKey) }
            .map { session in
                Self.sessionWorkItem(for: session, currentSessionKey: currentSessionKey)
            }
    }

    private func open(_ route: WorkRoute) {
        switch route {
        case let .chat(route):
            self.appModel.openChat(sessionKey: route.sessionKey)
            self.openChat()
        case .settings:
            self.openSettings()
        }
    }

    private func refreshRecentSessionsIfNeeded() async {
        await self.recentSessionsStore.send(.refreshRequested(.init(
            sceneActive: self.scenePhase == .active,
            sessionsAvailable: self.sessionListAvailable,
            currentSessionKey: self.appModel.chatSessionKey,
            defaultSessionKey: self.appModel.defaultChatSessionKey))).finish()
    }

    static func sessionWorkItem(
        for session: OpenClawChatSessionEntry,
        currentSessionKey: String) -> WorkItem
    {
        let isCurrent = session.key == currentSessionKey
        return WorkItem(
            id: "chat-session-\(session.key)",
            icon: isCurrent ? "bubble.left.and.text.bubble.right.fill" : "bubble.left.fill",
            title: Self.sessionTitle(session),
            detail: Self.sessionDetail(session),
            state: isCurrent ? "open" : "recent",
            trailing: "chat",
            color: isCurrent ? OpenClawBrand.accent : OpenClawBrand.ok,
            progress: nil,
            route: .chat(.recentSession(session.key)))
    }

    fileprivate static func sessionTitle(_ session: OpenClawChatSessionEntry) -> String {
        if let title = redactedSessionTitle(for: session.key) {
            return title
        }

        let displayName = session.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let displayName, !displayName.isEmpty {
            return Self.redactedSessionTitle(for: displayName) ?? displayName
        }
        let subject = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let subject, !subject.isEmpty {
            return Self.redactedSessionTitle(for: subject) ?? subject
        }
        return session.key
    }

    fileprivate static func redactedSessionTitle(for key: String) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        guard !trimmed.isEmpty else { return nil }
        if lowercased.contains(":ios-") {
            return "iOS chat"
        }
        if lowercased.hasPrefix("telegram:") {
            return "Telegram chat"
        }
        if lowercased.hasPrefix("user:+") {
            return "Direct chat"
        }
        if lowercased.hasPrefix("cron:") {
            return Self.humanizedSessionKey(String(trimmed.dropFirst("cron:".count)))
        }
        return nil
    }

    fileprivate static func humanizedSessionKey(_ key: String) -> String? {
        let words = key
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }

        return words
            .map { word in
                switch word.lowercased() {
                case "ai", "api", "ios", "qmd", "url":
                    word.uppercased()
                default:
                    word.prefix(1).uppercased() + String(word.dropFirst())
                }
            }
            .joined(separator: " ")
    }

    fileprivate static func sessionDetail(_ session: OpenClawChatSessionEntry) -> String {
        if let updatedAt = session.updatedAt, updatedAt > 0 {
            return self.relativeTimeText(forMilliseconds: updatedAt)
        }
        return session.key
    }

    fileprivate static func relativeTimeText(forMilliseconds milliseconds: Double) -> String {
        let date = Date(timeIntervalSince1970: milliseconds / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    fileprivate nonisolated static func isHiddenInternalSession(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed == "onboarding" || trimmed.hasSuffix(":onboarding")
    }

    nonisolated static func isRecentChatSession(_ key: String, defaultSessionKey: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed == defaultSessionKey { return false }
        let normalized = trimmed.lowercased()
        let defaultBase = self.sessionBaseKey(defaultSessionKey)
        if !normalized.contains(":"),
           self.isDirectSessionBase(normalized, defaultBase: defaultBase)
        {
            return false
        }
        if self.isHiddenInternalSession(trimmed) { return false }
        return !self.isAgentDeviceSession(trimmed, defaultSessionKey: defaultSessionKey)
    }

    private nonisolated static func isAgentDeviceSession(_ key: String, defaultSessionKey: String) -> Bool {
        let parts = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts[0].lowercased() == "agent" else { return false }
        guard parts.count == 3 || parts[3].lowercased() == "thread" else { return false }

        let base = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let defaultKey = self.sessionBaseKey(defaultSessionKey)
        return self.isDirectSessionBase(base, defaultBase: defaultKey)
    }

    private nonisolated static func isDirectSessionBase(_ base: String, defaultBase: String) -> Bool {
        base == defaultBase || base == "main" || base == "global" || base.hasPrefix("node-")
    }

    private nonisolated static func sessionBaseKey(_ key: String) -> String {
        let parts = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts[0].lowercased() == "agent" else {
            return key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

@Reducer
struct CommandCenterGatewayPresentationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var presentation = CommandCenterGatewayPresentationState()
    }

    enum Action: Equatable, Sendable {
        struct PresentationChange: Equatable, Sendable {
            var presentation: CommandCenterGatewayPresentationState
        }

        case presentationChanged(PresentationChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .presentationChanged(change):
                state.presentation = change.presentation
                return .none
            }
        }
        .autoLogActions()
    }
}

struct CommandCenterGatewayPresentationState: Equatable {
    var gatewayDisplayState: GatewayDisplayState = .disconnected
    var gatewayRemoteAddress: String?
    var gatewayServerName: String?
    var gatewayAgentCount = 0
    var activeAgentName = "Default Agent"
    var gatewayDisplayStatusText = "Offline"

    var isConnected: Bool {
        self.gatewayDisplayState == .connected
    }

    var connectionText: String {
        switch self.gatewayDisplayState {
        case .connected:
            "Online"
        case .connecting:
            "Connecting"
        case .error:
            "Attention"
        case .disconnected:
            "Offline"
        }
    }

    var statusColor: Color {
        switch self.gatewayDisplayState {
        case .connected:
            OpenClawBrand.ok
        case .connecting:
            OpenClawBrand.accent
        case .error:
            OpenClawBrand.warn
        case .disconnected:
            .secondary
        }
    }

    var addressText: String {
        Self.normalized(self.gatewayRemoteAddress)
            ?? Self.normalized(self.gatewayServerName)
            ?? "Unknown"
    }

    var agentCountText: String {
        guard self.isConnected else { return "—" }
        return "\(self.gatewayAgentCount)"
    }

    var gatewaySubtitle: String {
        if let server = Self.normalized(self.gatewayServerName) {
            return "\(self.activeAgentName) on \(server)"
        }
        if let address = Self.normalized(self.gatewayRemoteAddress) {
            return "\(self.activeAgentName) via \(address)"
        }
        return self.gatewayDisplayStatusText
    }

    var recentSessionsEmptyIcon: String {
        self.isConnected ? "bubble.left.and.text.bubble.right.fill" : "wifi.slash"
    }

    var recentSessionsEmptyTitle: String {
        self.isConnected ? "No recent sessions" : "Gateway offline"
    }

    var recentSessionsEmptyDetail: String {
        self.isConnected ? "Start a chat and it will appear here." : "Connect to the gateway."
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct CommandSessionsScreen: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<CommandSessionsFeature>
    let headerLeadingAction: OpenClawSidebarHeaderAction?
    let openChat: () -> Void

    init(
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        openChat: @escaping () -> Void,
        store: StoreOf<CommandSessionsFeature> = Store(initialState: CommandSessionsFeature.State()) {
            CommandSessionsFeature()
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.openChat = openChat
        self._store = State(wrappedValue: store)
    }

    var body: some View {
        ZStack {
            CommandControlBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    self.header
                    self.sessionsPanel
                }
                .padding(.top, 16)
                .padding(.bottom, 18)
            }
            .safeAreaPadding(.bottom, OpenClawProMetric.bottomScrollInset)
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: self.refreshID) {
            await self.refreshSessions()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if let headerLeadingAction {
                OpenClawSidebarHeaderLeadingSlot(action: headerLeadingAction)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Sessions")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text(self.headerDetail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var sessionsPanel: some View {
        CommandPanel(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Recent sessions")
                        .font(.subheadline.weight(.bold))
                    Spacer(minLength: 8)
                    if self.store.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 3)

                if let loadErrorText = self.store.loadErrorText {
                    CommandEmptyStateRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Sessions unavailable",
                        detail: loadErrorText)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                } else if self.sessionRows.isEmpty {
                    CommandEmptyStateRow(
                        icon: self.appModel
                            .isCommandSessionListAvailable ? "bubble.left.and.text.bubble.right.fill" : "wifi.slash",
                        title: self.appModel.isCommandSessionListAvailable ? "No recent sessions" : "Gateway offline",
                        detail: self.appModel
                            .isCommandSessionListAvailable ? "Start a chat and it will appear here." :
                            "Connect to the gateway.")
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                } else {
                    VStack(spacing: 8) {
                        ForEach(self.sessionRows) { item in
                            Button {
                                self.open(item)
                            } label: {
                                CommandSessionRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var headerDetail: String {
        if self.store.isLoading, self.store.sessions.isEmpty { return "Loading recent sessions" }
        let count = self.sessionRows.count
        if count == 0 {
            return self.appModel.isCommandSessionListAvailable ? "No recent sessions" : "Gateway offline"
        }
        return "\(count) \(count == 1 ? "session" : "sessions")"
    }

    private var sessionRows: [CommandCenterTab.WorkItem] {
        self.store.sessions
            .filter { CommandCenterTab.isRecentChatSession(
                $0.key,
                defaultSessionKey: self.appModel.defaultChatSessionKey) }
            .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
            .map {
                CommandCenterTab.sessionWorkItem(
                    for: $0,
                    currentSessionKey: self.appModel.chatSessionKey)
            }
    }

    private var refreshID: String {
        self.appModel.commandSessionListMode
    }

    private func open(_ item: CommandCenterTab.WorkItem) {
        switch item.route {
        case let .chat(route):
            self.appModel.openChat(sessionKey: route.sessionKey)
            self.dismiss()
            self.openChat()
        case .settings:
            break
        }
    }

    private func refreshSessions() async {
        await self.store.send(.refreshRequested(.init(
            sessionsAvailable: self.appModel.isCommandSessionListAvailable))).finish()
    }
}

extension NodeAppModel {
    fileprivate var isCommandSessionListAvailable: Bool {
        self.isLocalChatFixtureEnabled || self.isOperatorGatewayConnected
    }

    fileprivate var commandSessionListMode: String {
        self.chatTransportModeID
    }
}
