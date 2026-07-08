import ComposableArchitecture
import OpenClawKit
import SwiftUI

@Reducer
struct IPadSkillWorkshopFeature {
    private let clientOverride: IPadSkillWorkshopClient?

    init(client: IPadSkillWorkshopClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var proposalEntries = IPadSkillWorkshopProposals()
        var selectedProposalID: IPadSkillWorkshopProposalID?
        var selectedAgentScopeID = IPadSkillWorkshopSelectedAgentScopeID(value: "")
        var gatewayDefaultAgentID = IPadSkillWorkshopGatewayDefaultAgentID(value: nil)
        var gatewayAgentEntries = IPadSkillWorkshopGatewayAgents()
        var activeAgentName = IPadSkillWorkshopActiveAgentName(value: "Default Agent")
        var statusFilter = IPadSkillWorkshopStatusFilter(value: "pending")
        var query = IPadSkillWorkshopQuery(value: "")
        var loadingPhase = IPadSkillWorkshopLoadingPhase.idle
        var inspectingProposalID: IPadSkillWorkshopProposalID?
        var busyAction: IPadSkillProposalAction?
        var errorText: IPadSkillWorkshopFailureMessage?
        var noticeText: IPadSkillWorkshopNoticeMessage?
        var presentedProposalRoute: IPadSkillProposalSheetRoute?

        var proposals: [IPadSkillProposal] {
            self.proposalEntries.values
        }

        var selectedAgentParam: String? {
            let selected = Self.normalizedScopeID(self.selectedAgentScopeID.value)
            return selected.isEmpty ? nil : selected
        }

        var gatewayAgents: [IPadSkillWorkshopGatewayAgent] {
            self.gatewayAgentEntries.values
        }

        var agentScopeOptions: [IPadSkillWorkshopAgentScopeOption] {
            let defaultID = Self.normalizedScopeID(self.gatewayDefaultAgentID.value)
            return self.gatewayAgents
                .filter { Self.normalizedScopeID($0.id) != defaultID }
                .map { agent in
                    let name = Self.normalizedScopeID(agent.name)
                    return IPadSkillWorkshopAgentScopeOption(
                        id: Self.normalizedScopeID(agent.id),
                        title: name.isEmpty ? agent.id : name)
                }
                .filter { !$0.id.isEmpty }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        var agentScopeLabel: String {
            let selected = Self.normalizedScopeID(self.selectedAgentScopeID.value)
            guard !selected.isEmpty else { return self.defaultAgentScopeLabel }
            return self.agentScopeOptions.first(where: { $0.id == selected })?.title ?? selected
        }

        var defaultAgentScopeLabel: String {
            let defaultID = Self.normalizedScopeID(self.gatewayDefaultAgentID.value)
            if let match = self.gatewayAgents
                .first(where: { Self.normalizedScopeID($0.id) == defaultID })
            {
                let name = Self.normalizedScopeID(match.name)
                return name.isEmpty ? "Default agent" : name
            }
            let activeName = Self.normalizedScopeID(self.activeAgentName.value)
            return activeName.isEmpty ? "Default agent" : activeName
        }

        var agentScopeMenuPresentation: IPadSkillWorkshopAgentScopeMenuPresentation {
            let options = self.agentScopeOptions
            return .init(
                title: "Agent",
                selectedLabel: self.agentScopeLabel,
                selectorIconSystemName: "chevron.up.chevron.down",
                accessibilityLabel: "Skill Workshop agent scope",
                options: [IPadSkillWorkshopAgentScopeOption(id: "", title: "Default agent")] + options,
                isEnabled: !options.isEmpty)
        }

        static func normalizedScopeID(_ value: String?) -> String {
            (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func gatewayAccess(
            isOperatorGatewayConnected: Bool,
            isAppleReviewDemoModeEnabled: Bool,
            hasOperatorAdminScope: Bool) -> IPadSkillWorkshopGatewayAccess
        {
            .init(
                canRead: isOperatorGatewayConnected,
                canWrite: isOperatorGatewayConnected && !isAppleReviewDemoModeEnabled,
                hasOperatorAdminScope: hasOperatorAdminScope)
        }

        func refreshTaskID(gatewayAccess: IPadSkillWorkshopGatewayAccess, sceneIsActive: Bool) -> String {
            let connection = gatewayAccess.canRead ? "connected" : "offline"
            let scene = sceneIsActive ? "active" : "inactive"
            let agent = self.selectedAgentScopeID.value.isEmpty ? "default" : self.selectedAgentScopeID.value
            return [connection, scene, agent].joined(separator: ":")
        }

        var isRefreshInFlight: Bool {
            self.loadingPhase == .inFlight
        }

        var refreshControlPresentation: IPadSkillWorkshopRefreshControlPresentation {
            .init(
                title: "Refresh",
                iconSystemName: "arrow.clockwise",
                isDisabled: self.isRefreshInFlight,
                showsProgress: self.isRefreshInFlight)
        }

        var queryFieldPresentation: IPadSkillWorkshopQueryFieldPresentation {
            .init(
                text: self.query.value,
                placeholder: "Search proposals",
                iconSystemName: "magnifyingglass",
                clearButtonSystemName: "xmark.circle.fill",
                showsClearButton: !self.query.value.isEmpty)
        }

        var feedbackMessages: [IPadSkillWorkshopFeedbackPresentation] {
            var messages: [IPadSkillWorkshopFeedbackPresentation] = []
            if let noticeText {
                messages.append(.init(tone: .notice, text: noticeText.value))
            }
            if let errorText {
                messages.append(.init(tone: .error, text: errorText.value))
            }
            return messages
        }

        func shouldEnableProposalMutation(gatewayAccess: IPadSkillWorkshopGatewayAccess) -> Bool {
            gatewayAccess.canWrite && gatewayAccess.hasOperatorAdminScope
        }

        func shouldEnableProposalActionControls(gatewayAccess: IPadSkillWorkshopGatewayAccess) -> Bool {
            self.proposalActionControlsPresentation(gatewayAccess: gatewayAccess).canRunActions
        }

        func proposalActionControlsPresentation(
            gatewayAccess: IPadSkillWorkshopGatewayAccess) -> IPadSkillWorkshopProposalActionControlsPresentation
        {
            let canApplyMutations = self.shouldEnableProposalMutation(gatewayAccess: gatewayAccess)
            return .init(
                applyButton: .init(
                    title: "Apply",
                    iconSystemName: "checkmark.circle",
                    accessibilityLabel: "Apply Proposal"),
                rejectButton: .init(
                    title: "Reject",
                    iconSystemName: "xmark.circle",
                    accessibilityLabel: "Reject Proposal"),
                canApplyMutations: canApplyMutations,
                canRunActions: canApplyMutations && self.busyAction == nil,
                adminScopeNotice: canApplyMutations ? nil : .init(
                    iconSystemName: "lock.shield",
                    text: "Admin scope required."))
        }

        func emptyProposalPresentation(
            gatewayAccess: IPadSkillWorkshopGatewayAccess) -> IPadSkillWorkshopEmptyProposalPresentation
        {
            if gatewayAccess.canRead {
                return .init(
                    icon: "hammer",
                    title: "No proposals",
                    detail: "New proposals will appear here when agents draft skills.",
                    value: "empty")
            }
            return .init(
                icon: "wifi.slash",
                title: "No proposals loaded",
                detail: "Connect from Settings to load Skill Workshop proposals.",
                value: nil)
        }

        var proposalUnavailablePresentation: IPadSkillWorkshopEmptyProposalPresentation {
            .init(
                icon: "hammer",
                title: "Proposal unavailable",
                detail: "Return to the queue and choose another proposal.",
                value: "missing")
        }

        var proposalSheetPresentation: IPadSkillWorkshopProposalSheetPresentation {
            .init(title: "Proposal", dismissButtonTitle: "Done")
        }

        var screenChromePresentation: IPadSkillWorkshopScreenChromePresentation {
            .init(title: "Skill Workshop", subtitle: "Review and apply proposed skills.")
        }

        func screenPresentation(
            gatewayAccess: IPadSkillWorkshopGatewayAccess,
            sceneIsActive: Bool) -> IPadSkillWorkshopScreenPresentation
        {
            .init(
                screenChromePresentation: self.screenChromePresentation,
                refreshTaskID: self.refreshTaskID(gatewayAccess: gatewayAccess, sceneIsActive: sceneIsActive),
                refreshControlPresentation: self.refreshControlPresentation,
                statusFilterControlPresentation: self.statusFilterControlPresentation,
                queryFieldPresentation: self.queryFieldPresentation,
                feedbackMessages: self.feedbackMessages,
                queueSummaryPresentation: self.queueSummaryPresentation,
                metricPresentations: self.metricPresentations,
                agentScopeMenuPresentation: self.agentScopeMenuPresentation,
                proposalListPresentation: self.proposalListPresentation,
                proposalBoardPresentation: self.proposalBoardPresentation,
                proposalActionControlsPresentation: self.proposalActionControlsPresentation(
                    gatewayAccess: gatewayAccess),
                proposalInspectionControlsPresentation: self.proposalInspectionControlsPresentation,
                emptyProposalPresentation: self.emptyProposalPresentation(gatewayAccess: gatewayAccess),
                proposalUnavailablePresentation: self.proposalUnavailablePresentation,
                presentedProposalPresentation: self.presentedProposalPresentation,
                proposalSheetPresentation: self.proposalSheetPresentation)
        }

        static func shouldShowProposalActions(status: String) -> Bool {
            status == "pending"
        }

        func shouldShowProposalActions(for proposal: IPadSkillProposal) -> Bool {
            Self.shouldShowProposalActions(status: proposal.status)
        }

        static let proposalStatusFilters = ["pending", "held", "applied", "rejected", "all"]
        static let defaultProposalStatusBoardLanes = ["pending", "quarantined", "stale", "applied", "rejected"]

        static func proposalStatusFilterLabel(_ filter: String) -> String {
            switch filter {
            case "pending": "Pending"
            case "held": "Held"
            case "applied": "Applied"
            case "rejected": "Rejected"
            default: "All"
            }
        }

        static func proposalLaneLabel(_ status: String) -> String {
            switch status {
            case "quarantined": "Quarantined"
            case "stale": "Stale"
            case "pending", "applied", "rejected":
                self.proposalStatusFilterLabel(status)
            default:
                self.titleCasedProposalStatus(status)
            }
        }

        private static func titleCasedProposalStatus(_ status: String) -> String {
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

        var statusFilterLabel: String {
            Self.proposalStatusFilterLabel(self.statusFilter.value)
        }

        var statusFilterControlPresentation: IPadSkillWorkshopStatusFilterControlPresentation {
            .init(
                title: "Status",
                selectedFilter: self.statusFilter.value,
                selectedLabel: self.statusFilterLabel,
                options: Self.proposalStatusFilters.map { filter in
                    IPadSkillWorkshopStatusFilterOption(
                        id: filter,
                        title: Self.proposalStatusFilterLabel(filter))
                })
        }

        static func proposalStatusMatchesFilter(status: String, filter: String) -> Bool {
            switch filter {
            case "all": true
            case "held": status == "quarantined" || status == "stale"
            default: status == filter
            }
        }

        static func proposalStatusBoardLanes(filter: String, proposalStatuses: [String]) -> [String] {
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

        static func nextSelectedProposalID(
            current: String?,
            proposals: [(id: String, status: String)],
            filter: String) -> String?
        {
            let filtered = proposals.filter { Self.proposalStatusMatchesFilter(status: $0.status, filter: filter) }
            return Self.nextSelectedProposalID(current: current, visibleProposalIDs: filtered.map(\.id))
        }

        static func nextSelectedProposalID(current: String?, visibleProposalIDs: [String]) -> String? {
            guard !visibleProposalIDs.isEmpty else { return nil }
            if let current, visibleProposalIDs.contains(current) {
                return current
            }
            return visibleProposalIDs.first
        }

        var filteredProposals: [IPadSkillProposal] {
            Self.filteredProposals(
                proposals: self.proposals,
                statusFilter: self.statusFilter.value,
                query: self.query.value)
        }

        var filteredProposalCount: Int {
            self.filteredProposals.count
        }

        var queueSummaryPresentation: IPadSkillWorkshopQueueSummaryPresentation {
            .init(
                title: "Queue",
                proposalCount: self.filteredProposalCount,
                value: "\(self.filteredProposalCount)",
                proposalCountLabel: "\(self.filteredProposalCount) proposals",
                statusLabel: self.statusFilterLabel)
        }

        var pendingProposalCount: Int {
            self.proposalCount(forStatus: "pending")
        }

        var appliedProposalCount: Int {
            self.proposalCount(forStatus: "applied")
        }

        var heldProposalCount: Int {
            self.proposalCount(forStatus: "quarantined") + self.proposalCount(forStatus: "stale")
        }

        var metricPresentations: [IPadSkillWorkshopMetricPresentation] {
            [
                .init(id: .pending, icon: "clock", title: "Pending", value: "\(self.pendingProposalCount)"),
                .init(id: .applied, icon: "checkmark.circle", title: "Applied", value: "\(self.appliedProposalCount)"),
                .init(id: .held, icon: "shield", title: "Held", value: "\(self.heldProposalCount)"),
            ]
        }

        var visibleProposalLaneStatuses: [String] {
            Self.proposalStatusBoardLanes(
                filter: self.statusFilter.value,
                proposalStatuses: self.proposals.map(\.status))
        }

        func proposals(forLaneStatus status: String) -> [IPadSkillProposal] {
            Self.filteredProposals(
                proposals: self.proposals.filter { $0.status == status },
                statusFilter: "all",
                query: self.query.value)
                .sorted { $0.updatedAtMs > $1.updatedAtMs }
        }

        func proposal(withID id: String) -> IPadSkillProposal? {
            self.proposals.first { $0.id == id }
        }

        func proposalCardPresentation(
            for proposal: IPadSkillProposal) -> IPadSkillWorkshopProposalCardPresentation
        {
            .init(
                proposal: proposal,
                iconSystemName: proposal.id == self.inspectingProposalID?.value ? "hourglass" : "hammer",
                isSelected: proposal.id == self.selectedProposalID?.value,
                isInspecting: proposal.id == self.inspectingProposalID?.value,
                showsProposalActions: self.shouldShowProposalActions(for: proposal))
        }

        var proposalListPresentation: IPadSkillWorkshopProposalListPresentation {
            .init(proposals: self.filteredProposals.map { proposal in
                self.proposalCardPresentation(for: proposal)
            })
        }

        var proposalBoardPresentation: IPadSkillWorkshopProposalBoardPresentation {
            .init(lanes: self.visibleProposalLaneStatuses.map { status in
                let title = Self.proposalLaneLabel(status)
                let proposals = self.proposals(forLaneStatus: status).map { proposal in
                    self.proposalCardPresentation(for: proposal)
                }
                return IPadSkillWorkshopProposalLanePresentation(
                    id: status,
                    title: title,
                    value: "\(proposals.count)",
                    emptyPresentation: .init(
                        icon: "hammer",
                        title: "No \(title.lowercased()) proposals",
                        detail: "Matching proposals appear here after gateway refresh.",
                        value: "empty"),
                    proposals: proposals)
            })
        }

        func proposalDetailPresentation(
            for proposal: IPadSkillProposal) -> IPadSkillWorkshopProposalDetailPresentation
        {
            let bodyText = proposal.content.flatMap { content in
                content.isEmpty ? nil : content
            }
            return .init(
                card: self.proposalCardPresentation(for: proposal),
                bodyText: bodyText,
                emptyBodyText: "Select refresh to load the proposal body.",
                supportFilesTitle: "Support files",
                supportFiles: proposal.supportFiles,
                showsSupportFiles: !proposal.supportFiles.isEmpty)
        }

        func proposalDetailPresentation(
            forID id: String) -> IPadSkillWorkshopProposalDetailPresentation?
        {
            self.proposal(withID: id).map { proposal in
                self.proposalDetailPresentation(for: proposal)
            }
        }

        var presentedProposalPresentation: IPadSkillWorkshopProposalDetailPresentation? {
            guard let proposalID = self.presentedProposalRoute?.proposalID else { return nil }
            return self.proposalDetailPresentation(forID: proposalID)
        }

        var proposalInspectionControlsPresentation: IPadSkillWorkshopProposalInspectionControlsPresentation {
            .init(
                title: "Inspect",
                iconSystemName: "doc.text.magnifyingglass",
                accessibilityLabel: "Inspect Proposal",
                canInspect: self.inspectingProposalID == nil)
        }

        private func proposalCount(forStatus status: String) -> Int {
            self.proposals.count(where: { $0.status == status })
        }

        mutating func syncSelectedProposalIDForVisibleProposals() {
            let nextID = Self.nextSelectedProposalID(
                current: self.selectedProposalID?.value,
                visibleProposalIDs: self.filteredProposals.map(\.id))
            let nextProposalID = nextID.map { IPadSkillWorkshopProposalID(value: $0) }
            guard self.selectedProposalID != nextProposalID else { return }
            self.selectedProposalID = nextProposalID
        }

        mutating func merge(_ proposal: IPadSkillProposal) {
            var proposalValues = self.proposalEntries.values
            proposalValues.removeAll { $0.id == proposal.id }
            proposalValues.append(proposal)
            proposalValues.sort { $0.updatedAtMs > $1.updatedAtMs }
            self.proposalEntries = .init(values: proposalValues)
        }

        private static func filteredProposals(
            proposals: [IPadSkillProposal],
            statusFilter: String,
            query: String) -> [IPadSkillProposal]
        {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return proposals
                .filter { proposal in
                    Self.proposalStatusMatchesFilter(
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
        struct SceneActivity: Equatable, Sendable { var isActive: Bool }
        struct GatewayReadAccess: Equatable, Sendable { var canRead: Bool }
        struct GatewayWriteAccess: Equatable, Sendable { var canWrite: Bool }
        struct OperatorAdminAccess: Equatable, Sendable { var hasOperatorAdminScope: Bool }
        struct RefreshForce: Equatable, Sendable { var isForced: Bool }
        struct InspectionForce: Equatable, Sendable { var isForced: Bool }
        enum ProposalSheetOpening: Equatable, Sendable {
            case inline
            case sheet
        }

        struct AgentScopeChange: Equatable, Sendable {
            var agentID: IPadSkillWorkshopSelectedAgentScopeID
        }

        case agentScopeChanged(AgentScopeChange)

        struct AgentScopeSnapshot: Equatable, Sendable {
            var gatewayDefaultAgentID: IPadSkillWorkshopGatewayDefaultAgentID
            var gatewayAgents: IPadSkillWorkshopGatewayAgents
            var activeAgentName: IPadSkillWorkshopActiveAgentName
        }

        case agentScopeSnapshotChanged(AgentScopeSnapshot)
        case clearQueryTapped

        struct InspectRequest: Equatable, Sendable {
            var proposalID: IPadSkillWorkshopProposalID
            var readAccess: GatewayReadAccess
            var force: InspectionForce
        }

        struct InspectResponse: Equatable, Sendable {
            var proposalID: IPadSkillWorkshopProposalID
            var result: Result<IPadSkillProposalInspectResponse, IPadSkillWorkshopError>
        }

        case inspectRequested(InspectRequest)
        case inspectResponse(InspectResponse)

        struct ProposalMutationRequest: Equatable, Sendable {
            var kind: IPadSkillProposalAction.Kind
            var proposalID: IPadSkillWorkshopProposalID
            var sceneActivity: SceneActivity
            var readAccess: GatewayReadAccess
            var writeAccess: GatewayWriteAccess
            var adminAccess: OperatorAdminAccess
        }

        struct ProposalMutationSuccess: Equatable, Sendable {}

        struct ProposalMutationResponse: Equatable, Sendable {
            var kind: IPadSkillProposalAction.Kind
            var sceneActivity: SceneActivity
            var readAccess: GatewayReadAccess
            var result: Result<ProposalMutationSuccess, IPadSkillWorkshopError>
        }

        case proposalMutationRequested(ProposalMutationRequest)
        case proposalMutationResponse(ProposalMutationResponse)

        struct ProposalSelectionRequest: Equatable, Sendable {
            var proposalID: IPadSkillWorkshopProposalID
            var opening: ProposalSheetOpening
            var readAccess: GatewayReadAccess
            var forceInspect: InspectionForce
        }

        struct QueryChange: Equatable, Sendable {
            var query: IPadSkillWorkshopQuery
        }

        struct RefreshRequest: Equatable, Sendable {
            var sceneActivity: SceneActivity
            var readAccess: GatewayReadAccess
            var force: RefreshForce
        }

        struct RefreshResponse: Equatable, Sendable {
            var force: RefreshForce
            var result: Result<IPadSkillProposalManifest, IPadSkillWorkshopError>
        }

        case proposalSelected(ProposalSelectionRequest)
        case proposalSheetDismissed
        case queryChanged(QueryChange)
        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)

        struct StatusFilterChange: Equatable, Sendable {
            var filter: IPadSkillWorkshopStatusFilter
        }

        case statusFilterChanged(StatusFilterChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.iPadSkillWorkshop) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .agentScopeChanged(change):
                state.selectedAgentScopeID = .init(
                    value: IPadSkillWorkshopFeature.State.normalizedScopeID(change.agentID.value))
                return .none

            case let .agentScopeSnapshotChanged(snapshot):
                state.gatewayDefaultAgentID = snapshot.gatewayDefaultAgentID
                state.gatewayAgentEntries = snapshot.gatewayAgents
                state.activeAgentName = snapshot.activeAgentName
                return .none

            case .clearQueryTapped:
                state.query = .init(value: "")
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
                    let previous = state.proposals.first { $0.id == response.proposalID.value }
                    state.merge(IPadSkillProposal(inspect: inspectResponse, previous: previous))
                    return .none

                case let .failure(error):
                    state.inspectingProposalID = nil
                    state.errorText = .init(value: error.message)
                    return .none
                }

            case let .proposalMutationRequested(request):
                guard state.shouldEnableProposalActionControls(
                    gatewayAccess: .init(
                        canRead: request.readAccess.canRead,
                        canWrite: request.writeAccess.canWrite,
                        hasOperatorAdminScope: request.adminAccess.hasOperatorAdminScope))
                else {
                    return .none
                }

                state.busyAction = IPadSkillProposalAction(kind: request.kind, proposalID: request.proposalID.value)
                state.errorText = nil
                state.noticeText = nil
                let agentScope = IPadSkillWorkshopAgentScopeParam(agentID: state.selectedAgentParam)
                return .run { send in
                    do {
                        try await client.run(request.kind, agentScope, request.proposalID)
                        await send(.proposalMutationResponse(.init(
                            kind: request.kind,
                            sceneActivity: request.sceneActivity,
                            readAccess: request.readAccess,
                            result: .success(.init()))))
                    } catch {
                        await send(.proposalMutationResponse(.init(
                            kind: request.kind,
                            sceneActivity: request.sceneActivity,
                            readAccess: request.readAccess,
                            result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .proposalMutationResponse(response):
                switch response.result {
                case .success:
                    state.busyAction = nil
                    state.noticeText = .init(
                        value: response.kind == .apply ? "Proposal applied." : "Proposal rejected.")
                    return .run { send in
                        await send(.refreshRequested(.init(
                            sceneActivity: response.sceneActivity,
                            readAccess: response.readAccess,
                            force: .init(isForced: true))))
                    }

                case let .failure(error):
                    state.busyAction = nil
                    state.errorText = .init(value: error.message)
                    return .none
                }

            case let .proposalSelected(request):
                state.selectedProposalID = request.proposalID
                if request.opening == .sheet {
                    state.presentedProposalRoute = IPadSkillProposalSheetRoute(proposalID: request.proposalID.value)
                }
                return self.inspectEffect(
                    state: &state,
                    client: client,
                    request: .init(
                        proposalID: request.proposalID,
                        readAccess: request.readAccess,
                        force: request.forceInspect))

            case .proposalSheetDismissed:
                state.presentedProposalRoute = nil
                return .none

            case let .queryChanged(change):
                state.query = change.query
                state.syncSelectedProposalIDForVisibleProposals()
                return .none

            case let .refreshRequested(request):
                guard request.sceneActivity.isActive else {
                    state.loadingPhase = .idle
                    return .none
                }
                guard request.readAccess.canRead else {
                    state.proposalEntries = .init()
                    state.errorText = nil
                    state.loadingPhase = .idle
                    state.inspectingProposalID = nil
                    return .none
                }
                guard !state.isRefreshInFlight else { return .none }

                state.loadingPhase = .inFlight
                state.errorText = nil
                let agentScope = IPadSkillWorkshopAgentScopeParam(agentID: state.selectedAgentParam)
                return .run { send in
                    do {
                        let manifest = try await client.list(agentScope)
                        await send(.refreshResponse(.init(
                            force: request.force,
                            result: .success(manifest))))
                    } catch {
                        await send(.refreshResponse(.init(
                            force: request.force,
                            result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .refreshResponse(response):
                state.loadingPhase = .idle
                switch response.result {
                case let .success(manifest):
                    let previousByID = Dictionary(uniqueKeysWithValues: state.proposals.map { ($0.id, $0) })
                    let proposalValues = manifest.proposals
                        .map { IPadSkillProposal(entry: $0, previous: previousByID[$0.id]) }
                        .sorted { $0.updatedAtMs > $1.updatedAtMs }
                    state.proposalEntries = .init(values: proposalValues)
                    state.syncSelectedProposalIDForVisibleProposals()
                    guard let proposalID = state.selectedProposalID else { return .none }
                    return self.inspectEffect(
                        state: &state,
                        client: client,
                        request: .init(
                            proposalID: proposalID,
                            readAccess: .init(canRead: true),
                            force: .init(isForced: response.force.isForced)))

                case let .failure(error):
                    if response.force.isForced || state.proposals.isEmpty {
                        state.errorText = .init(value: error.message)
                    }
                    return .none
                }

            case let .statusFilterChanged(change):
                state.statusFilter = change.filter
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
        guard request.readAccess.canRead else { return .none }
        let existingContent = state.proposals.first(where: { $0.id == request.proposalID.value })?.content
        guard request.force.isForced || existingContent == nil else { return .none }
        guard state.inspectingProposalID == nil else { return .none }

        state.inspectingProposalID = request.proposalID
        state.errorText = nil
        let agentScope = IPadSkillWorkshopAgentScopeParam(agentID: state.selectedAgentParam)
        return .run { send in
            do {
                let response = try await client.inspect(agentScope, request.proposalID)
                await send(.inspectResponse(.init(
                    proposalID: request.proposalID,
                    result: .success(response))))
            } catch {
                await send(.inspectResponse(.init(
                    proposalID: request.proposalID,
                    result: .failure(Self.failure(for: error)))))
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

    private static func failure(for error: Error) -> IPadSkillWorkshopError {
        .failed(.init(message: .init(value: self.message(for: error))))
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
        store: StoreOf<IPadSkillWorkshopFeature>? = nil,
        storeFactory: () -> StoreOf<IPadSkillWorkshopFeature> = {
            Store(initialState: IPadSkillWorkshopFeature.State()) {
                IPadSkillWorkshopFeature()
            }
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.openSettings = openSettings
        let resolvedStore = store ?? storeFactory()
        self._store = State(wrappedValue: resolvedStore)
    }

    var body: some View {
        IPadSidebarScreenChrome(
            title: self.screenPresentation.screenChromePresentation.title,
            subtitle: self.screenPresentation.screenChromePresentation.subtitle,
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
        .task(id: self.refreshTaskID) {
            await self.loadProposals(force: false)
        }
        .task(id: self.agentScopeSnapshot) {
            self.store.send(.agentScopeSnapshotChanged(self.agentScopeSnapshot))
        }
        .refreshable {
            await self.loadProposals(force: true)
        }
        .sheet(item: self.presentedProposalRouteBinding) { _ in
            NavigationStack {
                ScrollView {
                    self.presentedProposalDetail
                        .padding(.horizontal, OpenClawProMetric.pagePadding)
                        .padding(.vertical, 16)
                }
                .background(OpenClawProBackground())
                .navigationTitle(self.proposalSheetPresentation.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(self.proposalSheetPresentation.dismissButtonTitle) {
                            self.store.send(.proposalSheetDismissed)
                        }
                    }
                }
            }
        }
    }

    private var metrics: [ProMetric] {
        self.screenPresentation.metricPresentations.map { presentation in
            ProMetric(
                icon: presentation.icon,
                title: presentation.title,
                value: presentation.value,
                color: presentation.id.color)
        }
    }

    private var filtersCard: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 12) {
                let refreshPresentation = self.screenPresentation.refreshControlPresentation
                let statusFilterPresentation = self.screenPresentation.statusFilterControlPresentation
                self.agentScopeMenu
                self.proposalSearchField
                Picker(statusFilterPresentation.title, selection: self.statusFilterBinding) {
                    ForEach(statusFilterPresentation.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .tint(OpenClawBrand.accent)
                HStack(spacing: 8) {
                    Button {
                        Task { await self.loadProposals(force: true) }
                    } label: {
                        Label(refreshPresentation.title, systemImage: refreshPresentation.iconSystemName)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(self.neutralControlTint)
                    .disabled(refreshPresentation.isDisabled)

                    if refreshPresentation.showsProgress { ProgressView().controlSize(.small) }
                }
                self.feedbackMessageRows
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var compactFiltersCard: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 12) {
                let refreshPresentation = self.screenPresentation.refreshControlPresentation
                let statusFilterPresentation = self.screenPresentation.statusFilterControlPresentation
                let queueSummary = self.screenPresentation.queueSummaryPresentation
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(queueSummary.proposalCountLabel)
                            .font(.headline)
                        Text(queueSummary.statusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if refreshPresentation.showsProgress { ProgressView().controlSize(.small) }
                }

                self.agentScopeMenu
                Picker(statusFilterPresentation.title, selection: self.statusFilterBinding) {
                    ForEach(statusFilterPresentation.options) { option in
                        Text(option.title).tag(option.id)
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
                        Label(refreshPresentation.title, systemImage: refreshPresentation.iconSystemName)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(self.neutralControlTint)
                    .disabled(refreshPresentation.isDisabled)
                }
                self.feedbackMessageRows
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var feedbackMessageRows: some View {
        ForEach(self.screenPresentation.feedbackMessages) { message in
            Text(message.text)
                .font(.caption2)
                .foregroundStyle(message.color)
        }
    }

    private var proposalSearchField: some View {
        let presentation = self.screenPresentation.queryFieldPresentation
        return HStack(spacing: 8) {
            Image(systemName: presentation.iconSystemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(presentation.placeholder, text: self.queryBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
            if presentation.showsClearButton {
                Button {
                    self.store.send(.clearQueryTapped)
                } label: {
                    Image(systemName: presentation.clearButtonSystemName)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var agentScopeMenu: some View {
        let presentation = self.screenPresentation.agentScopeMenuPresentation
        return HStack(spacing: 8) {
            Text(presentation.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Menu {
                ForEach(presentation.options, id: \.id) { option in
                    Button(option.title) {
                        self.store.send(.agentScopeChanged(.init(agentID: .init(value: option.id))))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(presentation.selectedLabel)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: presentation.selectorIconSystemName)
                        .font(.caption2.weight(.bold))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(self.neutralControlTint)
            .disabled(!presentation.isEnabled)
            .accessibilityLabel(presentation.accessibilityLabel)
        }
    }

    private var neutralControlTint: Color {
        Color.primary.opacity(0.55)
    }

    private var proposalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if self.screenPresentation.proposalListPresentation.isEmpty {
                ProCard(radius: OpenClawProMetric.cardRadius) {
                    ProStatusRow(
                        icon: self.emptyProposalPresentation.icon,
                        title: self.emptyProposalPresentation.title,
                        detail: self.emptyProposalPresentation.detail,
                        value: self.emptyProposalPresentation.value,
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
                let boardPresentation = self.screenPresentation.proposalBoardPresentation
                let actionControlsPresentation = self.proposalActionControlsPresentation
                let inspectionControlsPresentation = self.proposalInspectionControlsPresentation
                ForEach(boardPresentation.lanes) { lane in
                    IPadSkillProposalKanbanColumn(
                        lane: lane,
                        actionControlsPresentation: actionControlsPresentation,
                        inspectionControlsPresentation: inspectionControlsPresentation,
                        select: { presentation in
                            self.selectProposal(
                                presentation.proposal,
                                opening: .sheet,
                                forceInspect: false)
                        },
                        inspect: { presentation in
                            self.selectProposal(
                                presentation.proposal,
                                opening: .sheet,
                                forceInspect: true)
                        },
                        apply: { presentation in
                            Task { await self.run(.apply, proposal: presentation.proposal) }
                        },
                        reject: { presentation in
                            Task { await self.run(.reject, proposal: presentation.proposal) }
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
                let queueSummary = self.screenPresentation.queueSummaryPresentation
                let listPresentation = self.screenPresentation.proposalListPresentation
                let actionControlsPresentation = self.proposalActionControlsPresentation
                let inspectionControlsPresentation = self.proposalInspectionControlsPresentation
                ProPanelHeader(
                    title: queueSummary.title,
                    value: queueSummary.value,
                    actionTitle: nil,
                    action: nil)
                ForEach(Array(listPresentation.proposals.enumerated()), id: \.element.id) { index, presentation in
                    let proposal = presentation.proposal
                    if index > 0 {
                        Divider().padding(.leading, 58)
                    }
                    Button {
                        self.selectProposal(
                            proposal,
                            opening: self.isCompactWidth ? .sheet : .inline,
                            forceInspect: false)
                    } label: {
                        IPadSkillProposalRow(
                            presentation: presentation)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(inspectionControlsPresentation.title) {
                            self.selectProposal(
                                proposal,
                                opening: .sheet,
                                forceInspect: true)
                        }
                        if presentation.showsProposalActions {
                            Button(actionControlsPresentation.applyButton.title) {
                                Task { await self.run(.apply, proposal: proposal) }
                            }
                            .disabled(!actionControlsPresentation.canRunActions)
                            Button(actionControlsPresentation.rejectButton.title, role: .destructive) {
                                Task { await self.run(.reject, proposal: proposal) }
                            }
                            .disabled(!actionControlsPresentation.canRunActions)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if presentation.showsProposalActions {
                            Button(actionControlsPresentation.applyButton.title) {
                                Task { await self.run(.apply, proposal: proposal) }
                            }
                            .tint(OpenClawBrand.ok)
                            .disabled(!actionControlsPresentation.canRunActions)
                            Button(actionControlsPresentation.rejectButton.title, role: .destructive) {
                                Task { await self.run(.reject, proposal: proposal) }
                            }
                            .disabled(!actionControlsPresentation.canRunActions)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(inspectionControlsPresentation.title) {
                            self.selectProposal(
                                proposal,
                                opening: .sheet,
                                forceInspect: true)
                        }
                        .tint(OpenClawBrand.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var presentedProposalDetail: some View {
        if let presentation = self.screenPresentation.presentedProposalPresentation {
            self.proposalDetailCard(presentation)
        } else {
            ProCard(radius: OpenClawProMetric.cardRadius) {
                ProStatusRow(
                    icon: self.proposalUnavailablePresentation.icon,
                    title: self.proposalUnavailablePresentation.title,
                    detail: self.proposalUnavailablePresentation.detail,
                    value: self.proposalUnavailablePresentation.value,
                    color: .secondary,
                    actionTitle: nil,
                    action: nil)
            }
        }
    }

    private func proposalDetailCard(_ presentation: IPadSkillWorkshopProposalDetailPresentation) -> some View {
        let card = presentation.card
        let proposal = presentation.proposal
        return ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ProIconBadge(systemName: card.iconSystemName, color: proposal.statusColor)
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

                if card.isInspecting {
                    ProgressView().controlSize(.small)
                }

                if let bodyText = presentation.bodyText {
                    Text(bodyText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(16)
                        .textSelection(.enabled)
                } else {
                    Text(presentation.emptyBodyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if presentation.showsSupportFiles {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(presentation.supportFilesTitle)
                            .font(.subheadline.weight(.semibold))
                        ForEach(presentation.supportFiles, id: \.path) { file in
                            Text(file.path)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                if card.showsProposalActions {
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
                    if let notice = self.proposalActionControlsPresentation.adminScopeNotice {
                        self.adminScopeNotice(notice)
                    }
                }
            }
        }
    }

    private func proposalApplyButton(_ proposal: IPadSkillProposal) -> some View {
        let applyButtonPresentation = self.proposalActionControlsPresentation.applyButton
        return Button {
            Task { await self.run(.apply, proposal: proposal) }
        } label: {
            Label(applyButtonPresentation.title, systemImage: applyButtonPresentation.iconSystemName)
                .frame(maxWidth: self.isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(!self.proposalActionControlsPresentation.canRunActions)
    }

    private func proposalRejectButton(_ proposal: IPadSkillProposal) -> some View {
        let rejectButtonPresentation = self.proposalActionControlsPresentation.rejectButton
        return Button(role: .destructive) {
            Task { await self.run(.reject, proposal: proposal) }
        } label: {
            Label(rejectButtonPresentation.title, systemImage: rejectButtonPresentation.iconSystemName)
                .frame(maxWidth: self.isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!self.proposalActionControlsPresentation.canRunActions)
    }

    private func proposalInspectButton(_ proposal: IPadSkillProposal) -> some View {
        let inspectionPresentation = self.proposalInspectionControlsPresentation
        return Button {
            Task { await self.inspect(proposalID: proposal.id, force: true) }
        } label: {
            Label(inspectionPresentation.title, systemImage: inspectionPresentation.iconSystemName)
                .frame(maxWidth: self.isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!inspectionPresentation.canInspect)
    }

    private var refreshTaskID: String {
        self.screenPresentation.refreshTaskID
    }

    private var gatewayAccess: IPadSkillWorkshopGatewayAccess {
        IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: self.appModel.isOperatorGatewayConnected,
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            hasOperatorAdminScope: self.appModel.hasOperatorAdminScope)
    }

    private var screenPresentation: IPadSkillWorkshopScreenPresentation {
        self.store.state.screenPresentation(
            gatewayAccess: self.gatewayAccess,
            sceneIsActive: self.scenePhase == .active)
    }

    private var proposalActionControlsPresentation: IPadSkillWorkshopProposalActionControlsPresentation {
        self.screenPresentation.proposalActionControlsPresentation
    }

    private var proposalInspectionControlsPresentation: IPadSkillWorkshopProposalInspectionControlsPresentation {
        self.screenPresentation.proposalInspectionControlsPresentation
    }

    private var emptyProposalPresentation: IPadSkillWorkshopEmptyProposalPresentation {
        self.screenPresentation.emptyProposalPresentation
    }

    private var proposalUnavailablePresentation: IPadSkillWorkshopEmptyProposalPresentation {
        self.screenPresentation.proposalUnavailablePresentation
    }

    private var proposalSheetPresentation: IPadSkillWorkshopProposalSheetPresentation {
        self.screenPresentation.proposalSheetPresentation
    }

    private var agentScopeSnapshot: IPadSkillWorkshopFeature.Action.AgentScopeSnapshot {
        .init(
            gatewayDefaultAgentID: .init(value: self.appModel.gatewayDefaultAgentId),
            gatewayAgents: .init(values: self.appModel.gatewayAgents.map {
                IPadSkillWorkshopGatewayAgent(id: $0.id, name: $0.name)
            }),
            activeAgentName: .init(value: self.appModel.activeAgentName))
    }

    private func adminScopeNotice(_ presentation: IPadSkillWorkshopAdminScopeNoticePresentation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: presentation.iconSystemName)
                .foregroundStyle(OpenClawBrand.warn)
            Text(presentation.text)
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
            get: { self.screenPresentation.queryFieldPresentation.text },
            set: { self.store.send(.queryChanged(.init(query: .init(value: $0)))) })
    }

    private var statusFilterBinding: Binding<String> {
        Binding(
            get: { self.screenPresentation.statusFilterControlPresentation.selectedFilter },
            set: { self.store.send(.statusFilterChanged(.init(filter: .init(value: $0)))) })
    }

    private func selectProposal(
        _ proposal: IPadSkillProposal,
        opening: IPadSkillWorkshopFeature.Action.ProposalSheetOpening,
        forceInspect: Bool)
    {
        Task {
            await self.store.send(.proposalSelected(.init(
                proposalID: .init(value: proposal.id),
                opening: opening,
                readAccess: .init(canRead: self.gatewayAccess.canRead),
                forceInspect: .init(isForced: forceInspect)))).finish()
        }
    }

    private func loadProposals(force: Bool) async {
        await self.store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: self.scenePhase == .active),
            readAccess: .init(canRead: self.gatewayAccess.canRead),
            force: .init(isForced: force)))).finish()
    }

    private func inspect(proposalID: String, force: Bool) async {
        await self.store.send(.inspectRequested(.init(
            proposalID: .init(value: proposalID),
            readAccess: .init(canRead: self.gatewayAccess.canRead),
            force: .init(isForced: force)))).finish()
    }

    private func run(_ action: IPadSkillProposalAction.Kind, proposal: IPadSkillProposal) async {
        await self.store.send(.proposalMutationRequested(.init(
            kind: action,
            proposalID: .init(value: proposal.id),
            sceneActivity: .init(isActive: self.scenePhase == .active),
            readAccess: .init(canRead: self.gatewayAccess.canRead),
            writeAccess: .init(canWrite: self.gatewayAccess.canWrite),
            adminAccess: .init(hasOperatorAdminScope: self.gatewayAccess.hasOperatorAdminScope)))).finish()
    }
}

struct IPadSkillProposalKanbanColumn: View {
    let lane: IPadSkillWorkshopProposalLanePresentation
    let actionControlsPresentation: IPadSkillWorkshopProposalActionControlsPresentation
    let inspectionControlsPresentation: IPadSkillWorkshopProposalInspectionControlsPresentation
    let select: (IPadSkillWorkshopProposalCardPresentation) -> Void
    let inspect: (IPadSkillWorkshopProposalCardPresentation) -> Void
    let apply: (IPadSkillWorkshopProposalCardPresentation) -> Void
    let reject: (IPadSkillWorkshopProposalCardPresentation) -> Void

    var body: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: self.lane.title,
                    value: self.lane.value,
                    actionTitle: nil,
                    action: nil)

                if self.lane.proposals.isEmpty {
                    ProStatusRow(
                        icon: self.lane.emptyPresentation.icon,
                        title: self.lane.emptyPresentation.title,
                        detail: self.lane.emptyPresentation.detail,
                        value: self.lane.emptyPresentation.value,
                        color: .secondary,
                        actionTitle: nil,
                        action: nil)
                } else {
                    ForEach(Array(self.lane.proposals.enumerated()), id: \.element.id) { index, presentation in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        IPadSkillProposalKanbanCard(
                            presentation: presentation,
                            actionControlsPresentation: self.actionControlsPresentation,
                            inspectionControlsPresentation: self.inspectionControlsPresentation,
                            select: {
                                self.select(presentation)
                            },
                            inspect: {
                                self.inspect(presentation)
                            },
                            apply: {
                                self.apply(presentation)
                            },
                            reject: {
                                self.reject(presentation)
                            })
                    }
                }
            }
        }
    }
}

private struct IPadSkillProposalKanbanCard: View {
    let presentation: IPadSkillWorkshopProposalCardPresentation
    let actionControlsPresentation: IPadSkillWorkshopProposalActionControlsPresentation
    let inspectionControlsPresentation: IPadSkillWorkshopProposalInspectionControlsPresentation
    let select: () -> Void
    let inspect: () -> Void
    let apply: () -> Void
    let reject: () -> Void

    private var proposal: IPadSkillProposal {
        self.presentation.proposal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: self.select) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        ProIconBadge(
                            systemName: self.presentation.iconSystemName,
                            color: self.proposal.statusColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(self.proposal.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(self.presentation.isSelected ? OpenClawBrand.accent : .primary)
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
                if self.presentation.showsProposalActions {
                    Button(action: self.apply) {
                        Image(systemName: self.actionControlsPresentation.applyButton.iconSystemName)
                    }
                    .accessibilityLabel(self.actionControlsPresentation.applyButton.accessibilityLabel)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(!self.actionControlsPresentation.canRunActions)

                    Button(role: .destructive, action: self.reject) {
                        Image(systemName: self.actionControlsPresentation.rejectButton.iconSystemName)
                    }
                    .accessibilityLabel(self.actionControlsPresentation.rejectButton.accessibilityLabel)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(!self.actionControlsPresentation.canRunActions)
                }

                Button(action: self.inspect) {
                    Image(systemName: self.inspectionControlsPresentation.iconSystemName)
                }
                .accessibilityLabel(self.inspectionControlsPresentation.accessibilityLabel)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(self.presentation.isInspecting)
            }
        }
        .padding(12)
        .background(
            self.presentation.isSelected ? OpenClawBrand.accent.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            Button(self.inspectionControlsPresentation.title, action: self.inspect)
            if self.presentation.showsProposalActions {
                Button(self.actionControlsPresentation.applyButton.title, action: self.apply)
                    .disabled(!self.actionControlsPresentation.canRunActions)
                Button(self.actionControlsPresentation.rejectButton.title, role: .destructive, action: self.reject)
                    .disabled(!self.actionControlsPresentation.canRunActions)
            }
        }
    }
}

struct IPadSkillProposalRow: View {
    let presentation: IPadSkillWorkshopProposalCardPresentation

    private var proposal: IPadSkillProposal {
        self.presentation.proposal
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProIconBadge(systemName: self.presentation.iconSystemName, color: self.proposal.statusColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(self.proposal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(self.presentation.isSelected ? OpenClawBrand.accent : .primary)
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
            self.presentation.isSelected ? OpenClawBrand.danger.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension IPadSkillWorkshopFeedbackPresentation {
    fileprivate var color: Color {
        switch self.tone {
        case .notice: OpenClawBrand.accent
        case .error: OpenClawBrand.warn
        }
    }
}

extension IPadSkillWorkshopMetricTone {
    fileprivate var color: Color {
        switch self {
        case .pending: OpenClawBrand.warn
        case .applied: OpenClawBrand.ok
        case .held: .secondary
        }
    }
}

extension IPadSkillProposal {
    var statusColor: Color {
        switch self.status {
        case "pending", "quarantined", "stale": OpenClawBrand.warn
        case "applied": OpenClawBrand.ok
        case "rejected": .secondary
        default: OpenClawBrand.accent
        }
    }
}
