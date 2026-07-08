import ComposableArchitecture
import Foundation
import OpenClawKit

struct IPadWorkboardClient {
    var listCards: @Sendable @MainActor (IPadWorkboardBoardScope) async throws -> IPadWorkboardCardsResponse
    var listBoards: @Sendable @MainActor () async throws -> [IPadWorkboardBoardSummary]
    var create: @Sendable @MainActor (IPadWorkboardCreateParams) async throws -> IPadWorkboardCard
    var move: @Sendable @MainActor (IPadWorkboardMoveParams) async throws -> IPadWorkboardCard
    var archive: @Sendable @MainActor (IPadWorkboardArchiveParams) async throws -> IPadWorkboardCard
    var dispatch: @Sendable @MainActor (IPadWorkboardBoardScope) async throws -> IPadWorkboardDispatchSummary
}

extension IPadWorkboardClient: DependencyKey {
    static let liveValue = IPadWorkboardClient.unavailable
    static let testValue = IPadWorkboardClient.unavailable

    private static let unavailable = IPadWorkboardClient(
        listCards: { _ in
            throw IPadWorkboardError.failed(.init(message: .init(value: "Workboard gateway unavailable.")))
        },
        listBoards: { throw IPadWorkboardError.failed(.init(message: .init(value: "Workboard gateway unavailable."))) },
        create: { _ in
            throw IPadWorkboardError.failed(.init(message: .init(value: "Workboard gateway unavailable.")))
        },
        move: { _ in throw IPadWorkboardError.failed(.init(message: .init(value: "Workboard gateway unavailable."))) },
        archive: { _ in
            throw IPadWorkboardError.failed(.init(message: .init(value: "Workboard gateway unavailable.")))
        },
        dispatch: { _ in
            throw IPadWorkboardError.failed(.init(message: .init(value: "Workboard gateway unavailable.")))
        })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        IPadWorkboardClient(
            listCards: { boardScope in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.list",
                    params: IPadWorkboardListParams(boardId: boardScope.boardID?.value),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadWorkboardCardsResponse.self, from: data)
            },
            listBoards: {
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.boards.list",
                    params: EmptyParams(),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadWorkboardBoardsResponse.self, from: data).boards
            },
            create: { params in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.create",
                    params: params,
                    timeoutSeconds: 20)
                return try Self.decodeCardResponse(data)
            },
            move: { params in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.move",
                    params: params,
                    timeoutSeconds: 20)
                return try Self.decodeCardResponse(data)
            },
            archive: { params in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.archive",
                    params: params,
                    timeoutSeconds: 20)
                return try Self.decodeCardResponse(data)
            },
            dispatch: { boardScope in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.dispatch",
                    params: IPadWorkboardListParams(boardId: boardScope.boardID?.value),
                    timeoutSeconds: 45)
                return try JSONDecoder().decode(IPadWorkboardDispatchSummary.self, from: data)
            })
    }

    @MainActor
    private static func request(
        appModel: NodeAppModel,
        method: String,
        params: some Encodable,
        timeoutSeconds: Int) async throws -> Data
    {
        guard appModel.isOperatorGatewayConnected else { throw IPadSidebarGatewayError.offline }
        let data = try JSONEncoder().encode(params)
        guard let json = String(data: data, encoding: .utf8) else {
            throw IPadSidebarGatewayError.invalidPayload
        }
        return try await appModel.operatorSession.request(
            method: method,
            paramsJSON: json,
            timeoutSeconds: timeoutSeconds)
    }

    private static func decodeCardResponse(_ data: Data) throws -> IPadWorkboardCard {
        try JSONDecoder().decode(IPadWorkboardCardResponse.self, from: data).card
    }
}

extension DependencyValues {
    var iPadWorkboard: IPadWorkboardClient {
        get { self[IPadWorkboardClient.self] }
        set { self[IPadWorkboardClient.self] = newValue }
    }
}

// swiftformat:disable redundantSendable
struct IPadWorkboardActiveRefreshBoardID: Equatable, Sendable { var value: String }
struct IPadWorkboardBoardScopeID: Equatable, Sendable { var value: String }
struct IPadWorkboardBoardScopeSelection: Equatable, Sendable { var value: String }
struct IPadWorkboardBusyCardID: Equatable, Sendable { var value: String }
struct IPadWorkboardDraftNotes: Equatable, Sendable { var value: String }
struct IPadWorkboardDraftTitle: Equatable, Sendable { var value: String }
struct IPadWorkboardDispatchSummaryText: Equatable, Sendable { var value: String }
struct IPadWorkboardFailureMessage: Equatable, Sendable { var value: String }
struct IPadWorkboardKnownBoardID: Equatable, Sendable { var value: String }
struct IPadWorkboardMoveStatus: Equatable, Sendable { var value: String }
struct IPadWorkboardQuery: Equatable, Sendable { var value: String }
struct IPadWorkboardSelectedBoardID: Equatable, Sendable { var value: String }
struct IPadWorkboardSelectedStatus: Equatable, Sendable { var value: String }
struct IPadWorkboardStatus: Equatable, Sendable { var value: String }
struct IPadWorkboardStatusFilter: Equatable, Sendable { var value: String }

enum IPadWorkboardError: Error, Equatable, Sendable {
    struct Failure: Equatable, Sendable { var message: IPadWorkboardFailureMessage }

    case failed(Failure)

    var message: String {
        switch self {
        case let .failed(failure):
            failure.message.value
        }
    }
}

struct IPadWorkboardDispatchSnapshot: Equatable, Sendable {
    let summary: IPadWorkboardDispatchSummary
    let cardsResponse: IPadWorkboardCardsResponse
}

struct IPadWorkboardBoardScope: Equatable, Sendable {
    var boardID: IPadWorkboardBoardScopeID?
}

struct IPadWorkboardGatewayAccess: Equatable, Sendable {
    let canRead: Bool
    let canWrite: Bool
}

struct IPadWorkboardBoardScopeOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

struct IPadWorkboardBoardScopeMenuPresentation: Equatable, Sendable {
    let title: String
    let selectedLabel: String
    let leadingIconSystemName: String
    let selectorIconSystemName: String
    let accessibilityLabel: String
    let options: [IPadWorkboardBoardScopeOption]
}

struct IPadWorkboardCards: Equatable, Sendable {
    var values: [IPadWorkboardCard] = []
}

struct IPadWorkboardStatuses: Equatable, Sendable {
    var values: [IPadWorkboardStatus] = IPadWorkboardDefaults.statuses.map { .init(value: $0) }
}

struct IPadWorkboardKnownBoardIDs: Equatable, Sendable {
    var values: [IPadWorkboardKnownBoardID] = []
}

struct IPadWorkboardScreenChromePresentation: Equatable, Sendable {
    let title: String
    let subtitle: String
}

struct IPadWorkboardQueueSummaryPresentation: Equatable, Sendable {
    let title: String
    let cardCount: Int
    let value: String
    let cardCountLabel: String
}

enum IPadWorkboardMetricTone: Equatable, Sendable {
    case accent
    case ok
    case warn
}

enum IPadWorkboardStatusMessageTone: Equatable, Sendable {
    case accent
    case warn
}

struct IPadWorkboardStatusMessagePresentation: Equatable, Identifiable, Sendable {
    let id: String
    let text: String
    let tone: IPadWorkboardStatusMessageTone
}

enum IPadWorkboardCardTone: Equatable, Sendable {
    case accent
    case accentHot
    case ok
    case secondary
    case warn
}

enum IPadWorkboardCardActionControlContext: Equatable, Sendable {
    case kanban
    case queue
}

struct IPadWorkboardCardActionControlPresentation: Equatable, Sendable {
    let iconSystemName: String
    let accessibilityLabel: String
    let isDisabled: Bool
}

struct IPadWorkboardCardDetailActionControlsPresentation: Equatable, Sendable {
    let isMutationDisabled: Bool
}

struct IPadWorkboardCardDetailSheetPresentation: Equatable, Sendable {
    let cardPresentation: IPadWorkboardCardPresentation
    let moveActions: [IPadWorkboardMoveActionPresentation]
    let actionControlsPresentation: IPadWorkboardCardDetailActionControlsPresentation
}

struct IPadWorkboardQueueRowPresentation: Equatable, Sendable {
    let cardPresentation: IPadWorkboardCardPresentation
    let moveActions: [IPadWorkboardMoveActionPresentation]
    let nextMoveAction: IPadWorkboardMoveActionPresentation?
    let actionControlPresentation: IPadWorkboardCardActionControlPresentation
}

struct IPadWorkboardKanbanCardPresentation: Equatable, Sendable {
    let cardPresentation: IPadWorkboardCardPresentation
    let moveActions: [IPadWorkboardMoveActionPresentation]
    let actionControlPresentation: IPadWorkboardCardActionControlPresentation
}

struct IPadWorkboardMetricPresentation: Equatable, Identifiable, Sendable {
    let id: String
    let iconSystemName: String
    let title: String
    let value: String
    let tone: IPadWorkboardMetricTone
}

struct IPadWorkboardCardPresentation: Equatable, Sendable {
    let title: String
    let statusLabel: String
    let detail: String
    let iconSystemName: String
    let tone: IPadWorkboardCardTone
    let labelsSummary: String?
    let sessionKey: String?
    let openSessionActionTitle: String
    let compactOpenSessionActionTitle: String
    let inspectActionTitle: String
    let detailSheetTitle: String
    let detailSectionTitle: String
    let titleFieldTitle: String
    let statusFieldTitle: String
    let actionsSectionTitle: String
    let moveMenuTitle: String
    let actionMenuAccessibilityLabel: String
    let archiveActionTitle: String
    let doneActionTitle: String
    let notesText: String?

    var showsOpenSessionAction: Bool {
        self.sessionKey != nil
    }
}

struct IPadWorkboardMoveActionPresentation: Equatable, Identifiable, Sendable {
    let id: String
    let status: String
    let title: String
    let menuTitle: String
}

struct IPadWorkboardKanbanLaneEmptyStatePresentation: Equatable, Sendable {
    let icon: String
    let title: String
    let detail: String
    let value: String
}

struct IPadWorkboardKanbanLanePresentation: Equatable, Sendable {
    let status: String
    let title: String
    let cardCount: Int
    let value: String
    let emptyState: IPadWorkboardKanbanLaneEmptyStatePresentation
}

struct IPadWorkboardRefreshControlPresentation: Equatable, Sendable {
    let title: String
    let iconSystemName: String
    let compactAccessibilityLabel: String
    let isDisabled: Bool
    let showsProgress: Bool
}

struct IPadWorkboardDispatchControlPresentation: Equatable, Sendable {
    let title: String
    let iconSystemName: String
    let isDisabled: Bool
}

struct IPadWorkboardQueryFieldPresentation: Equatable, Sendable {
    let text: String
    let placeholder: String
    let iconSystemName: String
    let clearButtonSystemName: String
    let showsClearButton: Bool
}

struct IPadWorkboardCompactEmptyStatePresentation: Equatable, Sendable {
    let icon: String
    let title: String
    let detail: String
    let value: String?
}

struct IPadWorkboardCompactWriteUnavailablePresentation: Equatable, Sendable {
    let message: String
}

struct IPadWorkboardCompactWriteControlsPresentation: Equatable, Sendable {
    let showsWriteControls: Bool
    let unavailablePresentation: IPadWorkboardCompactWriteUnavailablePresentation
}

struct IPadWorkboardCreateSheetErrorPresentation: Equatable, Sendable {
    let text: String
    let tone: IPadWorkboardStatusMessageTone
}

struct IPadWorkboardCreateSheetPresentation: Equatable, Sendable {
    let title: String
    let sectionTitle: String
    let titlePlaceholder: String
    let notesPlaceholder: String
    let errorMessage: IPadWorkboardCreateSheetErrorPresentation?
    let cancelTitle: String
    let confirmationTitle: String
    let confirmationAccessibilityHint: String
    let isConfirmationDisabled: Bool
}

struct IPadWorkboardCreateCardPresentation: Equatable, Sendable {
    let buttonTitle: String
    let buttonIconSystemName: String
    let buttonAccessibilityHint: String
    let isButtonDisabled: Bool
    let sheet: IPadWorkboardCreateSheetPresentation
}

struct IPadWorkboardStatusFilterOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let accessibilityLabel: String
    let isSelected: Bool
}

struct IPadWorkboardStatusFilterControlPresentation: Equatable, Sendable {
    let pickerTitle: String
    let menuTitle: String
    let selectedFilter: String
    let selectedLabel: String
    let selectorIconSystemName: String
    let options: [IPadWorkboardStatusFilterOption]
    let compactOptions: [IPadWorkboardStatusFilterOption]
}

struct IPadWorkboardScreenPresentation: Equatable, Sendable {
    let screenChromePresentation: IPadWorkboardScreenChromePresentation
    let refreshTaskID: String
    let queueSummaryPresentation: IPadWorkboardQueueSummaryPresentation
    let refreshControlPresentation: IPadWorkboardRefreshControlPresentation
    let boardScopeMenuPresentation: IPadWorkboardBoardScopeMenuPresentation
    let statusFilterControlPresentation: IPadWorkboardStatusFilterControlPresentation
}

// swiftformat:enable redundantSendable

@Reducer
struct IPadWorkboardFeature {
    private let clientOverride: IPadWorkboardClient?

    init(client: IPadWorkboardClient? = nil) {
        self.clientOverride = client
    }

    private enum CancelID {
        case refresh
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        enum CardCreationPhase: Equatable, Sendable {
            case idle
            case inFlight
        }

        enum RefreshPhase: Equatable, Sendable {
            case idle
            case inFlight(boardID: IPadWorkboardActiveRefreshBoardID?)

            func matchesActiveBoardID(_ boardID: IPadWorkboardActiveRefreshBoardID?) -> Bool {
                switch self {
                case .idle:
                    false
                case let .inFlight(activeBoardID):
                    activeBoardID == boardID
                }
            }

            var isInFlight: Bool {
                switch self {
                case .idle:
                    false
                case .inFlight:
                    true
                }
            }
        }

        enum DispatchPhase: Equatable, Sendable {
            case idle
            case inFlight
        }

        var cardEntries = IPadWorkboardCards()
        var statusEntries = IPadWorkboardStatuses()
        var knownBoardIDEntries = IPadWorkboardKnownBoardIDs()
        var refreshPhase = RefreshPhase.idle
        var dispatchPhase = DispatchPhase.idle
        var busyCardID: IPadWorkboardBusyCardID?
        var dispatchSummaryText: IPadWorkboardDispatchSummaryText?
        var selectedStatus = IPadWorkboardSelectedStatus(value: "active")
        var selectedBoardID = IPadWorkboardSelectedBoardID(value: "")
        var query = IPadWorkboardQuery(value: "")
        var draftTitle = IPadWorkboardDraftTitle(value: "")
        var draftNotes = IPadWorkboardDraftNotes(value: "")
        var cardCreationPhase = CardCreationPhase.idle
        var errorText: IPadWorkboardFailureMessage?
        var presentedSheet: IPadWorkboardSheet?

        var cards: [IPadWorkboardCard] {
            self.cardEntries.values
        }

        var runningCardCount: Int {
            self.cards.count(where: { $0.status == "running" })
        }

        var blockedCardCount: Int {
            self.cards.count(where: { $0.status == "blocked" })
        }

        var statuses: [IPadWorkboardStatus] {
            self.statusEntries.values
        }

        var knownBoardIDs: [IPadWorkboardKnownBoardID] {
            self.knownBoardIDEntries.values
        }

        var boardScopeLabel: String {
            Self.boardScopeLabel(for: self.selectedBoardID.value)
        }

        var boardScopeMenuPresentation: IPadWorkboardBoardScopeMenuPresentation {
            .init(
                title: "Board",
                selectedLabel: self.boardScopeLabel,
                leadingIconSystemName: "rectangle.stack",
                selectorIconSystemName: "chevron.up.chevron.down",
                accessibilityLabel: "Workboard board scope",
                options: [Self.defaultBoardScopeOption] + self.boardScopeOptions.map {
                    .init(id: $0, title: Self.boardScopeLabel(for: $0))
                })
        }

        var workboardSubtitle: String {
            Self.workboardSubtitle(
                boardScopeLabel: self.boardScopeLabel,
                selectedStatus: self.selectedStatus.value)
        }

        var screenChromePresentation: IPadWorkboardScreenChromePresentation {
            .init(title: "Workboard", subtitle: self.workboardSubtitle)
        }

        var queueSummaryPresentation: IPadWorkboardQueueSummaryPresentation {
            .init(
                title: "Queue",
                cardCount: self.filteredCardCount,
                value: "\(self.filteredCardCount)",
                cardCountLabel: "\(self.filteredCardCount) cards")
        }

        var metricPresentations: [IPadWorkboardMetricPresentation] {
            [
                .init(
                    id: "cards",
                    iconSystemName: "tray.full",
                    title: "Cards",
                    value: "\(self.cards.count)",
                    tone: .accent),
                .init(
                    id: "running",
                    iconSystemName: "figure.run",
                    title: "Running",
                    value: "\(self.runningCardCount)",
                    tone: .ok),
                .init(
                    id: "blocked",
                    iconSystemName: "exclamationmark.triangle",
                    title: "Blocked",
                    value: "\(self.blockedCardCount)",
                    tone: .warn),
            ]
        }

        var refreshControlPresentation: IPadWorkboardRefreshControlPresentation {
            .init(
                title: "Refresh",
                iconSystemName: "arrow.clockwise",
                compactAccessibilityLabel: "Refresh workboard",
                isDisabled: self.isLoading,
                showsProgress: self.isLoading)
        }

        var statusMessagePresentations: [IPadWorkboardStatusMessagePresentation] {
            var messages: [IPadWorkboardStatusMessagePresentation] = []
            if let dispatchSummaryText {
                messages.append(.init(id: "dispatch", text: dispatchSummaryText.value, tone: .accent))
            }
            if let errorText {
                messages.append(.init(id: "error", text: errorText.value, tone: .warn))
            }
            return messages
        }

        func dispatchControlPresentation(
            gatewayAccess: IPadWorkboardGatewayAccess) -> IPadWorkboardDispatchControlPresentation
        {
            .init(
                title: "Dispatch",
                iconSystemName: "bolt.fill",
                isDisabled: !gatewayAccess.canWrite || self.isLoading)
        }

        var queryFieldPresentation: IPadWorkboardQueryFieldPresentation {
            .init(
                text: self.query.value,
                placeholder: "Search cards",
                iconSystemName: "magnifyingglass",
                clearButtonSystemName: "xmark.circle.fill",
                showsClearButton: !self.query.value.isEmpty)
        }

        func compactEmptyStatePresentation(
            gatewayAccess: IPadWorkboardGatewayAccess) -> IPadWorkboardCompactEmptyStatePresentation
        {
            if gatewayAccess.canRead {
                return .init(
                    icon: "tray",
                    title: "No cards",
                    detail: "Create a card or change the filter.",
                    value: "empty")
            }
            return .init(
                icon: "wifi.slash",
                title: "No cards loaded",
                detail: "Connect from Settings to load workboard cards.",
                value: nil)
        }

        func cardPresentation(for card: IPadWorkboardCard) -> IPadWorkboardCardPresentation {
            Self.cardPresentation(for: card)
        }

        func openSessionKey(for card: IPadWorkboardCard) -> String? {
            Self.normalizedNonEmpty(card.sessionKey)
        }

        func cardActionControlPresentation(
            for card: IPadWorkboardCard,
            context: IPadWorkboardCardActionControlContext) -> IPadWorkboardCardActionControlPresentation
        {
            Self.cardActionControlPresentation(
                isBusy: self.busyCardID?.value == card.id,
                context: context,
                accessibilityLabel: Self.cardPresentation(for: card).actionMenuAccessibilityLabel)
        }

        var moveActionPresentations: [IPadWorkboardMoveActionPresentation] {
            Self.moveActionPresentations(for: self.statusValues)
        }

        func nextMoveActionPresentation(for card: IPadWorkboardCard) -> IPadWorkboardMoveActionPresentation? {
            Self.nextMoveActionPresentation(for: card, statuses: self.statusValues)
        }

        func kanbanLanePresentation(status: String) -> IPadWorkboardKanbanLanePresentation {
            Self.kanbanLanePresentation(status: status, cardCount: self.cards(forKanbanStatus: status).count)
        }

        var statusFilterControlPresentation: IPadWorkboardStatusFilterControlPresentation {
            .init(
                pickerTitle: "Scope",
                menuTitle: "Status",
                selectedFilter: self.selectedStatus.value,
                selectedLabel: IPadWorkboardDefaults.label(for: self.selectedStatus.value),
                selectorIconSystemName: "chevron.up.chevron.down",
                options: Self.statusFilterOptions(
                    for: self.statusValues,
                    selectedStatus: self.selectedStatus.value),
                compactOptions: Self.statusFilterOptions(
                    for: self.compactStatuses,
                    selectedStatus: self.selectedStatus.value))
        }

        var isLoading: Bool {
            self.refreshPhase.isInFlight || self.dispatchPhase == .inFlight
        }

        var selectedBoardParam: IPadWorkboardBoardScopeID? {
            let selected = Self.normalizedScopeID(self.selectedBoardID.value)
            return selected.isEmpty ? nil : .init(value: selected)
        }

        var trimmedDraftTitle: String {
            self.draftTitle.value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func createUnavailableMessage(canRead: Bool, canWrite: Bool) -> String? {
            Self.createUnavailableMessage(
                cardCreationPhase: self.cardCreationPhase,
                trimmedDraftTitle: self.trimmedDraftTitle,
                canRead: canRead,
                canWrite: canWrite)
        }

        func createCardPresentation(gatewayAccess: IPadWorkboardGatewayAccess) -> IPadWorkboardCreateCardPresentation {
            let isCreating = self.cardCreationPhase == .inFlight
            return .init(
                buttonTitle: "New Card",
                buttonIconSystemName: "plus",
                buttonAccessibilityHint: "Opens card title and notes entry",
                isButtonDisabled: isCreating,
                sheet: .init(
                    title: "New Card",
                    sectionTitle: "Card",
                    titlePlaceholder: "Title",
                    notesPlaceholder: "Notes",
                    errorMessage: self.errorText.map { .init(text: $0.value, tone: .warn) },
                    cancelTitle: "Cancel",
                    confirmationTitle: isCreating ? "Creating..." : "Create",
                    confirmationAccessibilityHint: self.createUnavailableMessage(
                        canRead: gatewayAccess.canRead,
                        canWrite: gatewayAccess.canWrite) ?? "Creates a workboard card",
                    isConfirmationDisabled: isCreating))
        }

        var boardScopeOptions: [String] {
            Self.boardScopeOptions(
                knownBoardIDs: self.knownBoardIDValues,
                cardBoardIDs: self.cards.map(Self.boardID(for:)))
        }

        var knownBoardIDValues: [String] {
            self.knownBoardIDs.map(\.value)
        }

        var statusValues: [String] {
            self.statuses.map(\.value)
        }

        var visibleKanbanStatuses: [String] {
            if self.selectedStatus.value == "active" {
                return self.statusValues.filter { $0 != "done" }
            }
            if self.statusValues.contains(self.selectedStatus.value) {
                return [self.selectedStatus.value]
            }
            return self.statusValues
        }

        var compactStatuses: [String] {
            let preferred = ["todo", "ready", "running", "review", "blocked", "scheduled", "done"]
            let statusValues = self.statusValues
            let known = preferred.filter { statusValues.contains($0) }
            let custom = statusValues.filter { !preferred.contains($0) }
            return known + custom
        }

        var filteredCards: [IPadWorkboardCard] {
            Self.filteredCards(
                cards: self.cards,
                selectedStatus: self.selectedStatus.value,
                query: self.query.value)
        }

        var filteredCardCount: Int {
            self.filteredCards.count
        }

        func cards(forKanbanStatus status: String) -> [IPadWorkboardCard] {
            Self.cardsForKanbanStatus(
                cards: self.cards,
                status: status,
                selectedStatus: self.selectedStatus.value,
                query: self.query.value)
        }

        mutating func applyCardsResponse(_ response: IPadWorkboardCardsResponse) {
            self.cardEntries = .init(values: response.cards.sorted { $0.position < $1.position })
            self.statusEntries = .init(values: Self.normalizedStatuses(response.statuses))
            self.rememberBoardIDs(from: response.cards)
            self.validateSelectedStatus()
        }

        mutating func applyBoardScopes(_ boards: [IPadWorkboardBoardSummary]) {
            let discovered = boards.map(\.id)
            let boardIDs = Self.boardScopeOptions(
                knownBoardIDs: self.knownBoardIDValues,
                cardBoardIDs: discovered)
            self.knownBoardIDEntries = .init(values: boardIDs.map { .init(value: $0) })
        }

        mutating func replace(_ card: IPadWorkboardCard) {
            var cardValues = self.cardEntries.values
            cardValues.removeAll { $0.id == card.id }
            cardValues.append(card)
            cardValues.sort { $0.position < $1.position }
            self.cardEntries = .init(values: cardValues)
            self.rememberBoardIDs(from: [card])
        }

        func nextPosition(for status: String, excluding cardID: String? = nil) -> Double {
            let maxPosition = self.cards
                .filter { $0.status == status && $0.id != cardID }
                .map(\.position)
                .max() ?? 0
            return maxPosition + 1000
        }

        static func createUnavailableMessage(
            cardCreationPhase: CardCreationPhase,
            trimmedDraftTitle: String,
            canRead: Bool,
            canWrite: Bool) -> String?
        {
            if cardCreationPhase == .inFlight {
                return "Card creation is already in progress."
            }
            if !canWrite {
                return self.compactWriteUnavailableMessage(canRead: canRead)
            }
            if trimmedDraftTitle.isEmpty {
                return "Enter a title to create a card."
            }
            return nil
        }

        static func compactWriteUnavailableMessage(canRead: Bool) -> String {
            canRead ? "Read-only gateway." : "Connect from Settings to create, move, and dispatch cards."
        }

        static func boardID(for card: IPadWorkboardCard) -> String {
            self.normalizedScopeID(card.metadata?.automation?.boardId).isEmpty
                ? "default"
                : self.normalizedScopeID(card.metadata?.automation?.boardId)
        }

        static func normalizedScopeID(_ value: String?) -> String {
            (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func boardScopeLabel(for boardID: String) -> String {
            let normalized = self.normalizedScopeID(boardID)
            return normalized.isEmpty ? "All boards" : normalized
        }

        static func boardScopeOptions(knownBoardIDs: [String], cardBoardIDs: [String]) -> [String] {
            Array(Set((knownBoardIDs + cardBoardIDs).map { self.normalizedScopeID($0) }.filter { !$0.isEmpty }))
                .sorted()
        }

        static func workboardSubtitle(boardScopeLabel: String, selectedStatus: String) -> String {
            "\(boardScopeLabel) / \(IPadWorkboardDefaults.label(for: selectedStatus))"
        }

        static func cardPresentation(for card: IPadWorkboardCard) -> IPadWorkboardCardPresentation {
            .init(
                title: card.title,
                statusLabel: IPadWorkboardDefaults.label(for: card.status),
                detail: self.cardDetail(for: card),
                iconSystemName: self.cardIconSystemName(for: card.status),
                tone: self.cardTone(for: card.status),
                labelsSummary: self.labelsSummary(for: card.labels),
                sessionKey: self.normalizedNonEmpty(card.sessionKey),
                openSessionActionTitle: "Open Session",
                compactOpenSessionActionTitle: "Open",
                inspectActionTitle: "Inspect",
                detailSheetTitle: "Card",
                detailSectionTitle: "Card",
                titleFieldTitle: "Title",
                statusFieldTitle: "Status",
                actionsSectionTitle: "Actions",
                moveMenuTitle: "Move",
                actionMenuAccessibilityLabel: "Card Actions",
                archiveActionTitle: card.metadata?.archivedAt == nil ? "Archive" : "Unarchive",
                doneActionTitle: "Done",
                notesText: self.normalizedNonEmpty(card.notes))
        }

        static func moveActionPresentations(for statuses: [String]) -> [IPadWorkboardMoveActionPresentation] {
            statuses.map(self.moveActionPresentation(for:))
        }

        static func moveActionPresentation(for status: String) -> IPadWorkboardMoveActionPresentation {
            let title = IPadWorkboardDefaults.label(for: status)
            return .init(
                id: status,
                status: status,
                title: title,
                menuTitle: "Move to \(title)")
        }

        static func nextMoveActionPresentation(
            for card: IPadWorkboardCard,
            statuses: [String]) -> IPadWorkboardMoveActionPresentation?
        {
            let nextStatus: String
            if let currentIndex = statuses.firstIndex(of: card.status) {
                let nextIndex = statuses.index(after: currentIndex)
                guard statuses.indices.contains(nextIndex) else { return nil }
                nextStatus = statuses[nextIndex]
            } else if let firstStatus = statuses.first {
                nextStatus = firstStatus
            } else {
                return nil
            }
            return self.moveActionPresentation(for: nextStatus)
        }

        static func cardActionControlPresentation(
            isBusy: Bool,
            context: IPadWorkboardCardActionControlContext,
            accessibilityLabel: String) -> IPadWorkboardCardActionControlPresentation
        {
            .init(
                iconSystemName: isBusy ? "hourglass" : self.cardActionIdleIconSystemName(for: context),
                accessibilityLabel: accessibilityLabel,
                isDisabled: isBusy)
        }

        static func cardDetailActionControlsPresentation(
            isBusy: Bool,
            canWrite: Bool) -> IPadWorkboardCardDetailActionControlsPresentation
        {
            .init(isMutationDisabled: !canWrite || isBusy)
        }

        static func cardActionIdleIconSystemName(for context: IPadWorkboardCardActionControlContext) -> String {
            switch context {
            case .kanban: "ellipsis"
            case .queue: "ellipsis.circle"
            }
        }

        static func cardIconSystemName(for status: String) -> String {
            switch status {
            case "running": "figure.run"
            case "review": "checklist"
            case "blocked": "exclamationmark.triangle"
            case "done": "checkmark.circle"
            default: "tray"
            }
        }

        static func cardTone(for status: String) -> IPadWorkboardCardTone {
            switch status {
            case "running": .ok
            case "review": .accent
            case "blocked": .warn
            case "done": .secondary
            default: .accentHot
            }
        }

        static func cardDetail(for card: IPadWorkboardCard) -> String {
            self.normalizedNonEmpty(card.notes)
                ?? self.normalizedNonEmpty(card.sessionKey)
                ?? self.normalizedNonEmpty(card.agentId)
                ?? "Default agent"
        }

        static func normalizedNonEmpty(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        static func kanbanLanePresentation(
            status: String,
            cardCount: Int) -> IPadWorkboardKanbanLanePresentation
        {
            let title = IPadWorkboardDefaults.label(for: status)
            return .init(
                status: status,
                title: title,
                cardCount: cardCount,
                value: "\(cardCount)",
                emptyState: .init(
                    icon: "tray",
                    title: "No \(title.lowercased()) cards",
                    detail: "Cards moved into this lane appear here.",
                    value: "empty"))
        }

        private static let defaultBoardScopeOption = IPadWorkboardBoardScopeOption(id: "", title: "All boards")

        private static func statusFilterOptions(
            for statuses: [String],
            selectedStatus: String) -> [IPadWorkboardStatusFilterOption]
        {
            [self.statusFilterOption(for: "active", selectedStatus: selectedStatus)] + statuses.map {
                self.statusFilterOption(for: $0, selectedStatus: selectedStatus)
            }
        }

        private static func statusFilterOption(
            for status: String,
            selectedStatus: String) -> IPadWorkboardStatusFilterOption
        {
            let title = IPadWorkboardDefaults.label(for: status)
            return .init(
                id: status,
                title: title,
                accessibilityLabel: "Show \(title) cards",
                isSelected: status == selectedStatus)
        }

        static func cardsForKanbanStatus(
            cards: [IPadWorkboardCard],
            status: String,
            selectedStatus: String,
            query: String) -> [IPadWorkboardCard]
        {
            cards
                .filter { card in
                    card.status == status && (selectedStatus != "active" || card.metadata?.archivedAt == nil)
                }
                .filter { Self.matchesQuery(card: $0, query: query) }
                .sorted { $0.position < $1.position }
        }

        static func filteredCards(
            cards: [IPadWorkboardCard],
            selectedStatus: String,
            query: String) -> [IPadWorkboardCard]
        {
            cards
                .filter { card in
                    if selectedStatus == "active" {
                        return card.metadata?.archivedAt == nil && card.status != "done"
                    }
                    return card.status == selectedStatus
                }
                .filter { Self.matchesQuery(card: $0, query: query) }
                .sorted { left, right in
                    if left.status != right.status {
                        return IPadWorkboardDefaults.rank(left.status) < IPadWorkboardDefaults.rank(right.status)
                    }
                    return left.position < right.position
                }
        }

        private static func matchesQuery(card: IPadWorkboardCard, query: String) -> Bool {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmedQuery.isEmpty else { return true }
            return [
                card.title,
                card.notes,
                card.agentId,
                card.sessionKey,
                card.labels.joined(separator: " "),
            ]
                .compactMap(\.self)
                .joined(separator: " ")
                .lowercased()
                .contains(trimmedQuery)
        }

        private static func labelsSummary(for labels: [String]) -> String? {
            let summary = labels.prefix(3).joined(separator: ", ")
            return summary.isEmpty ? nil : summary
        }

        private mutating func rememberBoardIDs(from cards: [IPadWorkboardCard]) {
            let discovered = cards.map(Self.boardID(for:))
            let boardIDs = Array(Set(self.knownBoardIDValues + discovered)).sorted()
            self.knownBoardIDEntries = .init(values: boardIDs.map { .init(value: $0) })
        }

        private mutating func validateSelectedStatus() {
            if !self.statusValues.contains(self.selectedStatus.value), self.selectedStatus.value != "active" {
                self.selectedStatus = .init(value: "active")
            }
        }

        private static func normalizedStatuses(_ statuses: [String]?) -> [IPadWorkboardStatus] {
            let normalized = (statuses ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { IPadWorkboardStatus(value: $0) }
            return normalized.isEmpty ? IPadWorkboardDefaults.statuses.map { .init(value: $0) } : normalized
        }
    }

    enum Action: Equatable, Sendable {
        struct SceneActivity: Equatable, Sendable { var isActive: Bool }
        struct RefreshForce: Equatable, Sendable { var isForced: Bool }

        struct ArchiveRequest: Equatable, Sendable {
            var card: IPadWorkboardCard
            var gatewayAccess: IPadWorkboardGatewayAccess
        }

        struct ArchiveResponse: Equatable, Sendable {
            var result: Result<IPadWorkboardCard, IPadWorkboardError>
        }

        case archiveRequested(ArchiveRequest)
        case archiveResponse(ArchiveResponse)
        case beginCreateCardTapped

        struct BoardScopesResponse: Equatable, Sendable {
            var force: RefreshForce
            var result: Result<[IPadWorkboardBoardSummary], IPadWorkboardError>
        }

        case boardScopesResponse(BoardScopesResponse)

        struct BoardScopeChange: Equatable, Sendable {
            var boardID: IPadWorkboardBoardScopeSelection
        }

        case boardScopeChanged(BoardScopeChange)

        struct CardSheetPresentation: Equatable, Sendable {
            var card: IPadWorkboardCard
        }

        case cardSheetPresented(CardSheetPresentation)
        case clearQueryTapped

        struct CreateRequest: Equatable, Sendable {
            var gatewayAccess: IPadWorkboardGatewayAccess
        }

        struct CreateResponse: Equatable, Sendable {
            var result: Result<IPadWorkboardCard, IPadWorkboardError>
        }

        case createRequested(CreateRequest)
        case createResponse(CreateResponse)

        struct DispatchRequest: Equatable, Sendable {
            var gatewayAccess: IPadWorkboardGatewayAccess
        }

        struct DispatchResponse: Equatable, Sendable {
            var boardScope: IPadWorkboardBoardScope
            var result: Result<IPadWorkboardDispatchSnapshot, IPadWorkboardError>
        }

        case dispatchRequested(DispatchRequest)
        case dispatchResponse(DispatchResponse)

        struct DraftNotesChange: Equatable, Sendable {
            var notes: IPadWorkboardDraftNotes
        }

        case draftNotesChanged(DraftNotesChange)

        struct DraftTitleChange: Equatable, Sendable {
            var title: IPadWorkboardDraftTitle
        }

        case draftTitleChanged(DraftTitleChange)

        struct MoveRequest: Equatable, Sendable {
            var card: IPadWorkboardCard
            var status: IPadWorkboardMoveStatus
            var gatewayAccess: IPadWorkboardGatewayAccess
        }

        struct MoveResponse: Equatable, Sendable {
            var result: Result<IPadWorkboardCard, IPadWorkboardError>
        }

        case moveRequested(MoveRequest)
        case moveResponse(MoveResponse)

        struct QueryChange: Equatable, Sendable {
            var query: IPadWorkboardQuery
        }

        case queryChanged(QueryChange)

        struct RefreshRequest: Equatable, Sendable {
            var sceneActivity: SceneActivity
            var gatewayAccess: IPadWorkboardGatewayAccess
            var force: RefreshForce
        }

        struct RefreshResponse: Equatable, Sendable {
            var boardScope: IPadWorkboardBoardScope
            var force: RefreshForce
            var result: Result<IPadWorkboardCardsResponse, IPadWorkboardError>
        }

        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)
        case sheetDismissed

        struct StatusChange: Equatable, Sendable {
            var status: IPadWorkboardStatusFilter
        }

        case statusChanged(StatusChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.iPadWorkboard) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .archiveRequested(request):
                guard request.gatewayAccess.canWrite, state.busyCardID == nil else { return .none }
                state.busyCardID = .init(value: request.card.id)
                state.errorText = nil
                let params = IPadWorkboardArchiveParams(
                    id: request.card.id,
                    archived: request.card.metadata?.archivedAt == nil)
                return .run { send in
                    do {
                        let card = try await client.archive(params)
                        await send(.archiveResponse(.init(result: .success(card))))
                    } catch {
                        await send(.archiveResponse(.init(result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .archiveResponse(response):
                switch response.result {
                case let .success(card):
                    state.busyCardID = nil
                    state.replace(card)
                    return .none

                case let .failure(error):
                    state.busyCardID = nil
                    state.errorText = .init(value: error.message)
                    return .none
                }

            case .beginCreateCardTapped:
                state.draftTitle = .init(value: "")
                state.draftNotes = .init(value: "")
                state.errorText = nil
                state.presentedSheet = .create
                return .none

            case let .boardScopesResponse(response):
                switch response.result {
                case let .success(boards):
                    state.applyBoardScopes(boards)
                    return .none

                case let .failure(error):
                    if response.force.isForced, state.knownBoardIDs.isEmpty {
                        state.errorText = .init(value: error.message)
                    }
                    return .none
                }

            case let .boardScopeChanged(change):
                state.selectedBoardID = .init(value: State.normalizedScopeID(change.boardID.value))
                return .none

            case let .cardSheetPresented(presentation):
                state.presentedSheet = .card(presentation.card)
                return .none

            case .clearQueryTapped:
                state.query = .init(value: "")
                return .none

            case let .createRequested(request):
                if let message = state.createUnavailableMessage(
                    canRead: request.gatewayAccess.canRead,
                    canWrite: request.gatewayAccess.canWrite)
                {
                    state.errorText = .init(value: message)
                    return .none
                }

                state.cardCreationPhase = .inFlight
                state.errorText = nil
                let canCreateInSelectedStatus = state.statusValues.contains(state.selectedStatus.value)
                let status = canCreateInSelectedStatus ? state.selectedStatus.value : "todo"
                let params = IPadWorkboardCreateParams(
                    title: state.trimmedDraftTitle,
                    notes: state.draftNotes.value.trimmingCharacters(in: .whitespacesAndNewlines),
                    status: status,
                    priority: "normal",
                    labels: [],
                    agentId: "",
                    sessionKey: nil,
                    position: state.nextPosition(for: status),
                    boardId: state.selectedBoardParam?.value)
                return .run { send in
                    do {
                        let card = try await client.create(params)
                        await send(.createResponse(.init(result: .success(card))))
                    } catch {
                        await send(.createResponse(.init(result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .createResponse(response):
                switch response.result {
                case let .success(card):
                    state.cardCreationPhase = .idle
                    state.draftTitle = .init(value: "")
                    state.draftNotes = .init(value: "")
                    state.presentedSheet = nil
                    state.replace(card)
                    return .none

                case let .failure(error):
                    state.cardCreationPhase = .idle
                    state.errorText = .init(value: error.message)
                    return .none
                }

            case let .dispatchRequested(request):
                guard request.gatewayAccess.canWrite, !state.isLoading else { return .none }
                state.dispatchPhase = .inFlight
                state.errorText = nil
                state.dispatchSummaryText = nil
                let boardScope = IPadWorkboardBoardScope(boardID: state.selectedBoardParam)
                return .run { send in
                    do {
                        let summary = try await client.dispatch(boardScope)
                        let cardsResponse = try await client.listCards(boardScope)
                        await send(.dispatchResponse(.init(
                            boardScope: boardScope,
                            result: .success(IPadWorkboardDispatchSnapshot(
                                summary: summary,
                                cardsResponse: cardsResponse)))))
                    } catch {
                        await send(.dispatchResponse(.init(
                            boardScope: boardScope,
                            result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .dispatchResponse(response):
                state.dispatchPhase = .idle
                guard state.selectedBoardParam == response.boardScope.boardID else { return .none }
                switch response.result {
                case let .success(snapshot):
                    state.dispatchSummaryText = .init(value: snapshot.summary.summaryText)
                    state.applyCardsResponse(snapshot.cardsResponse)
                    return .none

                case let .failure(error):
                    state.errorText = .init(value: error.message)
                    return .none
                }

            case let .draftNotesChanged(change):
                state.draftNotes = change.notes
                return .none

            case let .draftTitleChanged(change):
                state.draftTitle = change.title
                return .none

            case let .moveRequested(request):
                guard request.gatewayAccess.canWrite, state.busyCardID == nil else { return .none }
                state.busyCardID = .init(value: request.card.id)
                state.errorText = nil
                let params = IPadWorkboardMoveParams(
                    id: request.card.id,
                    status: request.status.value,
                    position: state.nextPosition(for: request.status.value, excluding: request.card.id))
                return .run { send in
                    do {
                        let card = try await client.move(params)
                        await send(.moveResponse(.init(result: .success(card))))
                    } catch {
                        await send(.moveResponse(.init(result: .failure(Self.failure(for: error)))))
                    }
                }

            case let .moveResponse(response):
                switch response.result {
                case let .success(card):
                    state.busyCardID = nil
                    state.replace(card)
                    return .none

                case let .failure(error):
                    state.busyCardID = nil
                    state.errorText = .init(value: error.message)
                    return .none
                }

            case let .queryChanged(change):
                state.query = change.query
                return .none

            case let .refreshRequested(request):
                guard request.sceneActivity.isActive else {
                    state.refreshPhase = .idle
                    return .cancel(id: CancelID.refresh)
                }
                guard request.gatewayAccess.canRead else {
                    state.cardEntries = .init()
                    state.errorText = nil
                    state.refreshPhase = .idle
                    return .cancel(id: CancelID.refresh)
                }

                let boardScope = IPadWorkboardBoardScope(boardID: state.selectedBoardParam)
                state.refreshPhase = .inFlight(
                    boardID: boardScope.boardID.map { .init(value: $0.value) })
                state.errorText = nil
                if !state.statusValues.contains(state.selectedStatus.value), state.selectedStatus.value != "active" {
                    state.selectedStatus = .init(value: "active")
                }
                return .run { send in
                    do {
                        let response = try await client.listCards(boardScope)
                        await send(.refreshResponse(.init(
                            boardScope: boardScope,
                            force: request.force,
                            result: .success(response))))
                    } catch {
                        await send(.refreshResponse(.init(
                            boardScope: boardScope,
                            force: request.force,
                            result: .failure(Self.failure(for: error)))))
                    }
                }
                .cancellable(id: CancelID.refresh, cancelInFlight: true)

            case let .refreshResponse(response):
                let activeRefreshBoardID = response.boardScope.boardID
                    .map { IPadWorkboardActiveRefreshBoardID(value: $0.value) }
                guard state.refreshPhase.matchesActiveBoardID(activeRefreshBoardID) else { return .none }
                state.refreshPhase = .idle
                guard state.selectedBoardParam == response.boardScope.boardID else { return .none }
                switch response.result {
                case let .success(cardsResponse):
                    state.applyCardsResponse(cardsResponse)
                    return .run { send in
                        do {
                            let boards = try await client.listBoards()
                            await send(.boardScopesResponse(.init(force: response.force, result: .success(boards))))
                        } catch {
                            await send(.boardScopesResponse(.init(
                                force: response.force,
                                result: .failure(Self.failure(for: error)))))
                        }
                    }

                case let .failure(error):
                    if response.force.isForced || state.cards.isEmpty {
                        state.errorText = .init(value: error.message)
                    }
                    return .none
                }

            case .sheetDismissed:
                state.presentedSheet = nil
                return .none

            case let .statusChanged(change):
                state.selectedStatus = .init(value: change.status.value)
                return .none
            }
        }
        .autoLogActions()
    }

    private static func message(for error: Error) -> String {
        if let workboardError = error as? IPadWorkboardError {
            return workboardError.message
        }
        if let gatewayError = error as? IPadSidebarGatewayError {
            return gatewayError.message
        }
        return error.localizedDescription
    }

    private static func failure(for error: Error) -> IPadWorkboardError {
        .failed(.init(message: .init(value: self.message(for: error))))
    }
}

extension IPadWorkboardFeature.State {
    static func gatewayAccess(
        isOperatorGatewayConnected: Bool,
        isAppleReviewDemoModeEnabled: Bool) -> IPadWorkboardGatewayAccess
    {
        .init(
            canRead: isOperatorGatewayConnected,
            canWrite: isOperatorGatewayConnected && !isAppleReviewDemoModeEnabled)
    }

    func compactWriteControlsPresentation(
        gatewayAccess: IPadWorkboardGatewayAccess) -> IPadWorkboardCompactWriteControlsPresentation
    {
        .init(
            showsWriteControls: gatewayAccess.canWrite,
            unavailablePresentation: .init(message: Self
                .compactWriteUnavailableMessage(canRead: gatewayAccess.canRead)))
    }

    func cardDetailActionControlsPresentation(
        for card: IPadWorkboardCard,
        gatewayAccess: IPadWorkboardGatewayAccess) -> IPadWorkboardCardDetailActionControlsPresentation
    {
        Self.cardDetailActionControlsPresentation(
            isBusy: self.busyCardID?.value == card.id,
            canWrite: gatewayAccess.canWrite)
    }

    func cardDetailSheetPresentation(
        for card: IPadWorkboardCard,
        gatewayAccess: IPadWorkboardGatewayAccess) -> IPadWorkboardCardDetailSheetPresentation
    {
        .init(
            cardPresentation: self.cardPresentation(for: card),
            moveActions: self.moveActionPresentations,
            actionControlsPresentation: self.cardDetailActionControlsPresentation(
                for: card,
                gatewayAccess: gatewayAccess))
    }

    func queueRowPresentation(for card: IPadWorkboardCard) -> IPadWorkboardQueueRowPresentation {
        .init(
            cardPresentation: self.cardPresentation(for: card),
            moveActions: self.moveActionPresentations,
            nextMoveAction: self.nextMoveActionPresentation(for: card),
            actionControlPresentation: self.cardActionControlPresentation(for: card, context: .queue))
    }

    func kanbanCardPresentation(for card: IPadWorkboardCard) -> IPadWorkboardKanbanCardPresentation {
        .init(
            cardPresentation: self.cardPresentation(for: card),
            moveActions: self.moveActionPresentations,
            actionControlPresentation: self.cardActionControlPresentation(for: card, context: .kanban))
    }

    func screenPresentation(
        gatewayAccess: IPadWorkboardGatewayAccess,
        sceneIsActive: Bool) -> IPadWorkboardScreenPresentation
    {
        .init(
            screenChromePresentation: self.screenChromePresentation,
            refreshTaskID: self.refreshTaskID(
                gatewayAccess: gatewayAccess,
                sceneIsActive: sceneIsActive),
            queueSummaryPresentation: self.queueSummaryPresentation,
            refreshControlPresentation: self.refreshControlPresentation,
            boardScopeMenuPresentation: self.boardScopeMenuPresentation,
            statusFilterControlPresentation: self.statusFilterControlPresentation)
    }

    func refreshTaskID(gatewayAccess: IPadWorkboardGatewayAccess, sceneIsActive: Bool) -> String {
        let connection = gatewayAccess.canRead ? "connected" : "offline"
        let scene = sceneIsActive ? "active" : "inactive"
        let board = self.selectedBoardID.value.isEmpty ? "all" : self.selectedBoardID.value
        return [connection, scene, board].joined(separator: ":")
    }
}

enum IPadWorkboardStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<IPadWorkboardFeature> {
        Store(initialState: IPadWorkboardFeature.State()) {
            IPadWorkboardFeature(client: .live(appModel: appModel))
        }
    }
}
