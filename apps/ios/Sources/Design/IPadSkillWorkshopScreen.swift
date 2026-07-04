import ComposableArchitecture
import OpenClawKit
import SwiftUI

struct IPadSkillWorkshopClient {
    var list: @Sendable @MainActor (_ agentID: String?) async throws -> IPadSkillProposalManifest
    var inspect: @Sendable @MainActor (_ agentID: String?, _ proposalID: String) async throws
        -> IPadSkillProposalInspectResponse
    var run: @Sendable @MainActor (_ action: IPadSkillProposalAction.Kind, _ agentID: String?, _ proposalID: String)
    async throws -> Void
}

extension IPadSkillWorkshopClient: DependencyKey {
    static let liveValue = IPadSkillWorkshopClient(
        list: { _ in IPadSkillProposalManifest(proposals: []) },
        inspect: { _, _ in throw IPadSkillWorkshopError.failed("Proposal unavailable.") },
        run: { _, _, _ in })

    static let testValue = IPadSkillWorkshopClient(
        list: { _ in IPadSkillProposalManifest(proposals: []) },
        inspect: { _, _ in throw IPadSkillWorkshopError.failed("Proposal unavailable.") },
        run: { _, _, _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        IPadSkillWorkshopClient(
            list: { agentID in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "skills.proposals.list",
                    params: IPadSkillProposalListParams(agentId: agentID),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadSkillProposalManifest.self, from: data)
            },
            inspect: { agentID, proposalID in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "skills.proposals.inspect",
                    params: IPadSkillProposalInspectParams(
                        agentId: agentID,
                        proposalId: proposalID),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadSkillProposalInspectResponse.self, from: data)
            },
            run: { action, agentID, proposalID in
                let method = action == .apply ? "skills.proposals.apply" : "skills.proposals.reject"
                _ = try await Self.request(
                    appModel: appModel,
                    method: method,
                    params: IPadSkillProposalInspectParams(
                        agentId: agentID,
                        proposalId: proposalID),
                    timeoutSeconds: 30)
            })
    }

    @MainActor
    private static func request(
        appModel: NodeAppModel,
        method: String,
        params: some Encodable,
        timeoutSeconds: Int) async throws -> Data
    {
        let data = try JSONEncoder().encode(params)
        guard let json = String(data: data, encoding: .utf8) else {
            throw IPadSidebarGatewayError.invalidPayload
        }
        return try await appModel.operatorSession.request(
            method: method,
            paramsJSON: json,
            timeoutSeconds: timeoutSeconds)
    }
}

extension DependencyValues {
    var iPadSkillWorkshop: IPadSkillWorkshopClient {
        get { self[IPadSkillWorkshopClient.self] }
        set { self[IPadSkillWorkshopClient.self] = newValue }
    }
}

// swiftformat:disable redundantSendable
enum IPadSkillWorkshopError: Error, Equatable, Sendable {
    case failed(String)

    var message: String {
        switch self {
        case let .failed(message):
            message
        }
    }
}

// swiftformat:enable redundantSendable

@Reducer
struct IPadSkillWorkshopFeature {
    private let clientOverride: IPadSkillWorkshopClient?

    init(client: IPadSkillWorkshopClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var proposals: [IPadSkillProposal] = []
        var selectedProposalID: String?
        var selectedAgentScopeID = ""
        var statusFilter = "pending"
        var query = ""
        var isLoading = false
        var inspectingProposalID: String?
        var busyAction: IPadSkillProposalAction?
        var errorText: String?
        var noticeText: String?
        var presentedProposalRoute: IPadSkillProposalSheetRoute?

        var selectedAgentParam: String? {
            let selected = IPadSkillWorkshopScreen.normalizedScopeID(self.selectedAgentScopeID)
            return selected.isEmpty ? nil : selected
        }

        var statusFilterLabel: String {
            IPadSkillWorkshopScreen.proposalStatusFilterLabel(self.statusFilter)
        }

        var filteredProposals: [IPadSkillProposal] {
            Self.filteredProposals(
                proposals: self.proposals,
                statusFilter: self.statusFilter,
                query: self.query)
        }

        var visibleProposalLaneStatuses: [String] {
            IPadSkillWorkshopScreen.proposalStatusBoardLanes(
                filter: self.statusFilter,
                proposalStatuses: self.proposals.map(\.status))
        }

        func proposals(forLaneStatus status: String) -> [IPadSkillProposal] {
            Self.filteredProposals(
                proposals: self.proposals.filter { $0.status == status },
                statusFilter: "all",
                query: self.query)
                .sorted { $0.updatedAtMs > $1.updatedAtMs }
        }

        mutating func syncSelectedProposalIDForVisibleProposals() {
            let nextID = IPadSkillWorkshopScreen.nextSelectedProposalID(
                current: self.selectedProposalID,
                visibleProposalIDs: self.filteredProposals.map(\.id))
            guard self.selectedProposalID != nextID else { return }
            self.selectedProposalID = nextID
        }

        mutating func merge(_ proposal: IPadSkillProposal) {
            self.proposals.removeAll { $0.id == proposal.id }
            self.proposals.append(proposal)
            self.proposals.sort { $0.updatedAtMs > $1.updatedAtMs }
        }

        private static func filteredProposals(
            proposals: [IPadSkillProposal],
            statusFilter: String,
            query: String) -> [IPadSkillProposal]
        {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return proposals
                .filter { proposal in
                    IPadSkillWorkshopScreen.proposalStatusMatchesFilter(
                        status: proposal.status,
                        filter: statusFilter)
                }
                .filter { proposal in
                    guard !trimmedQuery.isEmpty else { return true }
                    return [
                        proposal.title,
                        proposal.description,
                        proposal.skillName,
                        proposal.skillKey,
                    ]
                        .joined(separator: " ")
                        .lowercased()
                        .contains(trimmedQuery)
                }
        }
    }

    enum Action: Equatable, Sendable {
        case agentScopeChanged(String)
        case clearQueryTapped

        struct InspectRequest: Equatable, Sendable {
            var proposalID: String
            var canRead: Bool
            var force: Bool
        }

        struct InspectResponse: Equatable, Sendable {
            var proposalID: String
            var result: Result<IPadSkillProposalInspectResponse, IPadSkillWorkshopError>
        }

        case inspectRequested(InspectRequest)
        case inspectResponse(InspectResponse)

        struct ProposalMutationRequest: Equatable, Sendable {
            var kind: IPadSkillProposalAction.Kind
            var proposalID: String
            var sceneActive: Bool
            var canRead: Bool
            var canWrite: Bool
            var hasOperatorAdminScope: Bool
        }

        struct ProposalMutationResponse: Equatable, Sendable {
            var kind: IPadSkillProposalAction.Kind
            var sceneActive: Bool
            var canRead: Bool
            var result: Result<Bool, IPadSkillWorkshopError>
        }

        case proposalMutationRequested(ProposalMutationRequest)
        case proposalMutationResponse(ProposalMutationResponse)

        struct ProposalSelectionRequest: Equatable, Sendable {
            var proposalID: String
            var opensSheet: Bool
            var canRead: Bool
            var forceInspect: Bool
        }

        struct RefreshRequest: Equatable, Sendable {
            var sceneActive: Bool
            var canRead: Bool
            var force: Bool
        }

        struct RefreshResponse: Equatable, Sendable {
            var force: Bool
            var result: Result<IPadSkillProposalManifest, IPadSkillWorkshopError>
        }

        case proposalSelected(ProposalSelectionRequest)
        case proposalSheetDismissed
        case queryChanged(String)
        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)
        case statusFilterChanged(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.iPadSkillWorkshop) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .agentScopeChanged(agentID):
                state.selectedAgentScopeID = IPadSkillWorkshopScreen.normalizedScopeID(agentID)
                return .none

            case .clearQueryTapped:
                state.query = ""
                state.syncSelectedProposalIDForVisibleProposals()
                return .none

            case let .inspectRequested(request):
                return self.inspectEffect(
                    state: &state,
                    client: client,
                    request: request)

            case let .inspectResponse(response):
                switch response.result {
                case let .success(inspectResponse):
                    state.inspectingProposalID = nil
                    let previous = state.proposals.first { $0.id == response.proposalID }
                    state.merge(IPadSkillProposal(inspect: inspectResponse, previous: previous))
                    return .none

                case let .failure(error):
                    state.inspectingProposalID = nil
                    state.errorText = error.message
                    return .none
                }

            case let .proposalMutationRequested(request):
                guard IPadSkillWorkshopScreen.shouldEnableProposalMutation(
                    canWrite: request.canWrite,
                    hasOperatorAdminScope: request.hasOperatorAdminScope),
                    state.busyAction == nil
                else {
                    return .none
                }

                state.busyAction = IPadSkillProposalAction(kind: request.kind, proposalID: request.proposalID)
                state.errorText = nil
                state.noticeText = nil
                let agentID = state.selectedAgentParam
                return .run { send in
                    do {
                        try await client.run(request.kind, agentID, request.proposalID)
                        await send(.proposalMutationResponse(.init(
                            kind: request.kind,
                            sceneActive: request.sceneActive,
                            canRead: request.canRead,
                            result: .success(true))))
                    } catch {
                        await send(.proposalMutationResponse(.init(
                            kind: request.kind,
                            sceneActive: request.sceneActive,
                            canRead: request.canRead,
                            result: .failure(.failed(Self.message(for: error))))))
                    }
                }

            case let .proposalMutationResponse(response):
                switch response.result {
                case .success:
                    state.busyAction = nil
                    state.noticeText = response.kind == .apply ? "Proposal applied." : "Proposal rejected."
                    return .run { send in
                        await send(.refreshRequested(.init(
                            sceneActive: response.sceneActive,
                            canRead: response.canRead,
                            force: true)))
                    }

                case let .failure(error):
                    state.busyAction = nil
                    state.errorText = error.message
                    return .none
                }

            case let .proposalSelected(request):
                state.selectedProposalID = request.proposalID
                if request.opensSheet {
                    state.presentedProposalRoute = IPadSkillProposalSheetRoute(proposalID: request.proposalID)
                }
                return self.inspectEffect(
                    state: &state,
                    client: client,
                    request: .init(
                        proposalID: request.proposalID,
                        canRead: request.canRead,
                        force: request.forceInspect))

            case .proposalSheetDismissed:
                state.presentedProposalRoute = nil
                return .none

            case let .queryChanged(query):
                state.query = query
                state.syncSelectedProposalIDForVisibleProposals()
                return .none

            case let .refreshRequested(request):
                guard request.sceneActive else {
                    state.isLoading = false
                    return .none
                }
                guard request.canRead else {
                    state.proposals = []
                    state.errorText = nil
                    state.isLoading = false
                    state.inspectingProposalID = nil
                    return .none
                }
                guard !state.isLoading else { return .none }

                state.isLoading = true
                state.errorText = nil
                let agentID = state.selectedAgentParam
                return .run { send in
                    do {
                        let manifest = try await client.list(agentID)
                        await send(.refreshResponse(.init(
                            force: request.force,
                            result: .success(manifest))))
                    } catch {
                        await send(.refreshResponse(.init(
                            force: request.force,
                            result: .failure(.failed(Self.message(for: error))))))
                    }
                }

            case let .refreshResponse(response):
                state.isLoading = false
                switch response.result {
                case let .success(manifest):
                    let previousByID = Dictionary(uniqueKeysWithValues: state.proposals.map { ($0.id, $0) })
                    state.proposals = manifest.proposals
                        .map { IPadSkillProposal(entry: $0, previous: previousByID[$0.id]) }
                        .sorted { $0.updatedAtMs > $1.updatedAtMs }
                    state.syncSelectedProposalIDForVisibleProposals()
                    guard let proposalID = state.selectedProposalID else { return .none }
                    return self.inspectEffect(
                        state: &state,
                        client: client,
                        request: .init(
                            proposalID: proposalID,
                            canRead: true,
                            force: response.force))

                case let .failure(error):
                    if response.force || state.proposals.isEmpty {
                        state.errorText = error.message
                    }
                    return .none
                }

            case let .statusFilterChanged(filter):
                state.statusFilter = filter
                state.syncSelectedProposalIDForVisibleProposals()
                return .none
            }
        }
        .autoLogActions()
    }

    private func inspectEffect(
        state: inout State,
        client: IPadSkillWorkshopClient,
        request: Action.InspectRequest) -> Effect<Action>
    {
        guard request.canRead else { return .none }
        guard request.force || state.proposals.first(where: { $0.id == request.proposalID })?.content == nil
        else { return .none }
        guard state.inspectingProposalID == nil else { return .none }

        state.inspectingProposalID = request.proposalID
        state.errorText = nil
        let agentID = state.selectedAgentParam
        return .run { send in
            do {
                let response = try await client.inspect(agentID, request.proposalID)
                await send(.inspectResponse(.init(
                    proposalID: request.proposalID,
                    result: .success(response))))
            } catch {
                await send(.inspectResponse(.init(
                    proposalID: request.proposalID,
                    result: .failure(.failed(Self.message(for: error))))))
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let workflowError = error as? IPadSkillWorkshopError {
            return workflowError.message
        }
        if let gatewayError = error as? IPadSidebarGatewayError {
            return gatewayError.message
        }
        return error.localizedDescription
    }
}

enum IPadSkillWorkshopStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<IPadSkillWorkshopFeature> {
        Store(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: .live(appModel: appModel))
        }
    }
}

struct IPadSkillWorkshopScreen: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var store: StoreOf<IPadSkillWorkshopFeature>
    let headerLeadingAction: OpenClawSidebarHeaderAction?
    let openSettings: () -> Void

    init(
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        openSettings: @escaping () -> Void = {},
        store: StoreOf<IPadSkillWorkshopFeature> = Store(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature()
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.openSettings = openSettings
        self._store = State(wrappedValue: store)
    }

    var body: some View {
        IPadSidebarScreenChrome(
            title: "Skill Workshop",
            subtitle: "Review and apply proposed skills.",
            headerLeadingAction: self.headerLeadingAction,
            gatewayAction: self.openSettings)
        {
            if self.isCompactWidth {
                self.compactFiltersCard
            } else {
                ProMetricGrid(metrics: self.metrics)
                self.filtersCard
            }
            self.proposalContent
        }
        .task(id: self.refreshID) {
            await self.loadProposals(force: false)
        }
        .refreshable {
            await self.loadProposals(force: true)
        }
        .sheet(item: self.presentedProposalRouteBinding) { route in
            NavigationStack {
                ScrollView {
                    self.presentedProposalDetail(proposalID: route.proposalID)
                        .padding(.horizontal, OpenClawProMetric.pagePadding)
                        .padding(.vertical, 16)
                }
                .background(OpenClawProBackground())
                .navigationTitle("Proposal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            self.store.send(.proposalSheetDismissed)
                        }
                    }
                }
            }
        }
    }

    private var metrics: [ProMetric] {
        [
            ProMetric(
                icon: "clock",
                title: "Pending",
                value: "\(self.count("pending"))",
                color: OpenClawBrand.warn),
            ProMetric(
                icon: "checkmark.circle",
                title: "Applied",
                value: "\(self.count("applied"))",
                color: OpenClawBrand.ok),
            ProMetric(
                icon: "shield",
                title: "Held",
                value: "\(self.count("quarantined") + self.count("stale"))",
                color: .secondary),
        ]
    }

    private var filtersCard: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 12) {
                self.agentScopeMenu
                self.proposalSearchField
                Picker("Status", selection: self.statusFilterBinding) {
                    ForEach(Self.proposalStatusFilters, id: \.self) { filter in
                        Text(Self.proposalStatusFilterLabel(filter)).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .tint(OpenClawBrand.accent)
                HStack(spacing: 8) {
                    Button {
                        Task { await self.loadProposals(force: true) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(self.neutralControlTint)
                    .disabled(self.store.isLoading)

                    if self.store.isLoading {
                        ProgressView().controlSize(.small)
                    }
                }
                if let noticeText = self.store.noticeText {
                    Text(noticeText)
                        .font(.caption2)
                        .foregroundStyle(OpenClawBrand.accent)
                }
                if let errorText = self.store.errorText {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(OpenClawBrand.warn)
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var compactFiltersCard: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(self.filteredProposals.count) proposals")
                            .font(.headline)
                        Text(self.statusFilterLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if self.store.isLoading {
                        ProgressView().controlSize(.small)
                    }
                }

                self.agentScopeMenu
                Picker("Status", selection: self.statusFilterBinding) {
                    ForEach(Self.proposalStatusFilters, id: \.self) { filter in
                        Text(Self.proposalStatusFilterLabel(filter)).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .tint(OpenClawBrand.accent)

                self.proposalSearchField

                HStack(spacing: 8) {
                    Button {
                        Task { await self.loadProposals(force: true) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(self.neutralControlTint)
                    .disabled(self.store.isLoading)
                }
                if let noticeText = self.store.noticeText {
                    Text(noticeText)
                        .font(.caption2)
                        .foregroundStyle(OpenClawBrand.accent)
                }
                if let errorText = self.store.errorText {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(OpenClawBrand.warn)
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var proposalSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Search proposals", text: self.queryBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
            if !self.store.query.isEmpty {
                Button {
                    self.store.send(.clearQueryTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var agentScopeMenu: some View {
        HStack(spacing: 8) {
            Text("Agent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Menu {
                Button("Default agent") {
                    self.store.send(.agentScopeChanged(""))
                }
                ForEach(self.agentScopeOptions, id: \.id) { option in
                    Button(option.title) {
                        self.store.send(.agentScopeChanged(option.id))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(self.agentScopeLabel)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(self.neutralControlTint)
            .disabled(self.agentScopeOptions.isEmpty)
            .accessibilityLabel("Skill Workshop agent scope")
        }
    }

    private var neutralControlTint: Color {
        Color.primary.opacity(0.55)
    }

    private var proposalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if self.filteredProposals.isEmpty {
                ProCard(radius: OpenClawProMetric.cardRadius) {
                    ProStatusRow(
                        icon: self.canRead ? "hammer" : "wifi.slash",
                        title: self.canRead ? "No proposals" : "No proposals loaded",
                        detail: self.canRead
                            ? "New proposals will appear here when agents draft skills."
                            : "Connect from Settings to load Skill Workshop proposals.",
                        value: self.canRead ? "empty" : nil,
                        color: .secondary,
                        actionTitle: nil,
                        action: nil)
                }
                .padding(.horizontal, OpenClawProMetric.pagePadding)
            } else {
                if self.isCompactWidth {
                    VStack(alignment: .leading, spacing: 12) {
                        self.proposalList
                    }
                    .padding(.horizontal, OpenClawProMetric.pagePadding)
                } else {
                    self.proposalBoard
                }
            }
        }
    }

    private var proposalBoard: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(self.visibleProposalLaneStatuses, id: \.self) { status in
                    IPadSkillProposalKanbanColumn(
                        status: status,
                        proposals: self.proposals(forLaneStatus: status),
                        selectedProposalID: self.store.selectedProposalID,
                        inspectingProposalID: self.store.inspectingProposalID,
                        canApplyProposalMutations: self.canApplyProposalMutations,
                        busyAction: self.store.busyAction,
                        select: { proposal in
                            self.selectProposal(
                                proposal,
                                opensSheet: true,
                                forceInspect: false)
                        },
                        inspect: { proposal in
                            self.selectProposal(
                                proposal,
                                opensSheet: true,
                                forceInspect: true)
                        },
                        apply: { proposal in
                            Task { await self.run(.apply, proposal: proposal) }
                        },
                        reject: { proposal in
                            Task { await self.run(.reject, proposal: proposal) }
                        })
                        .frame(width: 282)
                }
            }
            .padding(.horizontal, OpenClawProMetric.pagePadding)
        }
        .scrollIndicators(.visible)
    }

    private var proposalList: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: "Queue",
                    value: "\(self.filteredProposals.count)",
                    actionTitle: nil,
                    action: nil)
                ForEach(Array(self.filteredProposals.enumerated()), id: \.element.id) { index, proposal in
                    if index > 0 {
                        Divider().padding(.leading, 58)
                    }
                    Button {
                        self.selectProposal(
                            proposal,
                            opensSheet: self.isCompactWidth,
                            forceInspect: false)
                    } label: {
                        IPadSkillProposalRow(
                            proposal: proposal,
                            isSelected: proposal.id == self.store.selectedProposalID,
                            isBusy: self.store.inspectingProposalID == proposal.id)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Inspect") {
                            self.selectProposal(
                                proposal,
                                opensSheet: true,
                                forceInspect: true)
                        }
                        if proposal.status == "pending" {
                            Button("Apply") {
                                Task { await self.run(.apply, proposal: proposal) }
                            }
                            .disabled(!self.canApplyProposalMutations || self.store.busyAction != nil)
                            Button("Reject", role: .destructive) {
                                Task { await self.run(.reject, proposal: proposal) }
                            }
                            .disabled(!self.canApplyProposalMutations || self.store.busyAction != nil)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if proposal.status == "pending" {
                            Button("Apply") {
                                Task { await self.run(.apply, proposal: proposal) }
                            }
                            .tint(OpenClawBrand.ok)
                            .disabled(!self.canApplyProposalMutations || self.store.busyAction != nil)
                            Button("Reject", role: .destructive) {
                                Task { await self.run(.reject, proposal: proposal) }
                            }
                            .disabled(!self.canApplyProposalMutations || self.store.busyAction != nil)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("Inspect") {
                            self.selectProposal(
                                proposal,
                                opensSheet: true,
                                forceInspect: true)
                        }
                        .tint(OpenClawBrand.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func presentedProposalDetail(proposalID: String) -> some View {
        if let proposal = proposal(withID: proposalID) {
            self.proposalDetailCard(proposal)
        } else {
            ProCard(radius: OpenClawProMetric.cardRadius) {
                ProStatusRow(
                    icon: "hammer",
                    title: "Proposal unavailable",
                    detail: "Return to the queue and choose another proposal.",
                    value: "missing",
                    color: .secondary,
                    actionTitle: nil,
                    action: nil)
            }
        }
    }

    private func proposalDetailCard(_ proposal: IPadSkillProposal) -> some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ProIconBadge(systemName: "hammer", color: proposal.statusColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(proposal.title)
                            .font(.headline)
                        Text(proposal.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    ProValuePill(value: proposal.status, color: proposal.statusColor)
                }

                if self.store.inspectingProposalID == proposal.id {
                    ProgressView().controlSize(.small)
                }

                if let content = proposal.content, !content.isEmpty {
                    Text(content)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(16)
                        .textSelection(.enabled)
                } else {
                    Text("Select refresh to load the proposal body.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !proposal.supportFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Support files")
                            .font(.subheadline.weight(.semibold))
                        ForEach(proposal.supportFiles, id: \.path) { file in
                            Text(file.path)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                if proposal.status == "pending" {
                    if self.isCompactWidth {
                        VStack(spacing: 8) {
                            self.proposalApplyButton(proposal)
                            self.proposalRejectButton(proposal)
                            self.proposalInspectButton(proposal)
                        }
                    } else {
                        HStack(spacing: 8) {
                            self.proposalApplyButton(proposal)
                            self.proposalRejectButton(proposal)
                            self.proposalInspectButton(proposal)
                        }
                    }
                    if !self.canApplyProposalMutations {
                        self.adminScopeNotice
                    }
                }
            }
        }
    }

    private func proposalApplyButton(_ proposal: IPadSkillProposal) -> some View {
        Button {
            Task { await self.run(.apply, proposal: proposal) }
        } label: {
            Label("Apply", systemImage: "checkmark.circle")
                .frame(maxWidth: self.isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(!self.canApplyProposalMutations || self.store.busyAction != nil)
    }

    private func proposalRejectButton(_ proposal: IPadSkillProposal) -> some View {
        Button(role: .destructive) {
            Task { await self.run(.reject, proposal: proposal) }
        } label: {
            Label("Reject", systemImage: "xmark.circle")
                .frame(maxWidth: self.isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!self.canApplyProposalMutations || self.store.busyAction != nil)
    }

    private func proposalInspectButton(_ proposal: IPadSkillProposal) -> some View {
        Button {
            Task { await self.inspect(proposalID: proposal.id, force: true) }
        } label: {
            Label("Inspect", systemImage: "doc.text.magnifyingglass")
                .frame(maxWidth: self.isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(self.store.inspectingProposalID != nil)
    }

    private var refreshID: String {
        [
            self.canRead ? "connected" : "offline",
            self.scenePhase == .active ? "active" : "inactive",
            self.store.selectedAgentScopeID.isEmpty ? "default" : self.store.selectedAgentScopeID,
        ].joined(separator: ":")
    }

    private var canRead: Bool {
        self.appModel.isOperatorGatewayConnected
    }

    private var canWrite: Bool {
        self.appModel.isOperatorGatewayConnected && !self.appModel.isAppleReviewDemoModeEnabled
    }

    private var canApplyProposalMutations: Bool {
        Self.shouldEnableProposalMutation(
            canWrite: self.canWrite,
            hasOperatorAdminScope: self.appModel.hasOperatorAdminScope)
    }

    private var agentScopeOptions: [IPadSkillWorkshopAgentScope] {
        let defaultID = Self.normalizedScopeID(self.appModel.gatewayDefaultAgentId)
        return self.appModel.gatewayAgents
            .filter { Self.normalizedScopeID($0.id) != defaultID }
            .map { agent in
                let name = Self.normalizedScopeID(agent.name)
                return IPadSkillWorkshopAgentScope(
                    id: Self.normalizedScopeID(agent.id),
                    title: name.isEmpty ? agent.id : name)
            }
            .filter { !$0.id.isEmpty }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var agentScopeLabel: String {
        let selected = Self.normalizedScopeID(self.store.selectedAgentScopeID)
        guard !selected.isEmpty else { return self.defaultAgentScopeLabel }
        return self.agentScopeOptions.first(where: { $0.id == selected })?.title ?? selected
    }

    private var defaultAgentScopeLabel: String {
        let defaultID = Self.normalizedScopeID(self.appModel.gatewayDefaultAgentId)
        if let match = appModel.gatewayAgents.first(where: { Self.normalizedScopeID($0.id) == defaultID }) {
            let name = Self.normalizedScopeID(match.name)
            return name.isEmpty ? "Default agent" : name
        }
        let activeName = Self.normalizedScopeID(self.appModel.activeAgentName)
        return activeName.isEmpty ? "Default agent" : activeName
    }

    nonisolated static func shouldEnableProposalMutation(canWrite: Bool, hasOperatorAdminScope: Bool) -> Bool {
        canWrite && hasOperatorAdminScope
    }

    private var adminScopeNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(OpenClawBrand.warn)
            Text("Admin scope required.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
        }
        .padding(.top, 2)
    }

    private var isCompactWidth: Bool {
        Self.usesCompactTaskFlow(
            horizontalSizeClass: self.horizontalSizeClass,
            verticalSizeClass: self.verticalSizeClass)
    }

    nonisolated static func usesCompactTaskFlow(
        horizontalSizeClass: UserInterfaceSizeClass?,
        verticalSizeClass: UserInterfaceSizeClass?) -> Bool
    {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    nonisolated static let proposalStatusFilters = ["pending", "held", "applied", "rejected", "all"]

    nonisolated static let defaultProposalStatusBoardLanes = ["pending", "quarantined", "stale", "applied", "rejected"]

    nonisolated static func proposalStatusFilterLabel(_ filter: String) -> String {
        switch filter {
        case "pending": "Pending"
        case "held": "Held"
        case "applied": "Applied"
        case "rejected": "Rejected"
        default: "All"
        }
    }

    nonisolated static func proposalLaneLabel(_ status: String) -> String {
        switch status {
        case "quarantined": "Quarantined"
        case "stale": "Stale"
        case "pending", "applied", "rejected":
            self.proposalStatusFilterLabel(status)
        default:
            self.titleCasedProposalStatus(status)
        }
    }

    nonisolated static func titleCasedProposalStatus(_ status: String) -> String {
        status
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                let text = String(word)
                if text == text.uppercased() {
                    return text
                }
                return text.prefix(1).uppercased() + text.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    nonisolated static func proposalStatusBoardLanes(filter: String, proposalStatuses: [String]) -> [String] {
        let customStatuses = proposalStatuses
            .filter { !self.defaultProposalStatusBoardLanes.contains($0) }
            .sorted()
        switch filter {
        case "all":
            return self.defaultProposalStatusBoardLanes + customStatuses
        case "held":
            return ["quarantined", "stale"]
        case "pending", "applied", "rejected":
            return [filter]
        default:
            return [filter]
        }
    }

    nonisolated static func proposalStatusMatchesFilter(status: String, filter: String) -> Bool {
        switch filter {
        case "all":
            true
        case "held":
            status == "quarantined" || status == "stale"
        default:
            status == filter
        }
    }

    nonisolated static func nextSelectedProposalID(
        current: String?,
        proposals: [(id: String, status: String)],
        filter: String) -> String?
    {
        let filtered = proposals.filter { Self.proposalStatusMatchesFilter(status: $0.status, filter: filter) }
        return Self.nextSelectedProposalID(current: current, visibleProposalIDs: filtered.map(\.id))
    }

    nonisolated static func nextSelectedProposalID(current: String?, visibleProposalIDs: [String]) -> String? {
        guard !visibleProposalIDs.isEmpty else { return nil }
        if let current, visibleProposalIDs.contains(current) {
            return current
        }
        return visibleProposalIDs.first
    }

    nonisolated static func normalizedScopeID(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var presentedProposalRouteBinding: Binding<IPadSkillProposalSheetRoute?> {
        Binding(
            get: { self.store.presentedProposalRoute },
            set: { route in
                if route == nil {
                    self.store.send(.proposalSheetDismissed)
                }
            })
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { self.store.query },
            set: { self.store.send(.queryChanged($0)) })
    }

    private var statusFilterBinding: Binding<String> {
        Binding(
            get: { self.store.statusFilter },
            set: { self.store.send(.statusFilterChanged($0)) })
    }

    private var statusFilterLabel: String {
        self.store.statusFilterLabel
    }

    private var filteredProposals: [IPadSkillProposal] {
        self.store.filteredProposals
    }

    private var visibleProposalLaneStatuses: [String] {
        self.store.visibleProposalLaneStatuses
    }

    private func proposals(forLaneStatus status: String) -> [IPadSkillProposal] {
        let trimmedQuery = self.store.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return self.store.proposals
            .filter { $0.status == status }
            .filter { proposal in
                guard !trimmedQuery.isEmpty else { return true }
                return [
                    proposal.title,
                    proposal.description,
                    proposal.skillName,
                    proposal.skillKey,
                ]
                    .joined(separator: " ")
                    .lowercased()
                    .contains(trimmedQuery)
            }
            .sorted { $0.updatedAtMs > $1.updatedAtMs }
    }

    private func count(_ status: String) -> Int {
        self.store.proposals.count(where: { $0.status == status })
    }

    private func proposal(withID id: String) -> IPadSkillProposal? {
        self.store.proposals.first { $0.id == id }
    }

    private func selectProposal(
        _ proposal: IPadSkillProposal,
        opensSheet: Bool,
        forceInspect: Bool)
    {
        Task {
            await self.store.send(.proposalSelected(.init(
                proposalID: proposal.id,
                opensSheet: opensSheet,
                canRead: self.canRead,
                forceInspect: forceInspect))).finish()
        }
    }

    private func loadProposals(force: Bool) async {
        await self.store.send(.refreshRequested(.init(
            sceneActive: self.scenePhase == .active,
            canRead: self.canRead,
            force: force))).finish()
    }

    private func inspect(proposalID: String, force: Bool) async {
        await self.store.send(.inspectRequested(.init(
            proposalID: proposalID,
            canRead: self.canRead,
            force: force))).finish()
    }

    private func run(_ action: IPadSkillProposalAction.Kind, proposal: IPadSkillProposal) async {
        await self.store.send(.proposalMutationRequested(.init(
            kind: action,
            proposalID: proposal.id,
            sceneActive: self.scenePhase == .active,
            canRead: self.canRead,
            canWrite: self.canWrite,
            hasOperatorAdminScope: self.appModel.hasOperatorAdminScope))).finish()
    }
}

struct IPadSkillProposalKanbanColumn: View {
    let status: String
    let proposals: [IPadSkillProposal]
    let selectedProposalID: String?
    let inspectingProposalID: String?
    let canApplyProposalMutations: Bool
    let busyAction: IPadSkillProposalAction?
    let select: (IPadSkillProposal) -> Void
    let inspect: (IPadSkillProposal) -> Void
    let apply: (IPadSkillProposal) -> Void
    let reject: (IPadSkillProposal) -> Void

    var body: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: IPadSkillWorkshopScreen.proposalLaneLabel(self.status),
                    value: "\(self.proposals.count)",
                    actionTitle: nil,
                    action: nil)

                if self.proposals.isEmpty {
                    ProStatusRow(
                        icon: "hammer",
                        title: "No \(IPadSkillWorkshopScreen.proposalLaneLabel(self.status).lowercased()) proposals",
                        detail: "Matching proposals appear here after gateway refresh.",
                        value: "empty",
                        color: .secondary,
                        actionTitle: nil,
                        action: nil)
                } else {
                    ForEach(Array(self.proposals.enumerated()), id: \.element.id) { index, proposal in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        IPadSkillProposalKanbanCard(
                            proposal: proposal,
                            isSelected: proposal.id == self.selectedProposalID,
                            isInspecting: proposal.id == self.inspectingProposalID,
                            canApplyProposalMutations: self.canApplyProposalMutations,
                            isBusy: self.busyAction != nil,
                            select: {
                                self.select(proposal)
                            },
                            inspect: {
                                self.inspect(proposal)
                            },
                            apply: {
                                self.apply(proposal)
                            },
                            reject: {
                                self.reject(proposal)
                            })
                    }
                }
            }
        }
    }
}

private struct IPadSkillProposalKanbanCard: View {
    let proposal: IPadSkillProposal
    let isSelected: Bool
    let isInspecting: Bool
    let canApplyProposalMutations: Bool
    let isBusy: Bool
    let select: () -> Void
    let inspect: () -> Void
    let apply: () -> Void
    let reject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: self.select) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        ProIconBadge(
                            systemName: self.isInspecting ? "hourglass" : "hammer",
                            color: self.proposal.statusColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(self.proposal.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(self.isSelected ? OpenClawBrand.accent : .primary)
                                .lineLimit(2)
                            Text(self.proposal.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    HStack(spacing: 8) {
                        ProValuePill(value: self.proposal.status, color: self.proposal.statusColor)
                        Spacer(minLength: 4)
                        Text(self.proposal.ageLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if self.proposal.status == "pending" {
                    Button(action: self.apply) {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel("Apply Proposal")
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(!self.canApplyProposalMutations || self.isBusy)

                    Button(role: .destructive, action: self.reject) {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Reject Proposal")
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(!self.canApplyProposalMutations || self.isBusy)
                }

                Button(action: self.inspect) {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .accessibilityLabel("Inspect Proposal")
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(self.isInspecting)
            }
        }
        .padding(12)
        .background(
            self.isSelected ? OpenClawBrand.accent.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            Button("Inspect", action: self.inspect)
            if self.proposal.status == "pending" {
                Button("Apply", action: self.apply)
                    .disabled(!self.canApplyProposalMutations || self.isBusy)
                Button("Reject", role: .destructive, action: self.reject)
                    .disabled(!self.canApplyProposalMutations || self.isBusy)
            }
        }
    }
}

struct IPadSkillProposalRow: View {
    let proposal: IPadSkillProposal
    let isSelected: Bool
    let isBusy: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProIconBadge(systemName: self.isBusy ? "hourglass" : "hammer", color: self.proposal.statusColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(self.proposal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(self.isSelected ? OpenClawBrand.accent : .primary)
                    .lineLimit(1)
                Text(self.proposal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(self.proposal.ageLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            self.isSelected ? OpenClawBrand.danger.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// swiftformat:disable redundantSendable
struct IPadSkillProposalSheetRoute: Equatable, Identifiable, Sendable {
    let proposalID: String

    var id: String {
        self.proposalID
    }
}

struct IPadSkillProposalAction: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case apply
        case reject
    }

    let kind: Kind
    let proposalID: String
}

struct IPadSkillProposalManifest: Decodable, Equatable, Sendable {
    let proposals: [IPadSkillProposalManifestEntry]
}

struct IPadSkillProposalManifestEntry: Decodable, Equatable, Sendable {
    let id: String
    let kind: String
    let status: String
    let title: String
    let description: String
    let skillName: String
    let skillKey: String
    let createdAt: String
    let updatedAt: String
    let scanState: String
}

private struct IPadSkillWorkshopAgentScope: Identifiable {
    let id: String
    let title: String
}

private struct IPadSkillProposalListParams: Encodable {
    let agentId: String?
}

private struct IPadSkillProposalInspectParams: Encodable {
    let agentId: String?
    let proposalId: String
}

struct IPadSkillProposalInspectResponse: Decodable, Equatable, Sendable {
    let record: IPadSkillProposalRecord
    let content: String
    let supportFiles: [IPadSkillProposalSupportFile]?
}

struct IPadSkillProposalRecord: Decodable, Equatable, Sendable {
    let id: String
    let kind: String
    let status: String
    let title: String
    let description: String
    let createdAt: String
    let updatedAt: String
    let target: IPadSkillProposalTarget
}

struct IPadSkillProposalTarget: Decodable, Equatable, Sendable {
    let skillName: String
    let skillKey: String
}

struct IPadSkillProposalSupportFile: Decodable, Equatable, Sendable {
    let path: String
    let content: String?
}

struct IPadSkillProposal: Equatable, Identifiable, Sendable {
    let id: String
    let kind: String
    let status: String
    let title: String
    let description: String
    let skillName: String
    let skillKey: String
    let createdAtMs: Double
    let updatedAtMs: Double
    var content: String?
    var supportFiles: [IPadSkillProposalSupportFile]

    init(entry: IPadSkillProposalManifestEntry, previous: IPadSkillProposal?) {
        self.id = entry.id
        self.kind = entry.kind
        self.status = entry.status
        self.title = entry.title.isEmpty ? entry.skillName : entry.title
        self.description = entry.description
        self.skillName = entry.skillName
        self.skillKey = entry.skillKey
        self.createdAtMs = Self.parseDate(entry.createdAt)
        self.updatedAtMs = Self.parseDate(entry.updatedAt)
        self.content = previous?.updatedAtMs == self.updatedAtMs ? previous?.content : nil
        self.supportFiles = previous?.updatedAtMs == self.updatedAtMs ? previous?.supportFiles ?? [] : []
    }

    init(inspect: IPadSkillProposalInspectResponse, previous: IPadSkillProposal?) {
        let record = inspect.record
        self.id = record.id
        self.kind = record.kind
        self.status = record.status
        self.title = record.title.isEmpty ? record.target.skillName : record.title
        self.description = record.description
        self.skillName = record.target.skillName
        self.skillKey = record.target.skillKey
        self.createdAtMs = Self.parseDate(record.createdAt)
        self.updatedAtMs = Self.parseDate(record.updatedAt)
        self.content = Self.stripFrontmatter(inspect.content)
        self.supportFiles = inspect.supportFiles ?? previous?.supportFiles ?? []
    }

    var ageLabel: String {
        let diff = max(0, Date().timeIntervalSince1970 * 1000 - self.updatedAtMs)
        let minutes = Int(diff / 60000)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    var statusColor: Color {
        switch self.status {
        case "pending": OpenClawBrand.warn
        case "applied": OpenClawBrand.ok
        case "rejected": .secondary
        case "quarantined", "stale": OpenClawBrand.warn
        default: OpenClawBrand.accent
        }
    }

    private static func parseDate(_ value: String) -> Double {
        (ISO8601DateFormatter().date(from: value)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970) * 1000
    }

    private static func stripFrontmatter(_ value: String) -> String {
        let pattern = #"(?s)^---\r?\n.*?\r?\n---\r?\n?"#
        return value.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// swiftformat:enable redundantSendable
