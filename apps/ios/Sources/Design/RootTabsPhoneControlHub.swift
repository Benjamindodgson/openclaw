import ComposableArchitecture
import OpenClawProtocol
import SwiftUI

@Reducer
struct RootTabsPhoneControlHubFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var navigationPath: [RootTabs.SidebarDestination] = []
        var didApplyInitialDestination = false
    }

    enum Action: Equatable, Sendable {
        case detailBackTapped
        case detailDestinationTapped(RootTabs.SidebarDestination)
        case initialDestinationAppeared(destination: RootTabs.SidebarDestination?, opensRootTab: Bool)
        case navigationPathChanged([RootTabs.SidebarDestination])
        case rootDestinationTapped(RootTabs.SidebarDestination)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .detailBackTapped:
                guard !state.navigationPath.isEmpty else { return .none }
                state.navigationPath.removeLast()
                return .none

            case let .detailDestinationTapped(destination):
                state.navigationPath.append(destination)
                return .none

            case let .initialDestinationAppeared(initialDestination, opensRootTab):
                guard !state.didApplyInitialDestination else { return .none }
                state.didApplyInitialDestination = true
                guard let initialDestination, initialDestination != .overview else { return .none }
                guard !opensRootTab else {
                    state.navigationPath = []
                    return .none
                }
                state.navigationPath = [initialDestination]
                return .none

            case let .navigationPathChanged(navigationPath):
                state.navigationPath = navigationPath
                return .none

            case .rootDestinationTapped:
                state.navigationPath = []
                return .none
            }
        }
        .autoLogActions()
    }
}

struct RootTabsPhoneControlHub: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var store: StoreOf<RootTabsPhoneControlHubFeature>

    let groups: [RootTabs.SidebarGroup]
    let initialDestination: RootTabs.SidebarDestination?
    let openRootDestination: (RootTabs.SidebarDestination) -> Void

    init(
        groups: [RootTabs.SidebarGroup],
        initialDestination: RootTabs.SidebarDestination?,
        openRootDestination: @escaping (RootTabs.SidebarDestination) -> Void,
        store: StoreOf<RootTabsPhoneControlHubFeature> = Store(
            initialState: RootTabsPhoneControlHubFeature.State())
        {
            RootTabsPhoneControlHubFeature()
        })
    {
        self.groups = groups
        self.initialDestination = initialDestination
        self.openRootDestination = openRootDestination
        self._store = State(wrappedValue: store)
    }

    var body: some View {
        NavigationStack(path: self.navigationPathBinding) {
            ZStack {
                OpenClawProBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: self.isCompactHeight ? 10 : 16) {
                        self.headerCard
                        ForEach(self.groups) { group in
                            self.groupSection(group)
                        }
                    }
                    .padding(.vertical, self.isCompactHeight ? 10 : 16)
                }
                .safeAreaPadding(.bottom, self.bottomScrollInset)
            }
            .navigationTitle("Control")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: RootTabs.SidebarDestination.self) { destination in
                self.detail(for: destination)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .onAppear {
                self.applyInitialDestinationIfNeeded()
            }
        }
    }

    private var navigationPathBinding: Binding<[RootTabs.SidebarDestination]> {
        Binding(
            get: { self.store.navigationPath },
            set: { self.store.send(.navigationPathChanged($0)) })
    }

    private var headerCard: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            Button {
                self.openPhoneRootDestination(.gateway)
            } label: {
                HStack(spacing: 12) {
                    OpenClawProMark(
                        size: self.isCompactHeight ? 28 : 34,
                        shadowRadius: self.isCompactHeight ? 3 : 5)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(self.sidebarActiveAgentTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(self.gatewayDisplayLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 7) {
                        ProStatusDot(color: self.gatewayStateColor)
                        Text(self.gatewayStateText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(self.gatewayStateColor)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(self.isCompactHeight ? 10 : 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Gateway \(self.gatewayStateText)")
            .accessibilityHint("Opens Settings / Gateway")
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private func groupSection(_ group: RootTabs.SidebarGroup) -> some View {
        VStack(alignment: .leading, spacing: self.isCompactHeight ? 6 : 8) {
            ProSectionHeader(title: group.title.capitalized, uppercase: false)
            ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
                VStack(spacing: 0) {
                    ForEach(Array(group.destinations.enumerated()), id: \.element.id) { index, destination in
                        if index > 0 {
                            Divider().padding(.leading, 58)
                        }
                        self.destinationRow(destination)
                    }
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    @ViewBuilder
    private func destinationRow(_ destination: RootTabs.SidebarDestination) -> some View {
        if self.opensRootTab(destination) {
            Button {
                self.openPhoneRootDestination(destination)
            } label: {
                self.rowLabel(destination)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                self.openPhoneDetailDestination(destination)
            } label: {
                self.rowLabel(destination)
            }
            .buttonStyle(.plain)
        }
    }

    private func rowLabel(_ destination: RootTabs.SidebarDestination) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ProIconBadge(systemName: destination.systemImage, color: .secondary)
            Text(destination.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, self.isCompactHeight ? 7 : 9)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func detail(for destination: RootTabs.SidebarDestination) -> some View {
        switch destination {
        case .chat, .talk, .agents, .gateway:
            EmptyView()
        case .overview:
            CommandCenterTab(
                ownsNavigationStack: false,
                headerTitle: "Overview",
                headerLeadingAction: self.phoneDetailBackAction,
                showsHeaderMark: false,
                openChat: { self.openPhoneRootDestination(.chat) },
                openSettings: { self.openPhoneRootDestination(.gateway) },
                openSessions: { self.openPhoneDetailDestination(.sessions) },
                recentSessionsStore: CommandCenterRecentSessionsStoreFactory.live(appModel: self.appModel))
        case .activity:
            IPadActivityScreen(
                headerLeadingAction: self.phoneDetailBackAction,
                openChat: { self.openPhoneRootDestination(.chat) },
                openSettings: { self.openPhoneRootDestination(.gateway) },
                store: IPadActivitySessionsStoreFactory.live(appModel: self.appModel))
        case .workboard:
            IPadWorkboardScreen(
                headerLeadingAction: self.phoneDetailBackAction,
                openChat: { self.openPhoneRootDestination(.chat) },
                openSettings: { self.openPhoneRootDestination(.gateway) },
                store: IPadWorkboardStoreFactory.live(appModel: self.appModel))
        case .skillWorkshop:
            IPadSkillWorkshopScreen(
                headerLeadingAction: self.phoneDetailBackAction,
                openSettings: { self.openPhoneRootDestination(.gateway) },
                store: IPadSkillWorkshopStoreFactory.live(appModel: self.appModel))
        case .instances:
            AgentProTab(
                directRoute: .instances,
                headerLeadingAction: self.phoneDetailBackAction,
                headerTitle: "Instances",
                openSettings: { self.openPhoneRootDestination(.gateway) })
        case .sessions:
            CommandSessionsScreen(
                headerLeadingAction: self.phoneDetailBackAction,
                openChat: { self.openPhoneRootDestination(.chat) },
                store: CommandSessionsStoreFactory.live(appModel: self.appModel))
        case .dreaming:
            AgentProTab(
                directRoute: .dreaming,
                headerLeadingAction: self.phoneDetailBackAction,
                headerTitle: "Dreaming",
                openSettings: { self.openPhoneRootDestination(.gateway) })
        case .usage:
            AgentProTab(
                directRoute: .usage,
                headerLeadingAction: self.phoneDetailBackAction,
                headerTitle: "Usage",
                openSettings: { self.openPhoneRootDestination(.gateway) })
        case .cron:
            AgentProTab(
                directRoute: .cron,
                headerLeadingAction: self.phoneDetailBackAction,
                headerTitle: "Cron Jobs",
                openSettings: { self.openPhoneRootDestination(.gateway) })
        case .docs:
            OpenClawDocsScreen(
                headerLeadingAction: self.phoneDetailBackAction,
                gatewayAction: { self.openPhoneRootDestination(.gateway) })
        case .settings:
            EmptyView()
        }
    }

    private var phoneDetailBackAction: OpenClawSidebarHeaderAction {
        OpenClawSidebarHeaderAction(
            systemName: "chevron.left",
            accessibilityLabel: "Back to Control",
            accessibilityIdentifier: "OpenClawPhoneDetailBackButton",
            action: { self.popPhoneDetail() })
    }

    private func popPhoneDetail() {
        self.store.send(.detailBackTapped)
    }

    private func openPhoneDetailDestination(_ destination: RootTabs.SidebarDestination) {
        self.store.send(.detailDestinationTapped(destination))
    }

    private func openPhoneRootDestination(_ destination: RootTabs.SidebarDestination) {
        self.store.send(.rootDestinationTapped(destination))
        self.openRootDestination(destination)
    }

    private func opensRootTab(_ destination: RootTabs.SidebarDestination) -> Bool {
        RootTabs.shouldOpenRootTabFromPhoneHub(destination)
    }

    private func applyInitialDestinationIfNeeded() {
        guard !self.store.didApplyInitialDestination else { return }
        let shouldOpenRoot = self.initialDestination.map(self.opensRootTab) ?? false
        self.store.send(.initialDestinationAppeared(
            destination: self.initialDestination,
            opensRootTab: shouldOpenRoot))
        guard let initialDestination, initialDestination != .overview else { return }
        if shouldOpenRoot {
            self.openRootDestination(initialDestination)
        }
    }

    private var sidebarActiveAgentTitle: String {
        let selectedID = self.normalized(self.appModel.selectedAgentId) ?? self.resolveDefaultAgentID()
        if let agent = self.appModel.gatewayAgents.first(where: { $0.id == selectedID }) {
            return self.agentTitle(for: agent)
        }
        return self.normalized(self.appModel.activeAgentName) ?? "Default Agent"
    }

    private var gatewayDisplayLabel: String {
        self.normalized(self.appModel.gatewayServerName)
            ?? self.normalized(self.appModel.gatewayRemoteAddress)
            ?? self.appModel.gatewayDisplayStatusText
    }

    private var gatewayStateText: String {
        switch GatewayStatusBuilder.build(appModel: self.appModel) {
        case .connected: "Online"
        case .connecting: "Connecting"
        case .error: "Attention"
        case .disconnected: "Offline"
        }
    }

    private var gatewayStateColor: Color {
        switch GatewayStatusBuilder.build(appModel: self.appModel) {
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

    private var isCompactHeight: Bool {
        self.verticalSizeClass == .compact
    }

    private var bottomScrollInset: CGFloat {
        Self.bottomScrollInset(verticalSizeClass: self.verticalSizeClass)
    }

    static func bottomScrollInset(verticalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        verticalSizeClass == .compact ? 72 : 112
    }

    private func resolveDefaultAgentID() -> String {
        self.normalized(self.appModel.gatewayDefaultAgentId) ?? ""
    }

    private func agentTitle(for agent: AgentSummary) -> String {
        let name = self.normalized(agent.name) ?? agent.id
        return name == agent.id ? name : "\(name) (\(agent.id))"
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if DEBUG
#Preview("Phone control hub offline") {
    RootTabsPhoneControlHub.preview(appModel: NodeAppModel())
}

#Preview("Phone control hub connected") {
    let appModel = NodeAppModel()
    appModel.enterAppleReviewDemoMode()
    return RootTabsPhoneControlHub.preview(appModel: appModel)
}

#Preview("Phone control hub connecting") {
    let appModel = NodeAppModel()
    appModel.gatewayStatusText = "Connecting..."
    return RootTabsPhoneControlHub.preview(appModel: appModel)
}

#Preview("Phone control hub gateway error") {
    let appModel = NodeAppModel()
    appModel.gatewayStatusText = "Gateway error: connection refused"
    return RootTabsPhoneControlHub.preview(appModel: appModel)
}

#Preview(
    "Phone control hub landscape",
    traits: .fixedLayout(width: 852, height: 393),
    .landscapeLeft)
{
    RootTabsPhoneControlHub.preview(appModel: NodeAppModel())
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .compact)
}

extension RootTabsPhoneControlHub {
    fileprivate static func preview(appModel: NodeAppModel) -> some View {
        RootTabsPhoneControlHub(
            groups: RootTabs.phoneControlGroups,
            initialDestination: nil,
            openRootDestination: { _ in })
            .environment(appModel)
    }
}
#endif
