import OpenClawKit

// swiftformat:disable redundantSendable
struct IPadSkillWorkshopFailureMessage: Equatable, Sendable { var value: String }
struct IPadSkillWorkshopNoticeMessage: Equatable, Sendable { var value: String }
struct IPadSkillWorkshopQuery: Equatable, Sendable { var value: String }
struct IPadSkillWorkshopSelectedAgentScopeID: Equatable, Sendable { var value: String }
struct IPadSkillWorkshopStatusFilter: Equatable, Sendable { var value: String }
struct IPadSkillWorkshopGatewayDefaultAgentID: Equatable, Sendable { var value: String? }
struct IPadSkillWorkshopActiveAgentName: Equatable, Sendable { var value: String }

enum IPadSkillWorkshopLoadingPhase: Equatable, Sendable {
    case idle
    case inFlight
}

enum IPadSkillWorkshopError: Error, Equatable, Sendable {
    struct Failure: Equatable, Sendable { var message: IPadSkillWorkshopFailureMessage }

    case failed(Failure)

    var message: String {
        switch self {
        case let .failed(failure):
            failure.message.value
        }
    }
}

struct IPadSkillWorkshopAgentScopeParam: Equatable, Sendable {
    var agentID: String?
}

struct IPadSkillWorkshopProposalID: Equatable, Sendable {
    var value: String
}

struct IPadSkillWorkshopProposals: Equatable, Sendable {
    var values: [IPadSkillProposal] = []
}

struct IPadSkillWorkshopGatewayAgent: Equatable, Sendable {
    var id: String
    var name: String?
}

struct IPadSkillWorkshopGatewayAgents: Equatable, Sendable {
    var values: [IPadSkillWorkshopGatewayAgent] = []
}

struct IPadSkillWorkshopGatewayAccess: Equatable, Sendable {
    var canRead: Bool
    var canWrite: Bool
    var hasOperatorAdminScope: Bool
}

struct IPadSkillWorkshopEmptyProposalPresentation: Equatable, Sendable {
    var icon: String
    var title: String
    var detail: String
    var value: String?
}

enum IPadSkillWorkshopFeedbackTone: Equatable, Sendable {
    case notice
    case error
}

struct IPadSkillWorkshopFeedbackPresentation: Equatable, Identifiable, Sendable {
    let tone: IPadSkillWorkshopFeedbackTone
    let text: String

    var id: IPadSkillWorkshopFeedbackTone {
        self.tone
    }
}

struct IPadSkillWorkshopRefreshControlPresentation: Equatable, Sendable {
    let isDisabled: Bool
    let showsProgress: Bool
}

struct IPadSkillWorkshopProposalActionControlsPresentation: Equatable, Sendable {
    let canApplyMutations: Bool
    let canRunActions: Bool
    let showsAdminScopeNotice: Bool
}

struct IPadSkillWorkshopProposalInspectionControlsPresentation: Equatable, Sendable {
    let canInspect: Bool
}

struct IPadSkillWorkshopQueryFieldPresentation: Equatable, Sendable {
    let text: String
    let showsClearButton: Bool
}

struct IPadSkillWorkshopAgentScopeOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

struct IPadSkillWorkshopAgentScopeMenuPresentation: Equatable, Sendable {
    let selectedLabel: String
    let options: [IPadSkillWorkshopAgentScopeOption]
    let isEnabled: Bool
}

struct IPadSkillWorkshopStatusFilterOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

struct IPadSkillWorkshopStatusFilterControlPresentation: Equatable, Sendable {
    let selectedFilter: String
    let selectedLabel: String
    let options: [IPadSkillWorkshopStatusFilterOption]
}

struct IPadSkillWorkshopQueueSummaryPresentation: Equatable, Sendable {
    let proposalCount: Int
    let statusLabel: String
}

struct IPadSkillWorkshopProposalCardPresentation: Equatable, Identifiable, Sendable {
    let proposal: IPadSkillProposal
    let isSelected: Bool
    let isInspecting: Bool
    let showsProposalActions: Bool

    var id: String {
        self.proposal.id
    }
}

struct IPadSkillWorkshopProposalLanePresentation: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let proposals: [IPadSkillWorkshopProposalCardPresentation]
}

struct IPadSkillWorkshopProposalBoardPresentation: Equatable, Sendable {
    let lanes: [IPadSkillWorkshopProposalLanePresentation]
}

struct IPadSkillWorkshopProposalListPresentation: Equatable, Sendable {
    let proposals: [IPadSkillWorkshopProposalCardPresentation]

    var isEmpty: Bool {
        self.proposals.isEmpty
    }
}

enum IPadSkillWorkshopMetricTone: Equatable, Sendable {
    case pending
    case applied
    case held
}

struct IPadSkillWorkshopMetricPresentation: Equatable, Identifiable, Sendable {
    let id: IPadSkillWorkshopMetricTone
    let icon: String
    let title: String
    let value: String
}

// swiftformat:enable redundantSendable
