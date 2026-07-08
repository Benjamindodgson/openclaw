import ComposableArchitecture
import OpenClawChatUI
import OpenClawProtocol
import SwiftUI

// swiftformat:disable redundantSendable
struct ChatTransportModeID: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

struct ChatProTab: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: OpenClawChatViewModel?
    @State private var viewModelLifecycleStore: StoreOf<ChatViewModelLifecycleFeature>
    @State private var presentationStore: StoreOf<ChatProPresentationFeature>
    @State private var talkControlStore: StoreOf<ChatTalkControlFeature>
    let headerLeadingAction: OpenClawSidebarHeaderAction?
    let headerTitle: String?
    let headerSubtitle: String?
    let showsAgentBadge: Bool
    let ownsNavigationStack: Bool
    let openSettings: (() -> Void)?

    init(
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        headerTitle: String? = nil,
        headerSubtitle: String? = nil,
        showsAgentBadge: Bool = true,
        ownsNavigationStack: Bool = true,
        openSettings: (() -> Void)? = nil,
        viewModelLifecycleStore: StoreOf<ChatViewModelLifecycleFeature>? = nil,
        viewModelLifecycleStoreFactory: () -> StoreOf<ChatViewModelLifecycleFeature> = {
            Store(initialState: ChatViewModelLifecycleFeature.State()) {
                ChatViewModelLifecycleFeature()
            }
        },
        presentationStore: StoreOf<ChatProPresentationFeature>? = nil,
        presentationStoreFactory: () -> StoreOf<ChatProPresentationFeature> = {
            Store(initialState: ChatProPresentationFeature.State()) {
                ChatProPresentationFeature()
            }
        },
        talkControlStore: StoreOf<ChatTalkControlFeature>? = nil,
        talkControlStoreFactory: () -> StoreOf<ChatTalkControlFeature> = {
            Store(initialState: ChatTalkControlFeature.State()) {
                ChatTalkControlFeature()
            }
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.showsAgentBadge = showsAgentBadge
        self.ownsNavigationStack = ownsNavigationStack
        self.openSettings = openSettings
        let resolvedViewModelLifecycleStore = viewModelLifecycleStore ?? viewModelLifecycleStoreFactory()
        let resolvedPresentationStore = presentationStore ?? presentationStoreFactory()
        let resolvedTalkControlStore = talkControlStore ?? talkControlStoreFactory()
        self._viewModelLifecycleStore = State(wrappedValue: resolvedViewModelLifecycleStore)
        self._presentationStore = State(wrappedValue: resolvedPresentationStore)
        self._talkControlStore = State(wrappedValue: resolvedTalkControlStore)
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
        .task {
            self.syncPresentationState()
            self.syncChatViewModel()
        }
        .onChange(of: self.currentPresentationSnapshot) { _, _ in
            self.syncPresentationState()
        }
        .onChange(of: self.appModel.chatSessionKey) { _, _ in
            self.syncChatViewModel()
        }
        .onChange(of: self.appModel.isAppleReviewDemoModeEnabled) { _, _ in
            self.syncChatViewModel()
            self.viewModel?.refresh()
        }
        .onChange(of: self.appModel.isScreenshotFixtureModeEnabled) { _, _ in
            self.syncChatViewModel()
            self.viewModel?.refresh()
        }
        .onChange(of: self.appModel.isOperatorGatewayConnected) { _, connected in
            guard connected else { return }
            self.syncChatViewModel()
            self.viewModel?.refresh()
        }
    }

    private var content: some View {
        ZStack {
            OpenClawProBackground()
            VStack(spacing: 0) {
                self.header
                if let viewModel {
                    OpenClawChatView(
                        viewModel: viewModel,
                        drawsBackground: false,
                        showsSessionSwitcher: false,
                        userAccent: self.chatUserAccent,
                        assistantName: self.presentationState.agentDisplayName,
                        assistantAvatarText: self.presentationState.agentBadge,
                        assistantAvatarTint: OpenClawBrand.accent,
                        showsAssistantAvatars: false,
                        composerChrome: .clean,
                        isComposerEnabled: self.gatewayConnected,
                        messagePlaceholder: self.presentationState.messagePlaceholder,
                        talkControl: self.talkControl)
                        .id(ObjectIdentifier(viewModel))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ProCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Chat is preparing")
                                .font(.headline)
                            Text("The operator session will attach when the gateway is ready.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaPadding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarHidden(true)
    }

    private var header: some View {
        OpenClawAdaptiveHeaderRow(
            title: self.presentationState.headerDisplayTitle,
            subtitle: self.presentationState.headerDisplaySubtitle,
            titleFont: .headline.weight(.semibold),
            subtitleFont: .caption,
            subtitleLineLimit: 1)
        {
            HStack(spacing: 11) {
                if let headerLeadingAction {
                    OpenClawSidebarHeaderLeadingSlot(action: headerLeadingAction)
                }
                self.headerIdentityBadge
            }
        } accessory: {
            self.connectionPillButton
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var headerIdentityBadge: some View {
        if self.showsAgentBadge {
            let badge = self.presentationState.agentBadge
            Text(badge)
                .font(.system(size: badge.count > 2 ? 13 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(OpenClawBrand.accent.gradient))
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: OpenClawBrand.accent.opacity(0.14), radius: 5, y: 2)
        } else {
            ProIconBadge(systemName: "bubble.left", color: OpenClawBrand.accent)
        }
    }

    private func syncChatViewModel() {
        let sessionKey = self.appModel.chatSessionKey
        let transportModeID = self.appModel.chatTransportModeID
        guard let viewModel else {
            self.viewModelLifecycleStore.send(.transportModeRecorded(.init(
                transportModeID: .init(value: transportModeID))))
            self.viewModel = OpenClawChatViewModel(
                sessionKey: sessionKey,
                transport: self.appModel.makeChatTransport(),
                onSessionChanged: { sessionKey in
                    self.appModel.focusChatSession(sessionKey)
                },
                diagnosticsLog: { message in
                    GatewayDiagnostics.log(message)
                })
            return
        }
        if self.viewModelTransportModeID != transportModeID {
            self.viewModelLifecycleStore.send(.transportModeRecorded(.init(
                transportModeID: .init(value: transportModeID))))
            self.viewModel = OpenClawChatViewModel(
                sessionKey: sessionKey,
                transport: self.appModel.makeChatTransport(),
                onSessionChanged: { sessionKey in
                    self.appModel.focusChatSession(sessionKey)
                },
                diagnosticsLog: { message in
                    GatewayDiagnostics.log(message)
                })
            return
        }
        guard viewModel.sessionKey != sessionKey else { return }
        viewModel.syncSession(to: sessionKey)
    }

    private var viewModelTransportModeID: String {
        self.viewModelLifecycleStore.transportModeID
    }

    private var talkControl: OpenClawChatTalkControl {
        OpenClawChatTalkControl(
            isEnabled: self.appModel.talkMode.isEnabled,
            isListening: self.appModel.talkMode.isListening,
            isSpeaking: self.appModel.talkMode.isSpeaking,
            isGatewayConnected: self.appModel.talkMode.isGatewayConnected,
            statusText: self.appModel.talkMode.statusText,
            providerLabel: self.appModel.talkMode.gatewayTalkProviderLabel,
            toggle: { sessionKey in
                self.talkControlStore.send(.toggleRequested(.init(
                    sessionKey: ChatSessionKey(rawValue: sessionKey),
                    talkEnabled: .init(isEnabled: self.appModel.talkMode.isEnabled))))
            })
    }

    @ViewBuilder
    private var connectionPillButton: some View {
        if let openSettings {
            Button(action: openSettings) {
                self.connectionPill
            }
            .buttonBorderShape(.capsule)
            .openClawGlassButton()
            .accessibilityHint("Opens Settings / Gateway")
        } else {
            self.connectionPill
        }
    }

    private var connectionPill: some View {
        HStack(spacing: 6) {
            ProStatusDot(color: self.presentationState.gatewayPillColor)
            Text(self.presentationState.gatewayPillTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(self.presentationState.gatewayPillColor)
        .padding(.horizontal, 4)
        .frame(height: 30)
    }

    private var presentationState: ChatProPresentationState {
        let current = self.currentPresentationState
        guard self.presentationStore.presentation == current else {
            return current
        }
        return self.presentationStore.presentation
    }

    private var currentPresentationState: ChatProPresentationState {
        .init(snapshot: self.currentPresentationSnapshot)
    }

    private var currentPresentationSnapshot: ChatProPresentationSnapshot {
        ChatProPresentationSnapshot(
            gatewayDisplayState: self.gatewayDisplayState,
            isGatewayUsable: self.gatewayConnected,
            activeAgentID: self.appModel.chatAgentId,
            fallbackAgentDisplayName: self.appModel.chatAgentName,
            agents: self.appModel.gatewayAgents.map(ChatProAgentEntry.init(agent:)),
            headerTitle: self.headerTitle,
            headerSubtitle: self.headerSubtitle,
            showsAgentBadge: self.showsAgentBadge)
    }

    private func syncPresentationState() {
        let snapshot = self.currentPresentationSnapshot
        guard self.presentationStore.snapshot != snapshot else { return }
        self.presentationStore.send(.snapshotChanged(.init(snapshot: snapshot)))
    }

    private var gatewayConnected: Bool {
        guard self.gatewayDisplayState == .connected else {
            return false
        }
        return self.appModel.isLocalChatFixtureEnabled || self.appModel.isOperatorGatewayConnected
    }

    private var gatewayDisplayState: GatewayDisplayState {
        GatewayStatusBuilder.build(appModel: self.appModel)
    }

    private var chatUserAccent: Color {
        self.colorScheme == .light ? OpenClawBrand.info : OpenClawBrand.accent
    }
}

// swiftformat:disable redundantSendable
struct ChatTalkControlClient: Sendable {
    var focusChatSession: @MainActor @Sendable (ChatSessionKey?) -> Void
    var setTalkEnabled: @MainActor @Sendable (Bool) -> Void
}

// swiftformat:enable redundantSendable

extension ChatTalkControlClient: DependencyKey {
    static let liveValue = ChatTalkControlClient(
        focusChatSession: { _ in },
        setTalkEnabled: { _ in })
    static let testValue = ChatTalkControlClient(
        focusChatSession: { _ in },
        setTalkEnabled: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        ChatTalkControlClient(
            focusChatSession: { sessionKey in
                appModel.focusChatSession(sessionKey?.value)
            },
            setTalkEnabled: { enabled in
                appModel.setTalkEnabled(enabled)
            })
    }
}

extension DependencyValues {
    var chatTalkControl: ChatTalkControlClient {
        get { self[ChatTalkControlClient.self] }
        set { self[ChatTalkControlClient.self] = newValue }
    }
}

@Reducer
struct ChatTalkControlFeature {
    private let clientOverride: ChatTalkControlClient?

    init(client: ChatTalkControlClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        struct TalkEnabled: Equatable, Sendable {
            var isEnabled: Bool
        }

        struct ToggleRequest: Equatable, Sendable {
            var sessionKey: ChatSessionKey?
            var talkEnabled: TalkEnabled
        }

        case toggleRequested(ToggleRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.chatTalkControl) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .toggleRequested(request):
                return .run { [client] _ in
                    await client.focusChatSession(request.sessionKey)
                    await client.setTalkEnabled(!request.talkEnabled.isEnabled)
                }
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct ChatViewModelLifecycleFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var transportMode = ChatTransportModeID(value: "")

        var transportModeID: String {
            self.transportMode.value
        }
    }

    enum Action: Equatable, Sendable {
        struct TransportModeRecord: Equatable, Sendable { var transportModeID: ChatTransportModeID }

        case transportModeRecorded(TransportModeRecord)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .transportModeRecorded(record):
                state.transportMode = record.transportModeID
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct ChatProPresentationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var snapshot = ChatProPresentationSnapshot()

        var presentation: ChatProPresentationState {
            .init(snapshot: self.snapshot)
        }
    }

    enum Action: Equatable, Sendable {
        struct SnapshotChange: Equatable, Sendable {
            var snapshot: ChatProPresentationSnapshot
        }

        case snapshotChanged(SnapshotChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .snapshotChanged(change):
                state.snapshot = change.snapshot
                return .none
            }
        }
        .autoLogActions()
    }
}

// swiftformat:disable redundantSendable
struct ChatProGatewayUsability: Equatable, Sendable { var value: Bool }
struct ChatProActiveAgentID: Equatable, Sendable { var value: String }
struct ChatProFallbackAgentDisplayName: Equatable, Sendable { var value: String }
struct ChatProAgentDisplayName: Equatable, Sendable { var value: String }
struct ChatProHeaderTitle: Equatable, Sendable { var value: String? }
struct ChatProHeaderSubtitle: Equatable, Sendable { var value: String? }
struct ChatProShowsAgentBadge: Equatable, Sendable { var value: Bool }
struct ChatProAgentBadgeOverride: Equatable, Sendable { var value: String? }
// swiftformat:enable redundantSendable

// swiftformat:disable redundantSendable
struct ChatProAgentEntry: Equatable, Sendable {
    var id: String
    var name: String?
    var emoji: String?
}

// swiftformat:enable redundantSendable

extension ChatProAgentEntry {
    init(agent: AgentSummary) {
        self.init(
            id: agent.id,
            name: agent.name,
            emoji: agent.identity?["emoji"]?.value as? String)
    }
}

// swiftformat:disable redundantSendable
struct ChatProAgentEntries: Equatable, Sendable { var values: [ChatProAgentEntry] = [] }
// swiftformat:enable redundantSendable

// swiftformat:disable redundantSendable
struct ChatProPresentationSnapshot: Equatable, Sendable {
    var gatewayDisplayState: GatewayDisplayState = .disconnected
    var gatewayUsabilityValue = ChatProGatewayUsability(value: false)
    var activeAgentIDValue = ChatProActiveAgentID(value: "main")
    var fallbackAgentDisplayNameValue = ChatProFallbackAgentDisplayName(value: "OpenClaw")
    var agentEntries = ChatProAgentEntries()
    var headerTitleValue = ChatProHeaderTitle(value: nil)
    var headerSubtitleValue = ChatProHeaderSubtitle(value: nil)
    var showsAgentBadgeValue = ChatProShowsAgentBadge(value: true)

    init(
        gatewayDisplayState: GatewayDisplayState = .disconnected,
        isGatewayUsable: Bool = false,
        activeAgentID: String = "main",
        fallbackAgentDisplayName: String = "OpenClaw",
        agents: [ChatProAgentEntry] = [],
        headerTitle: String? = nil,
        headerSubtitle: String? = nil,
        showsAgentBadge: Bool = true)
    {
        self.gatewayDisplayState = gatewayDisplayState
        self.gatewayUsabilityValue = .init(value: isGatewayUsable)
        self.activeAgentIDValue = .init(value: activeAgentID)
        self.fallbackAgentDisplayNameValue = .init(value: fallbackAgentDisplayName)
        self.agentEntries = .init(values: agents)
        self.headerTitleValue = .init(value: headerTitle)
        self.headerSubtitleValue = .init(value: headerSubtitle)
        self.showsAgentBadgeValue = .init(value: showsAgentBadge)
    }

    var isGatewayUsable: Bool {
        self.gatewayUsabilityValue.value
    }

    var activeAgentID: String {
        Self.normalized(self.activeAgentIDValue.value) ?? "main"
    }

    var fallbackAgentDisplayName: String {
        self.fallbackAgentDisplayNameValue.value
    }

    var agents: [ChatProAgentEntry] {
        self.agentEntries.values
    }

    var headerTitle: String? {
        self.headerTitleValue.value
    }

    var headerSubtitle: String? {
        self.headerSubtitleValue.value
    }

    var showsAgentBadge: Bool {
        self.showsAgentBadgeValue.value
    }

    var activeAgent: ChatProAgentEntry? {
        self.agents.first { $0.id == self.activeAgentID }
    }

    var resolvedAgentDisplayName: String {
        if let name = Self.normalized(self.activeAgent?.name) {
            return name
        }
        return self.fallbackAgentDisplayName
    }

    var resolvedAgentBadgeOverride: String? {
        self.activeAgent?.emoji
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// swiftformat:enable redundantSendable

// swiftformat:disable redundantSendable
struct ChatProPresentationState: Equatable, Sendable {
    var gatewayDisplayState: GatewayDisplayState = .disconnected
    var gatewayUsabilityValue = ChatProGatewayUsability(value: false)
    var agentDisplayNameValue = ChatProAgentDisplayName(value: "OpenClaw")
    var headerTitleValue = ChatProHeaderTitle(value: nil)
    var headerSubtitleValue = ChatProHeaderSubtitle(value: nil)
    var showsAgentBadgeValue = ChatProShowsAgentBadge(value: true)
    var agentBadgeOverrideValue = ChatProAgentBadgeOverride(value: nil)

    init(
        gatewayDisplayState: GatewayDisplayState = .disconnected,
        isGatewayUsable: Bool = false,
        agentDisplayName: String = "OpenClaw",
        headerTitle: String? = nil,
        headerSubtitle: String? = nil,
        showsAgentBadge: Bool = true,
        agentBadgeOverride: String? = nil)
    {
        self.gatewayDisplayState = gatewayDisplayState
        self.gatewayUsabilityValue = .init(value: isGatewayUsable)
        self.agentDisplayNameValue = .init(value: agentDisplayName)
        self.headerTitleValue = .init(value: headerTitle)
        self.headerSubtitleValue = .init(value: headerSubtitle)
        self.showsAgentBadgeValue = .init(value: showsAgentBadge)
        self.agentBadgeOverrideValue = .init(value: agentBadgeOverride)
    }

    init(snapshot: ChatProPresentationSnapshot) {
        self.init(
            gatewayDisplayState: snapshot.gatewayDisplayState,
            isGatewayUsable: snapshot.isGatewayUsable,
            agentDisplayName: snapshot.resolvedAgentDisplayName,
            headerTitle: snapshot.headerTitle,
            headerSubtitle: snapshot.headerSubtitle,
            showsAgentBadge: snapshot.showsAgentBadge,
            agentBadgeOverride: snapshot.resolvedAgentBadgeOverride)
    }

    var agentDisplayName: String {
        self.agentDisplayNameValue.value
    }

    var isGatewayUsable: Bool {
        self.gatewayUsabilityValue.value
    }

    var headerTitle: String? {
        self.headerTitleValue.value
    }

    var headerSubtitle: String? {
        self.headerSubtitleValue.value
    }

    var showsAgentBadge: Bool {
        self.showsAgentBadgeValue.value
    }

    var agentBadgeOverride: String? {
        self.agentBadgeOverrideValue.value
    }

    var gatewayPillTitle: String {
        switch self.gatewayDisplayState {
        case .connected:
            self.isGatewayUsable ? "Connected" : "Unavailable"
        case .connecting:
            "Connecting"
        case .error:
            "Attention"
        case .disconnected:
            "Offline"
        }
    }

    var gatewayPillColor: Color {
        switch self.gatewayDisplayState {
        case .connected:
            self.isGatewayUsable ? OpenClawBrand.ok : .secondary
        case .connecting:
            OpenClawBrand.accent
        case .error:
            OpenClawBrand.warn
        case .disconnected:
            .secondary
        }
    }

    var messagePlaceholder: String {
        self.isGatewayUsable ? "Message \(self.agentDisplayName)..." : "Connect to a gateway"
    }

    var headerDisplayTitle: String {
        Self.normalized(self.headerTitle)
            ?? Self.defaultHeaderTitle(showsAgentBadge: self.showsAgentBadge, agentDisplayName: self.agentDisplayName)
    }

    var headerDisplaySubtitle: String? {
        Self.normalized(self.headerSubtitle)
    }

    var agentBadge: String {
        if let badge = Self.normalized(self.agentBadgeOverride) {
            return badge
        }
        let words = self.agentDisplayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .prefix(2)
        let initials = words.compactMap(\.first).map(String.init).joined()
        if !initials.isEmpty {
            return initials.uppercased()
        }
        return "OC"
    }

    nonisolated static func defaultHeaderTitle(showsAgentBadge: Bool, agentDisplayName: String) -> String {
        showsAgentBadge ? agentDisplayName : "Chat"
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// swiftformat:enable redundantSendable
