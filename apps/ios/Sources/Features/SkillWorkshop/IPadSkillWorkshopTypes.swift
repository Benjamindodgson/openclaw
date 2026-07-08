import Foundation
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

    private static func parseDate(_ value: String) -> Double {
        (ISO8601DateFormatter().date(from: value)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970) * 1000
    }

    private static func stripFrontmatter(_ value: String) -> String {
        let pattern = #"(?s)^---\r?\n.*?\r?\n---\r?\n?"#
        return value.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
    let title: String
    let iconSystemName: String
    let isDisabled: Bool
    let showsProgress: Bool
}

struct IPadSkillWorkshopAdminScopeNoticePresentation: Equatable, Sendable {
    let iconSystemName: String
    let text: String
}

struct IPadSkillWorkshopProposalActionButtonPresentation: Equatable, Sendable {
    let title: String
    let iconSystemName: String
    let accessibilityLabel: String
}

struct IPadSkillWorkshopProposalActionControlsPresentation: Equatable, Sendable {
    let applyButton: IPadSkillWorkshopProposalActionButtonPresentation
    let rejectButton: IPadSkillWorkshopProposalActionButtonPresentation
    let canApplyMutations: Bool
    let canRunActions: Bool
    let adminScopeNotice: IPadSkillWorkshopAdminScopeNoticePresentation?
}

struct IPadSkillWorkshopProposalInspectionControlsPresentation: Equatable, Sendable {
    let title: String
    let iconSystemName: String
    let accessibilityLabel: String
    let canInspect: Bool
}

struct IPadSkillWorkshopQueryFieldPresentation: Equatable, Sendable {
    let text: String
    let placeholder: String
    let iconSystemName: String
    let clearButtonSystemName: String
    let showsClearButton: Bool
}

struct IPadSkillWorkshopAgentScopeOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

struct IPadSkillWorkshopAgentScopeMenuPresentation: Equatable, Sendable {
    let title: String
    let selectedLabel: String
    let selectorIconSystemName: String
    let accessibilityLabel: String
    let options: [IPadSkillWorkshopAgentScopeOption]
    let isEnabled: Bool
}

struct IPadSkillWorkshopStatusFilterOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

struct IPadSkillWorkshopStatusFilterControlPresentation: Equatable, Sendable {
    let title: String
    let selectedFilter: String
    let selectedLabel: String
    let options: [IPadSkillWorkshopStatusFilterOption]
}

struct IPadSkillWorkshopProposalSheetPresentation: Equatable, Sendable {
    let title: String
    let dismissButtonTitle: String
}

struct IPadSkillWorkshopQueueSummaryPresentation: Equatable, Sendable {
    let title: String
    let proposalCount: Int
    let value: String
    let proposalCountLabel: String
    let statusLabel: String
}

struct IPadSkillWorkshopScreenPresentation: Equatable, Sendable {
    let refreshTaskID: String
    let proposalActionControlsPresentation: IPadSkillWorkshopProposalActionControlsPresentation
    let proposalInspectionControlsPresentation: IPadSkillWorkshopProposalInspectionControlsPresentation
    let emptyProposalPresentation: IPadSkillWorkshopEmptyProposalPresentation
    let proposalUnavailablePresentation: IPadSkillWorkshopEmptyProposalPresentation
    let proposalSheetPresentation: IPadSkillWorkshopProposalSheetPresentation
}

struct IPadSkillWorkshopProposalCardPresentation: Equatable, Identifiable, Sendable {
    let proposal: IPadSkillProposal
    let iconSystemName: String
    let isSelected: Bool
    let isInspecting: Bool
    let showsProposalActions: Bool

    var id: String {
        self.proposal.id
    }
}

struct IPadSkillWorkshopProposalDetailPresentation: Equatable, Identifiable, Sendable {
    let card: IPadSkillWorkshopProposalCardPresentation
    let bodyText: String?
    let emptyBodyText: String
    let supportFilesTitle: String
    let supportFiles: [IPadSkillProposalSupportFile]
    let showsSupportFiles: Bool

    var id: String {
        self.card.id
    }

    var proposal: IPadSkillProposal {
        self.card.proposal
    }
}

struct IPadSkillWorkshopProposalLanePresentation: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
    let emptyPresentation: IPadSkillWorkshopEmptyProposalPresentation
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
