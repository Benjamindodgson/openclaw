import ComposableArchitecture
import OpenClawChatUI
import OpenClawProtocol
import SwiftUI

struct ChatProTab: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: OpenClawChatViewModel?
    @State private var viewModelLifecycleStore: StoreOf<ChatViewModelLifecycleFeature>
    @State private var presentationStore: StoreOf<ChatProPresentationFeature>
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
        viewModelLifecycleStore: StoreOf<ChatViewModelLifecycleFeature> = Store(
            initialState: ChatViewModelLifecycleFeature.State())
        {
            ChatViewModelLifecycleFeature()
        },
        presentationStore: StoreOf<ChatProPresentationFeature> = Store(
            initialState: ChatProPresentationFeature.State())
        {
            ChatProPresentationFeature()
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.showsAgentBadge = showsAgentBadge
        self.ownsNavigationStack = ownsNavigationStack
        self.openSettings = openSettings
        self._viewModelLifecycleStore = State(wrappedValue: viewModelLifecycleStore)
        self._presentationStore = State(wrappedValue: presentationStore)
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
        .onChange(of: self.currentPresentationState) { _, _ in
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
                        assistantName: self.agentDisplayName,
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
            self.viewModelLifecycleStore.send(.transportModeRecorded(transportModeID))
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
            self.viewModelLifecycleStore.send(.transportModeRecorded(transportModeID))
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
                self.appModel.focusChatSession(sessionKey)
                self.appModel.setTalkEnabled(!self.appModel.talkMode.isEnabled)
            })
    }

    private var activeAgentID: String {
        self.normalized(self.appModel.chatAgentId)
            ?? "main"
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
        ChatProPresentationState(
            gatewayDisplayState: self.gatewayDisplayState,
            isGatewayUsable: self.gatewayConnected,
            agentDisplayName: self.agentDisplayName,
            headerTitle: self.headerTitle,
            headerSubtitle: self.headerSubtitle,
            showsAgentBadge: self.showsAgentBadge,
            agentBadgeOverride: self.agentBadgeOverride)
    }

    private func syncPresentationState() {
        let presentation = self.currentPresentationState
        guard self.presentationStore.presentation != presentation else { return }
        self.presentationStore.send(.presentationChanged(presentation))
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

    private var activeAgent: AgentSummary? {
        self.appModel.gatewayAgents.first { $0.id == self.activeAgentID }
    }

    private var agentDisplayName: String {
        self.normalized(self.activeAgent?.name) ?? self.appModel.chatAgentName
    }

    private var agentBadgeOverride: String? {
        if let identity = self.activeAgent?.identity,
           let emoji = identity["emoji"]?.value as? String
        {
            return emoji
        }
        return nil
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@Reducer
struct ChatViewModelLifecycleFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var transportModeID = ""
    }

    enum Action: Equatable, Sendable {
        case transportModeRecorded(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .transportModeRecorded(transportModeID):
                state.transportModeID = transportModeID
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
        var presentation = ChatProPresentationState()
    }

    enum Action: Equatable, Sendable {
        case presentationChanged(ChatProPresentationState)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .presentationChanged(presentation):
                state.presentation = presentation
                return .none
            }
        }
        .autoLogActions()
    }
}

struct ChatProPresentationState: Equatable {
    var gatewayDisplayState: GatewayDisplayState = .disconnected
    var isGatewayUsable = false
    var agentDisplayName = "OpenClaw"
    var headerTitle: String?
    var headerSubtitle: String?
    var showsAgentBadge = true
    var agentBadgeOverride: String?

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
