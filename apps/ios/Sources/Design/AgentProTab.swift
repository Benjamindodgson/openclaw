import ComposableArchitecture
import OpenClawKit
import SwiftUI

struct AgentProTab: View {
    @Environment(NodeAppModel.self) var appModel
    @Environment(\.scenePhase) var scenePhase
    let directRoute: AgentRoute?
    let headerLeadingAction: OpenClawSidebarHeaderAction?
    let headerTitle: String
    let openSettings: (() -> Void)?
    @State private var navigationStore: StoreOf<AgentNavigationFeature>
    @State var filterStore: StoreOf<AgentOverviewFilterFeature>
    @State var overviewStore: StoreOf<AgentOverviewLoadFeature>
    @State var skillFilter: String = ""
    @State var skillStatusFilter: SkillStatusFilter = .all
    @State var skillMutationBusyKeys: Set<String> = []
    @State var skillMutationErrorText: String?
    @State var skillMutationStatusText: String?
    @State var skillConfigBusyKeys: Set<String> = []
    @State var skillConfigMessages: [String: SkillEditorMessage] = [:]
    @State var skillAPIKeyDrafts: [String: String] = [:]
    @State var skillEditorSelection: SkillEditorSelection?
    @State var clawHubStore: StoreOf<AgentClawHubSearchFeature>
    @State var cronActionBusyIDs: Set<String> = []
    @State var cronActionStatusText: String?

    enum AgentRoute: Hashable {
        case agents
        case skills
        case instances
        case cron
        case usage
        case dreaming
    }

    enum SkillStatusFilter: String, CaseIterable, Identifiable {
        case all
        case enabled
        case off
        case setup
        case blocked

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .all: "All"
            case .enabled: "Enabled"
            case .off: "Off"
            case .setup: "Setup"
            case .blocked: "Blocked"
            }
        }
    }

    enum AgentRosterFilter: String, CaseIterable, Identifiable {
        case all
        case online
        case ready

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .all: "All"
            case .online: "Online"
            case .ready: "Ready"
            }
        }
    }

    enum AgentLayout {
        static let cardRadius: CGFloat = OpenClawProMetric.cardRadius
        static let filterHeight: CGFloat = 34
        static let rowMinHeight: CGFloat = 72
        static let metricTileHeight: CGFloat = 94
    }

    enum AgentRosterState: Equatable {
        case online
        case ready

        var color: Color {
            switch self {
            case .online: OpenClawBrand.ok
            case .ready: OpenClawBrand.info
            }
        }
    }

    struct SkillEditorSelection: Identifiable {
        let id: String
    }

    struct SkillEditorMessage {
        let kind: Kind
        let text: String

        enum Kind {
            case success
            case error
        }
    }

    init(
        directRoute: AgentRoute? = nil,
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        headerTitle: String = "Agents",
        openSettings: (() -> Void)? = nil,
        navigationStore: StoreOf<AgentNavigationFeature> = Store(
            initialState: AgentNavigationFeature.State())
        {
            AgentNavigationFeature()
        },
        overviewStore: StoreOf<AgentOverviewLoadFeature> = Store(
            initialState: AgentOverviewLoadFeature.State())
        {
            AgentOverviewLoadFeature()
        },
        clawHubStore: StoreOf<AgentClawHubSearchFeature> = Store(
            initialState: AgentClawHubSearchFeature.State())
        {
            AgentClawHubSearchFeature()
        },
        filterStore: StoreOf<AgentOverviewFilterFeature> = Store(
            initialState: AgentOverviewFilterFeature.State())
        {
            AgentOverviewFilterFeature()
        })
    {
        self.directRoute = directRoute
        self.headerLeadingAction = headerLeadingAction
        self.headerTitle = headerTitle
        self.openSettings = openSettings
        self._navigationStore = State(wrappedValue: navigationStore)
        self._overviewStore = State(wrappedValue: overviewStore)
        self._clawHubStore = State(wrappedValue: clawHubStore)
        self._filterStore = State(wrappedValue: filterStore)
    }

    var body: some View {
        Group {
            if let directRoute {
                self.directDestination(for: directRoute)
            } else {
                self.overviewNavigation
            }
        }
        .task(id: self.overviewTaskID) {
            await self.refreshOverview(force: false)
        }
        .sheet(item: self.$skillEditorSelection) { selection in
            if let skill = self.skillByKey(selection.id) {
                self.skillEditorSheet(skill)
            } else {
                self.missingSkillEditorSheet
            }
        }
    }

    var overview: AgentOverviewSnapshot? {
        self.overviewStore.overview
    }

    var overviewErrorText: String? {
        self.overviewStore.errorText
    }

    var overviewLoading: Bool {
        self.overviewStore.isLoading
    }

    var clawHubQuery: String {
        self.clawHubStore.query
    }

    var clawHubQueryBinding: Binding<String> {
        Binding(
            get: { self.clawHubStore.query },
            set: { self.clawHubStore.send(.queryChanged($0)) })
    }

    var clawHubResults: [ClawHubSearchResultLite] {
        self.clawHubStore.results
    }

    var clawHubLoading: Bool {
        self.clawHubStore.isLoading
    }

    var clawHubErrorText: String? {
        self.clawHubStore.errorText
    }

    var clawHubInstallSlug: String? {
        self.clawHubStore.installingSlug
    }

    private var overviewNavigation: some View {
        NavigationStack(path: self.navigationPathBinding) {
            ZStack {
                OpenClawProBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        self.rosterHeader
                        self.agentFilters
                        self.agentsSection
                        self.operationsSection
                        self.dreamingSection
                        self.cronSection
                    }
                    .padding(.vertical, 18)
                }
                .refreshable {
                    await self.refreshOverview(force: true)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: AgentRoute.self) { route in
                self.destination(for: route)
            }
        }
    }

    private var navigationPathBinding: Binding<[AgentRoute]> {
        Binding(
            get: { self.navigationStore.navigationPath },
            set: { self.navigationStore.send(.navigationPathChanged($0)) })
    }

    private func directDestination(for route: AgentRoute) -> some View {
        self.destination(for: route)
            .toolbar(
                route == .agents || self.directHeaderLeadingAction(for: route) != nil ? .hidden : .visible,
                for: .navigationBar)
    }
}

@Reducer
struct AgentClawHubSearchFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var query = ""
        var results: [ClawHubSearchResultLite] = []
        var isLoading = false
        var errorText: String?
        var installingSlug: String?
    }

    enum Action: Equatable, Sendable {
        case installFailed(slug: String, message: String)
        case installFinished(slug: String)
        case installRequested(slug: String)
        case queryChanged(String)
        case searchFailed(String)
        case searchFinished([ClawHubSearchResultLite])
        case searchRequested
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .queryChanged(query):
                state.query = query
                return .none

            case .searchRequested:
                state.isLoading = true
                state.errorText = nil
                return .none

            case let .searchFinished(results):
                state.results = results
                state.isLoading = false
                return .none

            case let .searchFailed(message):
                state.errorText = message
                state.isLoading = false
                return .none

            case let .installRequested(slug):
                state.installingSlug = slug
                state.errorText = nil
                return .none

            case let .installFinished(slug):
                if state.installingSlug == slug {
                    state.installingSlug = nil
                }
                return .none

            case let .installFailed(slug, message):
                state.errorText = message
                if state.installingSlug == slug {
                    state.installingSlug = nil
                }
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct AgentOverviewLoadFeature {
    struct RefreshRequest: Equatable {
        let id: Int
        let activeAgentID: String
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var overview: AgentOverviewSnapshot?
        var errorText: String?
        var isLoading = false
        var refreshRequest: RefreshRequest?
        var nextRefreshRequestID = 0
    }

    enum Action: Equatable, Sendable {
        case refreshFinished(AgentOverviewSnapshot, requestID: Int)
        case refreshLaunched(requestID: Int)
        case refreshRequested(gatewayConnected: Bool, force: Bool, activeAgentID: String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .refreshRequested(gatewayConnected, force, activeAgentID):
                guard gatewayConnected else {
                    state.overview = nil
                    state.errorText = nil
                    state.isLoading = false
                    state.refreshRequest = nil
                    return .none
                }

                guard force || !state.isLoading else {
                    state.refreshRequest = nil
                    return .none
                }

                state.nextRefreshRequestID += 1
                state.refreshRequest = RefreshRequest(
                    id: state.nextRefreshRequestID,
                    activeAgentID: activeAgentID)
                state.isLoading = true
                state.errorText = nil
                return .none

            case let .refreshFinished(snapshot, requestID):
                state.overview = snapshot
                state.errorText = snapshot.hasAnyLiveData ? nil : "Live overview could not load yet."
                state.isLoading = false
                if state.refreshRequest?.id == requestID {
                    state.refreshRequest = nil
                }
                return .none

            case let .refreshLaunched(requestID):
                if state.refreshRequest?.id == requestID {
                    state.refreshRequest = nil
                }
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct AgentNavigationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var navigationPath: [AgentProTab.AgentRoute] = []
    }

    enum Action: Equatable, Sendable {
        case navigationPathChanged([AgentProTab.AgentRoute])
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .navigationPathChanged(navigationPath):
                state.navigationPath = navigationPath
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct AgentOverviewFilterFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var rosterFilter: AgentProTab.AgentRosterFilter = .all
        var searchPresented = false
        var searchText = ""

        var hasActiveFilters: Bool {
            self.rosterFilter != .all
                || !self.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: Equatable, Sendable {
        case clearFiltersTapped
        case rosterFilterChanged(AgentProTab.AgentRosterFilter)
        case searchButtonTapped
        case searchTextChanged(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .clearFiltersTapped:
                state.rosterFilter = .all
                state.searchText = ""
                return .none

            case let .rosterFilterChanged(filter):
                state.rosterFilter = filter
                return .none

            case .searchButtonTapped:
                state.searchPresented.toggle()
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none
            }
        }
        .autoLogActions()
    }
}
