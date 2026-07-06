import ComposableArchitecture
import OpenClawKit
import SwiftUI

// swiftformat:disable redundantSendable
struct AgentSkillEditorMutationSuccessMessage: Equatable, Sendable { var value: String }

struct AgentSkillEditorMutationSummary: Equatable, Sendable {
    var message: AgentSkillEditorMutationSuccessMessage
}

// swiftformat:enable redundantSendable

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
    @State var skillFilterStore: StoreOf<AgentSkillFilterFeature>
    @State var skillPolicyMutationStore: StoreOf<AgentSkillPolicyMutationFeature>
    @State var skillEditorStore: StoreOf<AgentSkillEditorFeature>
    @State var clawHubStore: StoreOf<AgentClawHubSearchFeature>
    @State var cronActionStore: StoreOf<AgentCronActionFeature>
    @State var selectionStore: StoreOf<AgentSelectionFeature>

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

    struct SkillEditorSelection: Equatable, Identifiable {
        let id: String
    }

    struct SkillEditorMessage: Equatable {
        let kind: Kind
        let text: String

        enum Kind: Equatable {
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
        skillFilterStore: StoreOf<AgentSkillFilterFeature> = Store(
            initialState: AgentSkillFilterFeature.State())
        {
            AgentSkillFilterFeature()
        },
        skillPolicyMutationStore: StoreOf<AgentSkillPolicyMutationFeature> = Store(
            initialState: AgentSkillPolicyMutationFeature.State())
        {
            AgentSkillPolicyMutationFeature()
        },
        skillEditorStore: StoreOf<AgentSkillEditorFeature> = Store(
            initialState: AgentSkillEditorFeature.State())
        {
            AgentSkillEditorFeature()
        },
        cronActionStore: StoreOf<AgentCronActionFeature> = Store(
            initialState: AgentCronActionFeature.State())
        {
            AgentCronActionFeature()
        },
        selectionStore: StoreOf<AgentSelectionFeature> = Store(
            initialState: AgentSelectionFeature.State())
        {
            AgentSelectionFeature()
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
        self._skillFilterStore = State(wrappedValue: skillFilterStore)
        self._skillPolicyMutationStore = State(wrappedValue: skillPolicyMutationStore)
        self._skillEditorStore = State(wrappedValue: skillEditorStore)
        self._cronActionStore = State(wrappedValue: cronActionStore)
        self._selectionStore = State(wrappedValue: selectionStore)
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
        .sheet(item: self.skillEditorSelectionBinding) { selection in
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
            set: { self.clawHubStore.send(.queryChanged(.init(query: $0))) })
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

    var skillFilter: String {
        self.skillFilterStore.searchText
    }

    var skillFilterBinding: Binding<String> {
        Binding(
            get: { self.skillFilterStore.searchText },
            set: { self.skillFilterStore.send(.searchTextChanged(.init(text: $0))) })
    }

    var skillStatusFilter: SkillStatusFilter {
        self.skillFilterStore.statusFilter
    }

    var skillStatusFilterBinding: Binding<SkillStatusFilter> {
        Binding(
            get: { self.skillFilterStore.statusFilter },
            set: { self.skillFilterStore.send(.statusFilterChanged($0)) })
    }

    var skillMutationBusyKeys: Set<String> {
        self.skillPolicyMutationStore.busyKeys
    }

    var skillMutationErrorText: String? {
        self.skillPolicyMutationStore.errorText
    }

    var skillMutationStatusText: String? {
        self.skillPolicyMutationStore.statusText
    }

    var skillConfigBusyKeys: Set<String> {
        self.skillEditorStore.busyKeys
    }

    var skillConfigMessages: [String: SkillEditorMessage] {
        self.skillEditorStore.messages
    }

    var skillEditorSelectionBinding: Binding<SkillEditorSelection?> {
        Binding(
            get: { self.skillEditorStore.selection },
            set: { self.skillEditorStore.send(.selectionChanged(.init(selection: $0))) })
    }

    var cronActionBusyIDs: Set<String> {
        self.cronActionStore.busyIDs
    }

    var cronActionStatusText: String? {
        self.cronActionStore.statusText
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
            set: { self.navigationStore.send(.navigationPathChanged(.init(path: $0))) })
    }

    private func directDestination(for route: AgentRoute) -> some View {
        self.destination(for: route)
            .toolbar(
                route == .agents || self.directHeaderLeadingAction(for: route) != nil ? .hidden : .visible,
                for: .navigationBar)
    }
}

// swiftformat:disable redundantSendable
struct AgentSelectionClient: Sendable {
    var setSelectedAgentId: @MainActor @Sendable (SelectedAgentID) -> Void
}

// swiftformat:enable redundantSendable

extension AgentSelectionClient: DependencyKey {
    static let liveValue = AgentSelectionClient(setSelectedAgentId: { _ in })
    static let testValue = AgentSelectionClient(setSelectedAgentId: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        AgentSelectionClient(setSelectedAgentId: { agentId in
            appModel.setSelectedAgentId(agentId.value)
        })
    }
}

extension DependencyValues {
    var agentSelection: AgentSelectionClient {
        get { self[AgentSelectionClient.self] }
        set { self[AgentSelectionClient.self] = newValue }
    }
}

@Reducer
struct AgentSelectionFeature {
    private let selectionClientOverride: AgentSelectionClient?

    init(selectionClient: AgentSelectionClient? = nil) {
        self.selectionClientOverride = selectionClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        struct AgentSelection: Equatable, Sendable {
            var agentId: SelectedAgentID
        }

        case agentSelected(AgentSelection)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.agentSelection) var dependencySelectionClient
            let selectionClient = self.selectionClientOverride ?? dependencySelectionClient

            switch action {
            case let .agentSelected(selection):
                return .run { [selectionClient] _ in
                    await selectionClient.setSelectedAgentId(selection.agentId)
                }
            }
        }
        .autoLogActions()
    }
}

// swiftformat:disable redundantSendable
struct AgentSkillPolicyMutationFailureMessage: Equatable, Sendable { var value: String }
struct AgentSkillPolicyMutationSuccessMessage: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

@Reducer
struct AgentSkillPolicyMutationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var busyKeys: Set<String> = []
        var errorText: String?
        var statusText: String?
    }

    enum Action: Equatable, Sendable {
        struct MutationKey: Equatable, Sendable {
            var key: String
        }

        struct MutationFailure: Equatable, Sendable {
            var message: AgentSkillPolicyMutationFailureMessage
        }

        struct MutationSuccess: Equatable, Sendable {
            var message: AgentSkillPolicyMutationSuccessMessage
        }

        case mutationFailed(MutationFailure)
        case mutationFinished(MutationKey)
        case mutationStarted(MutationKey)
        case mutationSucceeded(MutationSuccess)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .mutationStarted(mutation):
                state.busyKeys.insert(mutation.key)
                state.errorText = nil
                state.statusText = nil
                return .none

            case let .mutationSucceeded(result):
                state.statusText = result.message.value
                return .none

            case let .mutationFailed(failure):
                state.errorText = failure.message.value
                return .none

            case let .mutationFinished(mutation):
                state.busyKeys.remove(mutation.key)
                return .none
            }
        }
        .autoLogActions()
    }
}

// swiftformat:disable redundantSendable
struct AgentSkillEditorMutationFailureMessage: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

@Reducer
struct AgentSkillEditorFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var apiKeyDrafts: [String: String] = [:]
        var busyKeys: Set<String> = []
        var messages: [String: AgentProTab.SkillEditorMessage] = [:]
        var selection: AgentProTab.SkillEditorSelection?
    }

    enum Action: Equatable, Sendable {
        struct MutationKey: Equatable, Sendable {
            var key: String
        }

        struct MutationFailure: Equatable, Sendable {
            var key: String
            var message: AgentSkillEditorMutationFailureMessage
        }

        struct MutationSuccess: Equatable, Sendable {
            var key: String
            var summary: AgentSkillEditorMutationSummary
        }

        struct APIKeyDraftChange: Equatable, Sendable {
            var key: String
            var value: String
        }

        struct APIKeyDraftKey: Equatable, Sendable {
            var key: String
        }

        struct EditorID: Equatable, Sendable {
            var id: String
        }

        struct SelectionChange: Equatable, Sendable {
            var selection: AgentProTab.SkillEditorSelection?
        }

        case apiKeyDraftChanged(APIKeyDraftChange)
        case apiKeyDraftCleared(APIKeyDraftKey)
        case editorDismissed
        case editorOpened(EditorID)
        case mutationFailed(MutationFailure)
        case mutationFinished(MutationKey)
        case mutationStarted(MutationKey)
        case mutationSucceeded(MutationSuccess)
        case selectionChanged(SelectionChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .apiKeyDraftChanged(draft):
                state.apiKeyDrafts[draft.key] = draft.value
                return .none

            case let .apiKeyDraftCleared(draft):
                state.apiKeyDrafts[draft.key] = nil
                return .none

            case .editorDismissed:
                state.selection = nil
                return .none

            case let .editorOpened(editor):
                state.selection = AgentProTab.SkillEditorSelection(id: editor.id)
                return .none

            case let .selectionChanged(change):
                state.selection = change.selection
                return .none

            case let .mutationStarted(mutation):
                state.busyKeys.insert(mutation.key)
                state.messages[mutation.key] = nil
                return .none

            case let .mutationSucceeded(result):
                state.messages[result.key] = AgentProTab.SkillEditorMessage(
                    kind: .success,
                    text: result.summary.message.value)
                return .none

            case let .mutationFinished(mutation):
                state.busyKeys.remove(mutation.key)
                return .none

            case let .mutationFailed(failure):
                state.busyKeys.remove(failure.key)
                state.messages[failure.key] = AgentProTab.SkillEditorMessage(
                    kind: .error,
                    text: failure.message.value)
                return .none
            }
        }
        .autoLogActions()
    }
}

// swiftformat:disable redundantSendable
struct AgentCronActionFailureMessage: Equatable, Sendable { var value: String }
struct AgentCronActionSuccessMessage: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

@Reducer
struct AgentCronActionFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var busyIDs: Set<String> = []
        var statusText: String?
    }

    enum Action: Equatable, Sendable {
        struct ActionID: Equatable, Sendable {
            var id: String
        }

        struct ActionFailure: Equatable, Sendable {
            var id: String
            var message: AgentCronActionFailureMessage
        }

        struct ActionSuccess: Equatable, Sendable {
            var message: AgentCronActionSuccessMessage
        }

        case actionFinished(ActionID)
        case actionFailed(ActionFailure)
        case actionStarted(ActionID)
        case actionSucceeded(ActionSuccess)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .actionStarted(action):
                state.busyIDs.insert(action.id)
                state.statusText = nil
                return .none

            case let .actionSucceeded(result):
                state.statusText = result.message.value
                return .none

            case let .actionFinished(action):
                state.busyIDs.remove(action.id)
                return .none

            case let .actionFailed(failure):
                state.busyIDs.remove(failure.id)
                state.statusText = failure.message.value
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct AgentSkillFilterFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var searchText = ""
        var statusFilter: AgentProTab.SkillStatusFilter = .all
    }

    enum Action: Equatable, Sendable {
        struct SearchTextChange: Equatable, Sendable {
            var text: String
        }

        case clearSearchTapped
        case searchTextChanged(SearchTextChange)
        case statusFilterChanged(AgentProTab.SkillStatusFilter)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .clearSearchTapped:
                state.searchText = ""
                return .none

            case let .searchTextChanged(change):
                state.searchText = change.text
                return .none

            case let .statusFilterChanged(statusFilter):
                state.statusFilter = statusFilter
                return .none
            }
        }
        .autoLogActions()
    }
}

// swiftformat:disable redundantSendable
struct AgentClawHubInstallFailureMessage: Equatable, Sendable { var value: String }
struct AgentClawHubSearchFailureMessage: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

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
        struct QueryChange: Equatable, Sendable {
            var query: String
        }

        struct SearchFailure: Equatable, Sendable {
            var message: AgentClawHubSearchFailureMessage
        }

        struct InstallSlug: Equatable, Sendable {
            var slug: String
        }

        struct InstallFailure: Equatable, Sendable {
            var slug: String
            var message: AgentClawHubInstallFailureMessage
        }

        struct SearchResults: Equatable, Sendable {
            var results: [ClawHubSearchResultLite]
        }

        case installFailed(InstallFailure)
        case installFinished(InstallSlug)
        case installRequested(InstallSlug)
        case queryChanged(QueryChange)
        case searchFailed(SearchFailure)
        case searchFinished(SearchResults)
        case searchRequested
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .queryChanged(change):
                state.query = change.query
                return .none

            case .searchRequested:
                state.isLoading = true
                state.errorText = nil
                return .none

            case let .searchFinished(response):
                state.results = response.results
                state.isLoading = false
                return .none

            case let .searchFailed(failure):
                state.errorText = failure.message.value
                state.isLoading = false
                return .none

            case let .installRequested(install):
                state.installingSlug = install.slug
                state.errorText = nil
                return .none

            case let .installFinished(install):
                if state.installingSlug == install.slug {
                    state.installingSlug = nil
                }
                return .none

            case let .installFailed(failure):
                state.errorText = failure.message.value
                if state.installingSlug == failure.slug {
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
        struct GatewayConnectionStatus: Equatable, Sendable {
            var isConnected: Bool
        }

        struct RefreshForce: Equatable, Sendable {
            var isForced: Bool
        }

        struct ActiveAgentID: Equatable, Sendable {
            var value: String
        }

        struct RefreshRequestPayload: Equatable, Sendable {
            var gatewayConnection: GatewayConnectionStatus
            var force: RefreshForce
            var activeAgent: ActiveAgentID
        }

        struct RefreshLaunch: Equatable, Sendable {
            var requestID: Int
        }

        struct RefreshResult: Equatable, Sendable {
            var snapshot: AgentOverviewSnapshot
            var requestID: Int
        }

        case refreshFinished(RefreshResult)
        case refreshLaunched(RefreshLaunch)
        case refreshRequested(RefreshRequestPayload)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .refreshRequested(request):
                guard request.gatewayConnection.isConnected else {
                    state.overview = nil
                    state.errorText = nil
                    state.isLoading = false
                    state.refreshRequest = nil
                    return .none
                }

                guard request.force.isForced || !state.isLoading else {
                    state.refreshRequest = nil
                    return .none
                }

                state.nextRefreshRequestID += 1
                state.refreshRequest = RefreshRequest(
                    id: state.nextRefreshRequestID,
                    activeAgentID: request.activeAgent.value)
                state.isLoading = true
                state.errorText = nil
                return .none

            case let .refreshFinished(result):
                state.overview = result.snapshot
                state.errorText = result.snapshot.hasAnyLiveData ? nil : "Live overview could not load yet."
                state.isLoading = false
                if state.refreshRequest?.id == result.requestID {
                    state.refreshRequest = nil
                }
                return .none

            case let .refreshLaunched(launch):
                if state.refreshRequest?.id == launch.requestID {
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
        struct NavigationPathChange: Equatable, Sendable {
            var path: [AgentProTab.AgentRoute]
        }

        case navigationPathChanged(NavigationPathChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .navigationPathChanged(change):
                state.navigationPath = change.path
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
        struct SearchTextChange: Equatable, Sendable {
            var text: String
        }

        case clearFiltersTapped
        case rosterFilterChanged(AgentProTab.AgentRosterFilter)
        case searchButtonTapped
        case searchTextChanged(SearchTextChange)
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

            case let .searchTextChanged(change):
                state.searchText = change.text
                return .none
            }
        }
        .autoLogActions()
    }
}
