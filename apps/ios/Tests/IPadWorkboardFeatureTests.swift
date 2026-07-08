import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct IPadWorkboardFeatureTests {
    @Test func `begin create clears drafts and presents create sheet`() async {
        var initialState = IPadWorkboardFeature.State()
        initialState.draftTitle = .init(value: "Old")
        initialState.draftNotes = .init(value: "Old notes")
        initialState.errorText = .init(value: "old error")
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature()
        }

        await store.send(.beginCreateCardTapped) {
            $0.draftTitle = .init(value: "")
            $0.draftNotes = .init(value: "")
            $0.errorText = nil
            $0.presentedSheet = .create
        }
    }

    @Test func `draft and query controls update reducer state`() async {
        let store = TestStore(initialState: IPadWorkboardFeature.State()) {
            IPadWorkboardFeature()
        }

        await store.send(.draftTitleChanged(.init(title: .init(value: "  Ship TCA  ")))) {
            $0.draftTitle = .init(value: "  Ship TCA  ")
        }
        await store.send(.draftNotesChanged(.init(notes: .init(value: "notes")))) {
            $0.draftNotes = .init(value: "notes")
        }
        await store.send(.queryChanged(.init(query: .init(value: "gateway")))) {
            $0.query = .init(value: "gateway")
        }
        await store.send(.clearQueryTapped) {
            $0.query = .init(value: "")
        }
        await store.send(.statusChanged(.init(status: .init(value: "review")))) {
            $0.selectedStatus = .init(value: "review")
        }
    }

    @Test func `create unavailable message matches gateway and draft state`() {
        var state = IPadWorkboardFeature.State()
        #expect(state.createUnavailableMessage(canRead: true, canWrite: true) == "Enter a title to create a card.")

        state.draftTitle = .init(value: "Card")
        #expect(state.createUnavailableMessage(canRead: false, canWrite: false) ==
            "Connect from Settings to create, move, and dispatch cards.")

        state.cardCreationPhase = .inFlight
        #expect(state
            .createUnavailableMessage(canRead: true, canWrite: true) == "Card creation is already in progress.")
    }

    @Test func `workboard create card presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()

        #expect(state.createCardPresentation(gatewayAccess: .init(canRead: true, canWrite: true)) == .init(
            buttonTitle: "New Card",
            buttonIconSystemName: "plus",
            buttonAccessibilityHint: "Opens card title and notes entry",
            isButtonDisabled: false,
            sheet: .init(
                title: "New Card",
                sectionTitle: "Card",
                titlePlaceholder: "Title",
                notesPlaceholder: "Notes",
                errorMessage: nil,
                cancelTitle: "Cancel",
                confirmationTitle: "Create",
                confirmationAccessibilityHint: "Enter a title to create a card.",
                isConfirmationDisabled: false)))

        state.draftTitle = .init(value: "Card")
        #expect(state.createCardPresentation(gatewayAccess: .init(canRead: true, canWrite: true)).sheet
            .confirmationAccessibilityHint ==
            "Creates a workboard card")

        state.cardCreationPhase = .inFlight
        let creatingPresentation = state.createCardPresentation(gatewayAccess: .init(canRead: true, canWrite: true))
        #expect(creatingPresentation.isButtonDisabled)
        #expect(creatingPresentation.sheet.confirmationTitle == "Creating...")
        #expect(creatingPresentation.sheet.isConfirmationDisabled)
        #expect(creatingPresentation.sheet.confirmationAccessibilityHint == "Card creation is already in progress.")

        state.cardCreationPhase = .idle
        #expect(state.createCardPresentation(gatewayAccess: .init(canRead: false, canWrite: false)).sheet
            .confirmationAccessibilityHint ==
            "Connect from Settings to create, move, and dispatch cards.")

        state.errorText = .init(value: "workboard boom")
        #expect(state.createCardPresentation(gatewayAccess: .init(canRead: true, canWrite: true)).sheet
            .errorMessage == .init(
                text: "workboard boom",
                tone: .warn))
    }

    @Test func `workboard subtitle is derived by reducer state`() {
        var state = IPadWorkboardFeature.State()
        #expect(state.workboardSubtitle == "All boards / Active")
        let defaultChrome = IPadWorkboardScreenChromePresentation(
            title: "Workboard",
            subtitle: "All boards / Active")
        #expect(state.screenChromePresentation == defaultChrome)
        #expect(state.screenPresentation(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true)
            .screenChromePresentation == defaultChrome)

        state.selectedBoardID = .init(value: "planning")
        state.selectedStatus = .init(value: "blocked")

        #expect(state.workboardSubtitle == "planning / Blocked")
        #expect(state.screenPresentation(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true)
            .screenChromePresentation == .init(
                title: "Workboard",
                subtitle: "planning / Blocked"))
    }

    @Test func `workboard queue summary presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        state.cardEntries = .init(values: [
            Self.card(id: "todo-match", title: "Gateway fix", status: "todo", position: 30),
            Self.card(id: "done-match", title: "Gateway shipped", status: "done", position: 20),
        ])

        #expect(state.queueSummaryPresentation == .init(
            title: "Queue",
            cardCount: 1,
            value: "1",
            cardCountLabel: "1 cards"))
        #expect(state.screenPresentation(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true)
            .queueSummaryPresentation ==
            state.queueSummaryPresentation)
    }

    @Test func `workboard refresh control presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        #expect(state.refreshControlPresentation == .init(
            title: "Refresh",
            iconSystemName: "arrow.clockwise",
            compactAccessibilityLabel: "Refresh workboard",
            isDisabled: false,
            showsProgress: false))

        state.refreshPhase = .inFlight(boardID: nil)
        #expect(state.refreshControlPresentation == .init(
            title: "Refresh",
            iconSystemName: "arrow.clockwise",
            compactAccessibilityLabel: "Refresh workboard",
            isDisabled: true,
            showsProgress: true))
        #expect(state.screenPresentation(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true)
            .refreshControlPresentation ==
            state.refreshControlPresentation)

        state.refreshPhase = .idle
        state.dispatchPhase = .inFlight
        #expect(state.refreshControlPresentation.isDisabled)
        #expect(state.refreshControlPresentation.showsProgress)
    }

    @Test func `workboard refresh task id is reducer owned`() {
        var state = IPadWorkboardFeature.State()

        #expect(state
            .refreshTaskID(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true) ==
            "connected:active:all")
        #expect(state
            .refreshTaskID(gatewayAccess: .init(canRead: false, canWrite: false), sceneIsActive: false) ==
            "offline:inactive:all")
        #expect(state.screenPresentation(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true)
            .refreshTaskID == "connected:active:all")

        state.selectedBoardID = .init(value: "planning")
        #expect(state
            .refreshTaskID(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: false) ==
            "connected:inactive:planning")
        #expect(state.screenPresentation(
            gatewayAccess: .init(canRead: false, canWrite: false),
            sceneIsActive: true).refreshTaskID == "offline:active:planning")
    }

    @Test func `workboard dispatch control presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        #expect(state.dispatchControlPresentation(gatewayAccess: .init(canRead: true, canWrite: true)) == .init(
            title: "Dispatch",
            iconSystemName: "bolt.fill",
            isDisabled: false))
        #expect(state.dispatchControlPresentation(gatewayAccess: .init(canRead: true, canWrite: false)).isDisabled)

        state.refreshPhase = .inFlight(boardID: nil)
        #expect(state.dispatchControlPresentation(gatewayAccess: .init(canRead: true, canWrite: true)).isDisabled)

        state.refreshPhase = .idle
        state.dispatchPhase = .inFlight
        #expect(state.dispatchControlPresentation(gatewayAccess: .init(canRead: true, canWrite: true)).isDisabled)
    }

    @Test func `workboard gateway access is reducer owned`() {
        #expect(IPadWorkboardFeature.State.gatewayAccess(
            isOperatorGatewayConnected: true,
            isAppleReviewDemoModeEnabled: false) == .init(
            canRead: true,
            canWrite: true))
        #expect(IPadWorkboardFeature.State.gatewayAccess(
            isOperatorGatewayConnected: true,
            isAppleReviewDemoModeEnabled: true) == .init(
            canRead: true,
            canWrite: false))
        #expect(IPadWorkboardFeature.State.gatewayAccess(
            isOperatorGatewayConnected: false,
            isAppleReviewDemoModeEnabled: false) == .init(
            canRead: false,
            canWrite: false))
    }

    @Test func `workboard query field presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        #expect(state.queryFieldPresentation == .init(
            text: "",
            placeholder: "Search cards",
            iconSystemName: "magnifyingglass",
            clearButtonSystemName: "xmark.circle.fill",
            showsClearButton: false))

        state.query = .init(value: "gateway")
        #expect(state.queryFieldPresentation == .init(
            text: "gateway",
            placeholder: "Search cards",
            iconSystemName: "magnifyingglass",
            clearButtonSystemName: "xmark.circle.fill",
            showsClearButton: true))
    }

    @Test func `workboard compact empty state presentation is reducer owned`() {
        let state = IPadWorkboardFeature.State()

        #expect(state.compactEmptyStatePresentation(gatewayAccess: .init(canRead: true, canWrite: true)) == .init(
            icon: "tray",
            title: "No cards",
            detail: "Create a card or change the filter.",
            value: "empty"))

        #expect(state.compactEmptyStatePresentation(gatewayAccess: .init(canRead: false, canWrite: false)) == .init(
            icon: "wifi.slash",
            title: "No cards loaded",
            detail: "Connect from Settings to load workboard cards.",
            value: nil))
    }

    @Test func `workboard compact write unavailable message is reducer owned`() {
        #expect(IPadWorkboardFeature.State.compactWriteUnavailableMessage(canRead: false) ==
            "Connect from Settings to create, move, and dispatch cards.")
        #expect(IPadWorkboardFeature.State.compactWriteUnavailableMessage(canRead: true) == "Read-only gateway.")
    }

    @Test func `workboard compact write controls presentation is reducer owned`() {
        let state = IPadWorkboardFeature.State()

        #expect(state.compactWriteControlsPresentation(gatewayAccess: .init(canRead: true, canWrite: true)) == .init(
            showsWriteControls: true,
            unavailablePresentation: .init(message: "Read-only gateway.")))
        #expect(state.compactWriteControlsPresentation(gatewayAccess: .init(canRead: true, canWrite: false)) == .init(
            showsWriteControls: false,
            unavailablePresentation: .init(message: "Read-only gateway.")))
        #expect(state.compactWriteControlsPresentation(gatewayAccess: .init(canRead: false, canWrite: false)) == .init(
            showsWriteControls: false,
            unavailablePresentation: .init(message: "Connect from Settings to create, move, and dispatch cards.")))
    }

    @Test func `workboard board scope menu presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        state.knownBoardIDEntries = .init(values: [.init(value: "ops")])
        state.cardEntries = .init(values: [
            Self.card(id: "planning-card", status: "todo", position: 10, boardID: "planning"),
        ])

        let defaultPresentation = IPadWorkboardBoardScopeMenuPresentation(
            title: "Board",
            selectedLabel: "All boards",
            leadingIconSystemName: "rectangle.stack",
            selectorIconSystemName: "chevron.up.chevron.down",
            accessibilityLabel: "Workboard board scope",
            options: [
                .init(id: "", title: "All boards"),
                .init(id: "ops", title: "ops"),
                .init(id: "planning", title: "planning"),
            ])
        #expect(state.boardScopeMenuPresentation == defaultPresentation)
        #expect(state.screenPresentation(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true)
            .boardScopeMenuPresentation ==
            defaultPresentation)

        state.selectedBoardID = .init(value: "planning")
        #expect(state.boardScopeMenuPresentation.selectedLabel == "planning")
    }

    @Test func `workboard status filter presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        state.statusEntries = .init(values: [
            .init(value: "review"),
            .init(value: "todo"),
            .init(value: "custom"),
        ])

        let presentation = state.statusFilterControlPresentation
        #expect(presentation.pickerTitle == "Scope")
        #expect(presentation.menuTitle == "Status")
        #expect(presentation.selectedFilter == "active")
        #expect(presentation.selectedLabel == "Active")
        #expect(presentation.selectorIconSystemName == "chevron.up.chevron.down")
        #expect(presentation.options.map(\.id) == ["active", "review", "todo", "custom"])
        #expect(presentation.compactOptions.map(\.id) == ["active", "todo", "review", "custom"])
        #expect(presentation.options.first?.accessibilityLabel == "Show Active cards")
        #expect(presentation.options.filter(\.isSelected).map(\.id) == ["active"])
        #expect(presentation.compactOptions.filter(\.isSelected).map(\.id) == ["active"])
        #expect(state.screenPresentation(gatewayAccess: .init(canRead: true, canWrite: true), sceneIsActive: true)
            .statusFilterControlPresentation ==
            presentation)

        state.selectedStatus = .init(value: "review")
        #expect(state.statusFilterControlPresentation.selectedLabel == "Review")
        #expect(state.statusFilterControlPresentation.options.filter(\.isSelected).map(\.id) == ["review"])
        #expect(state.statusFilterControlPresentation.compactOptions.filter(\.isSelected).map(\.id) == ["review"])
    }

    @Test func `workboard card presentation is reducer owned`() {
        let card = Self.card(
            id: "running-card",
            title: "Run gateway",
            status: "running",
            position: 10,
            notes: "  Ship it  ",
            labels: ["agent", "relay", "ios", "extra"],
            sessionKey: " session-1 ")
        let presentation = IPadWorkboardFeature.State.cardPresentation(for: card)

        #expect(presentation == .init(
            title: "Run gateway",
            statusLabel: "Running",
            detail: "Ship it",
            iconSystemName: "figure.run",
            tone: .ok,
            labelsSummary: "agent, relay, ios",
            sessionKey: "session-1",
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
            archiveActionTitle: "Archive",
            doneActionTitle: "Done",
            notesText: "Ship it"))
        #expect(presentation.showsOpenSessionAction)
        #expect(IPadWorkboardFeature.State().cardPresentation(for: card) == presentation)

        let sessionOnly = Self.card(id: "review-card", status: "review", position: 20, sessionKey: " session-2 ")
        let sessionPresentation = IPadWorkboardFeature.State.cardPresentation(for: sessionOnly)
        #expect(sessionPresentation.detail == "session-2")
        #expect(sessionPresentation.iconSystemName == "checklist")
        #expect(sessionPresentation.tone == .accent)
        #expect(sessionPresentation.notesText == nil)
        #expect(sessionPresentation.showsOpenSessionAction)

        let agentOnly = Self.card(id: "blocked-card", status: "blocked", position: 30, agentID: " agent-7 ")
        let agentPresentation = IPadWorkboardFeature.State.cardPresentation(for: agentOnly)
        #expect(agentPresentation.detail == "agent-7")
        #expect(agentPresentation.iconSystemName == "exclamationmark.triangle")
        #expect(agentPresentation.tone == .warn)
        #expect(agentPresentation.sessionKey == nil)
        #expect(!agentPresentation.showsOpenSessionAction)

        let archived = Self.card(id: "done-card", status: "done", position: 40, archivedAt: 1)
        let archivedPresentation = IPadWorkboardFeature.State.cardPresentation(for: archived)
        #expect(archivedPresentation.detail == "Default agent")
        #expect(archivedPresentation.iconSystemName == "checkmark.circle")
        #expect(archivedPresentation.tone == .secondary)
        #expect(archivedPresentation.archiveActionTitle == "Unarchive")

        let defaultPresentation = IPadWorkboardFeature.State.cardPresentation(for: Self.card(
            id: "todo-card",
            status: "todo",
            position: 50))
        #expect(defaultPresentation.tone == .accentHot)
    }

    @Test func `workboard move action presentation is reducer owned`() {
        let statuses = ["todo", "in_review", "done"]
        let actions = IPadWorkboardFeature.State.moveActionPresentations(for: statuses)

        #expect(actions == [
            .init(id: "todo", status: "todo", title: "Todo", menuTitle: "Move to Todo"),
            .init(id: "in_review", status: "in_review", title: "In Review", menuTitle: "Move to In Review"),
            .init(id: "done", status: "done", title: "Done", menuTitle: "Move to Done"),
        ])

        var state = IPadWorkboardFeature.State()
        state.statusEntries = .init(values: statuses.map { .init(value: $0) })
        #expect(state.moveActionPresentations == actions)

        let current = Self.card(id: "current", status: "todo", position: 10)
        #expect(state.nextMoveActionPresentation(for: current) ==
            .init(id: "in_review", status: "in_review", title: "In Review", menuTitle: "Move to In Review"))

        let last = Self.card(id: "last", status: "done", position: 20)
        #expect(state.nextMoveActionPresentation(for: last) == nil)

        let unknown = Self.card(id: "unknown", status: "custom", position: 30)
        #expect(state.nextMoveActionPresentation(for: unknown) ==
            .init(id: "todo", status: "todo", title: "Todo", menuTitle: "Move to Todo"))
        #expect(IPadWorkboardFeature.State.nextMoveActionPresentation(for: unknown, statuses: []) == nil)
    }

    @Test func `workboard status message presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        #expect(state.statusMessagePresentations == [])

        state.dispatchSummaryText = .init(value: "3 dispatched.")
        #expect(state.statusMessagePresentations == [
            .init(id: "dispatch", text: "3 dispatched.", tone: .accent),
        ])

        state.errorText = .init(value: "workboard boom")
        #expect(state.statusMessagePresentations == [
            .init(id: "dispatch", text: "3 dispatched.", tone: .accent),
            .init(id: "error", text: "workboard boom", tone: .warn),
        ])

        state.dispatchSummaryText = nil
        state.errorText = .init(value: "offline")
        #expect(state.statusMessagePresentations == [
            .init(id: "error", text: "offline", tone: .warn),
        ])
    }

    @Test func `workboard card action control presentation is reducer owned`() {
        let card = Self.card(id: "card-1", status: "todo", position: 10)
        var state = IPadWorkboardFeature.State()

        #expect(state.cardActionControlPresentation(for: card, context: .kanban) == .init(
            iconSystemName: "ellipsis",
            accessibilityLabel: "Card Actions",
            isDisabled: false))
        #expect(state.cardActionControlPresentation(for: card, context: .queue) == .init(
            iconSystemName: "ellipsis.circle",
            accessibilityLabel: "Card Actions",
            isDisabled: false))

        state.busyCardID = .init(value: "card-1")
        #expect(state.cardActionControlPresentation(for: card, context: .kanban) == .init(
            iconSystemName: "hourglass",
            accessibilityLabel: "Card Actions",
            isDisabled: true))
        #expect(IPadWorkboardFeature.State.cardActionControlPresentation(
            isBusy: true,
            context: .queue,
            accessibilityLabel: "Custom Actions") == .init(
            iconSystemName: "hourglass",
            accessibilityLabel: "Custom Actions",
            isDisabled: true))
    }

    @Test func `workboard card detail action controls presentation is reducer owned`() {
        let card = Self.card(id: "card-1", status: "todo", position: 10)
        var state = IPadWorkboardFeature.State()

        #expect(state.cardDetailActionControlsPresentation(
            for: card,
            gatewayAccess: .init(canRead: true, canWrite: true)) == .init(
            isMutationDisabled: false))
        #expect(state.cardDetailActionControlsPresentation(
            for: card,
            gatewayAccess: .init(canRead: true, canWrite: false)) == .init(
            isMutationDisabled: true))

        state.busyCardID = .init(value: "card-1")
        #expect(state.cardDetailActionControlsPresentation(
            for: card,
            gatewayAccess: .init(canRead: true, canWrite: true)) == .init(
            isMutationDisabled: true))
        #expect(IPadWorkboardFeature.State.cardDetailActionControlsPresentation(
            isBusy: false,
            canWrite: false) == .init(isMutationDisabled: true))
    }

    @Test func `workboard kanban lane presentation is reducer owned`() {
        var state = IPadWorkboardFeature.State()
        state.cardEntries = .init(values: [
            Self.card(id: "review-1", title: "Gateway review", status: "in_review", position: 10),
            Self.card(id: "review-2", title: "Other review", status: "in_review", position: 20),
            Self.card(id: "done-1", status: "done", position: 30),
        ])

        #expect(state.kanbanLanePresentation(status: "in_review") == .init(
            status: "in_review",
            title: "In Review",
            cardCount: 2,
            value: "2",
            emptyState: .init(
                icon: "tray",
                title: "No in review cards",
                detail: "Cards moved into this lane appear here.",
                value: "empty")))
        state.query = .init(value: "gateway")
        #expect(state.kanbanLanePresentation(status: "in_review").cardCount == 1)
        #expect(IPadWorkboardFeature.State.kanbanLanePresentation(status: "blocked", cardCount: 0) == .init(
            status: "blocked",
            title: "Blocked",
            cardCount: 0,
            value: "0",
            emptyState: .init(
                icon: "tray",
                title: "No blocked cards",
                detail: "Cards moved into this lane appear here.",
                value: "empty")))
    }

    @Test func `kanban cards are filtered by reducer state`() {
        var state = IPadWorkboardFeature.State()
        state.cardEntries = .init(values: [
            Self.card(id: "todo-match", title: "Gateway fix", status: "todo", position: 30),
            Self.card(id: "todo-other", title: "Other", status: "todo", position: 10),
            Self.card(id: "done-match", title: "Gateway shipped", status: "done", position: 20),
            Self.card(id: "archived-match", title: "Gateway archived", status: "todo", position: 5, archivedAt: 1),
        ])
        state.query = .init(value: "gateway")

        #expect(state.cards(forKanbanStatus: "todo").map(\.id) == ["todo-match"])
        #expect(state.filteredCardCount == 1)

        state.selectedStatus = .init(value: "todo")
        #expect(state.cards(forKanbanStatus: "todo").map(\.id) == ["archived-match", "todo-match"])
        #expect(state.filteredCardCount == 2)
    }

    @Test func `workboard metric counts are derived by reducer state`() {
        var state = IPadWorkboardFeature.State()
        state.cardEntries = .init(values: [
            Self.card(id: "running-1", status: "running", position: 10),
            Self.card(id: "running-2", status: "running", position: 20),
            Self.card(id: "blocked-1", status: "blocked", position: 30),
            Self.card(id: "todo-1", status: "todo", position: 40),
        ])

        #expect(state.runningCardCount == 2)
        #expect(state.blockedCardCount == 1)
        #expect(state.metricPresentations == [
            .init(
                id: "cards",
                iconSystemName: "tray.full",
                title: "Cards",
                value: "4",
                tone: .accent),
            .init(
                id: "running",
                iconSystemName: "figure.run",
                title: "Running",
                value: "2",
                tone: .ok),
            .init(
                id: "blocked",
                iconSystemName: "exclamationmark.triangle",
                title: "Blocked",
                value: "1",
                tone: .warn),
        ])
    }

    @Test func `refresh loads cards and board scopes through client`() async {
        let card = Self.card(id: "card-1", status: "todo", position: 20, boardID: "planning")
        let response = IPadWorkboardCardsResponse(cards: [card], statuses: ["todo", "done"])
        let boards = [IPadWorkboardBoardSummary(id: "ops"), IPadWorkboardBoardSummary(id: "planning")]
        var client = Self.failingClient()
        client.listCards = { boardScope in
            #expect(boardScope.boardID == .init(value: "planning"))
            return response
        }
        client.listBoards = { boards }
        var initialState = IPadWorkboardFeature.State()
        initialState.selectedStatus = .init(value: "missing")
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.boardScopeChanged(.init(boardID: .init(value: " planning ")))) {
            $0.selectedBoardID = .init(value: "planning")
        }
        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            gatewayAccess: .init(canRead: true, canWrite: true),
            force: .init(isForced: false))))
        {
            $0.refreshPhase = .inFlight(boardID: .init(value: "planning"))
            $0.errorText = nil
            $0.selectedStatus = .init(value: "active")
        }
        await store.receive(.refreshResponse(.init(
            boardScope: .init(boardID: .init(value: "planning")),
            force: .init(isForced: false),
            result: .success(response))))
        {
            $0.refreshPhase = .idle
            $0.cardEntries = .init(values: [card])
            $0.statusEntries = .init(values: [.init(value: "todo"), .init(value: "done")])
            $0.knownBoardIDEntries = .init(values: [.init(value: "planning")])
        }
        await store.receive(.boardScopesResponse(.init(force: .init(isForced: false), result: .success(boards)))) {
            $0.knownBoardIDEntries = .init(values: [.init(value: "ops"), .init(value: "planning")])
        }
    }

    @Test func `stale refresh responses are ignored after board changes`() async {
        let currentCard = Self.card(id: "current", status: "todo", position: 10, boardID: "current")
        let staleCard = Self.card(id: "stale", status: "done", position: 20, boardID: "old")
        var initialState = IPadWorkboardFeature.State()
        initialState.selectedBoardID = .init(value: "current")
        initialState.cardEntries = .init(values: [currentCard])
        initialState.refreshPhase = .inFlight(boardID: .init(value: "old"))
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: Self.failingClient())
        }

        await store.send(.refreshResponse(
            .init(
                boardScope: .init(boardID: .init(value: "old")),
                force: .init(isForced: true),
                result: .success(IPadWorkboardCardsResponse(cards: [staleCard], statuses: ["done"])))))
        {
            $0.refreshPhase = .idle
        }
    }

    @Test func `idle all boards refresh response is ignored`() async {
        let currentCard = Self.card(id: "current", status: "todo", position: 10)
        let staleCard = Self.card(id: "stale", status: "done", position: 20)
        var initialState = IPadWorkboardFeature.State()
        initialState.cardEntries = .init(values: [currentCard])
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: Self.failingClient())
        }

        await store.send(.refreshResponse(
            .init(
                boardScope: .init(boardID: nil),
                force: .init(isForced: true),
                result: .success(IPadWorkboardCardsResponse(cards: [staleCard], statuses: ["done"])))))
    }

    @Test func `forced refresh failure surfaces error text`() async {
        var client = Self.failingClient()
        client.listCards = { _ in throw TestWorkboardFailure.failed }
        let store = TestStore(initialState: IPadWorkboardFeature.State()) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            gatewayAccess: .init(canRead: true, canWrite: true),
            force: .init(isForced: true))))
        {
            $0.refreshPhase = .inFlight(boardID: nil)
        }
        await store.receive(.refreshResponse(.init(
            boardScope: .init(boardID: nil),
            force: .init(isForced: true),
            result: .failure(.failed(.init(message: .init(value: "workboard boom")))))))
        {
            $0.refreshPhase = .idle
            $0.errorText = .init(value: "workboard boom")
        }
    }

    @Test func `create request sends trimmed params and inserts returned card`() async {
        let existing = Self.card(id: "existing", status: "ready", position: 1000, boardID: "planning")
        let created = Self.card(id: "created", status: "ready", position: 2000, boardID: "planning")
        var client = Self.failingClient()
        client.create = { params in
            #expect(params.title == "New card")
            #expect(params.notes == "notes")
            #expect(params.status == "ready")
            #expect(params.position == 2000)
            #expect(params.boardId == "planning")
            return created
        }
        var initialState = IPadWorkboardFeature.State()
        initialState.cardEntries = .init(values: [existing])
        initialState.statusEntries = .init(values: [.init(value: "todo"), .init(value: "ready")])
        initialState.selectedStatus = .init(value: "ready")
        initialState.selectedBoardID = .init(value: "planning")
        initialState.presentedSheet = .create
        initialState.draftTitle = .init(value: "  New card  ")
        initialState.draftNotes = .init(value: " notes ")
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.createRequested(.init(gatewayAccess: .init(canRead: true, canWrite: true)))) {
            $0.cardCreationPhase = .inFlight
            $0.errorText = nil
        }
        await store.receive(.createResponse(.init(result: .success(created)))) {
            $0.cardCreationPhase = .idle
            $0.draftTitle = .init(value: "")
            $0.draftNotes = .init(value: "")
            $0.presentedSheet = nil
            $0.cardEntries = .init(values: [existing, created])
            $0.knownBoardIDEntries = .init(values: [.init(value: "planning")])
        }
    }

    @Test func `create failure clears busy state and surfaces error text`() async {
        var client = Self.failingClient()
        client.create = { _ in throw TestWorkboardFailure.failed }
        var initialState = IPadWorkboardFeature.State()
        initialState.draftTitle = .init(value: "New card")
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.createRequested(.init(gatewayAccess: .init(canRead: true, canWrite: true)))) {
            $0.cardCreationPhase = .inFlight
            $0.errorText = nil
        }
        await store.receive(.createResponse(.init(
            result: .failure(.failed(.init(message: .init(value: "workboard boom")))))))
        {
            $0.cardCreationPhase = .idle
            $0.errorText = .init(value: "workboard boom")
        }
    }

    @Test func `move and archive requests keep one busy card and replace returned card`() async {
        let card = Self.card(id: "card-1", status: "todo", position: 100)
        let moved = Self.card(id: "card-1", status: "running", position: 1000)
        let archived = Self.card(id: "card-1", status: "running", position: 1000, archivedAt: 100)
        var client = Self.failingClient()
        client.move = { params in
            #expect(params.id == "card-1")
            #expect(params.status == "running")
            #expect(params.position == 1000)
            return moved
        }
        client.archive = { params in
            #expect(params.id == "card-1")
            #expect(params.archived)
            return archived
        }
        var initialState = IPadWorkboardFeature.State()
        initialState.cardEntries = .init(values: [card])
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.moveRequested(.init(
            card: card,
            status: .init(value: "running"),
            gatewayAccess: .init(canRead: true, canWrite: true))))
        {
            $0.busyCardID = .init(value: "card-1")
            $0.errorText = nil
        }
        await store.receive(.moveResponse(.init(result: .success(moved)))) {
            $0.busyCardID = nil
            $0.cardEntries = .init(values: [moved])
            $0.knownBoardIDEntries = .init(values: [.init(value: "default")])
        }
        await store.send(.archiveRequested(.init(
            card: moved,
            gatewayAccess: .init(canRead: true, canWrite: true))))
        {
            $0.busyCardID = .init(value: "card-1")
            $0.errorText = nil
        }
        await store.receive(.archiveResponse(.init(result: .success(archived)))) {
            $0.busyCardID = nil
            $0.cardEntries = .init(values: [archived])
            $0.knownBoardIDEntries = .init(values: [.init(value: "default")])
        }
    }

    @Test func `dispatch returns summary and refreshed cards`() async {
        let refreshed = Self.card(id: "running", status: "running", position: 50)
        let response = IPadWorkboardCardsResponse(cards: [refreshed], statuses: ["running"])
        let summary = IPadWorkboardDispatchSummary(startedCount: 1, dispatchCount: 1)
        var client = Self.failingClient()
        client.dispatch = { boardScope in
            #expect(boardScope.boardID == nil)
            return summary
        }
        client.listCards = { boardScope in
            #expect(boardScope.boardID == nil)
            return response
        }
        let store = TestStore(initialState: IPadWorkboardFeature.State()) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.dispatchRequested(.init(gatewayAccess: .init(canRead: true, canWrite: true)))) {
            $0.dispatchPhase = .inFlight
            $0.errorText = nil
            $0.dispatchSummaryText = nil
        }
        await store.receive(.dispatchResponse(.init(
            boardScope: .init(boardID: nil),
            result: .success(IPadWorkboardDispatchSnapshot(
                summary: summary,
                cardsResponse: response)))))
        {
            $0.dispatchPhase = .idle
            $0.dispatchSummaryText = .init(value: "1 dispatched: 1 started.")
            $0.cardEntries = .init(values: [refreshed])
            $0.statusEntries = .init(values: [.init(value: "running")])
            $0.knownBoardIDEntries = .init(values: [.init(value: "default")])
        }
    }

    @Test func `refresh completion does not clear dispatch busy state`() async {
        let refreshed = Self.card(id: "card", status: "todo", position: 10)
        let response = IPadWorkboardCardsResponse(cards: [refreshed], statuses: ["todo"])
        var initialState = IPadWorkboardFeature.State()
        initialState.refreshPhase = .inFlight(boardID: nil)
        initialState.dispatchPhase = .inFlight
        var client = Self.failingClient()
        client.listBoards = { [] }
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.refreshResponse(.init(
            boardScope: .init(boardID: nil),
            force: .init(isForced: true),
            result: .success(response))))
        {
            $0.refreshPhase = .idle
            $0.cardEntries = .init(values: [refreshed])
            $0.statusEntries = .init(values: [.init(value: "todo")])
            $0.knownBoardIDEntries = .init(values: [.init(value: "default")])
        }
        await store.receive(.boardScopesResponse(.init(force: .init(isForced: true), result: .success([]))))
    }

    private static func failingClient() -> IPadWorkboardClient {
        IPadWorkboardClient(
            listCards: { _ in throw IPadWorkboardError.failed(.init(message: .init(value: "unexpected listCards"))) },
            listBoards: { throw IPadWorkboardError.failed(.init(message: .init(value: "unexpected listBoards"))) },
            create: { _ in throw IPadWorkboardError.failed(.init(message: .init(value: "unexpected create"))) },
            move: { _ in throw IPadWorkboardError.failed(.init(message: .init(value: "unexpected move"))) },
            archive: { _ in throw IPadWorkboardError.failed(.init(message: .init(value: "unexpected archive"))) },
            dispatch: { _ in throw IPadWorkboardError.failed(.init(message: .init(value: "unexpected dispatch"))) })
    }

    private static func card(
        id: String,
        title: String = "Card",
        status: String,
        position: Double,
        boardID: String? = nil,
        archivedAt: Double? = nil,
        notes: String? = nil,
        labels: [String] = [],
        agentID: String? = nil,
        sessionKey: String? = nil) -> IPadWorkboardCard
    {
        IPadWorkboardCard(
            id: id,
            title: title,
            notes: notes,
            status: status,
            priority: nil,
            labels: labels,
            agentId: agentID,
            sessionKey: sessionKey,
            position: position,
            updatedAt: nil,
            metadata: IPadWorkboardMetadata(
                archivedAt: archivedAt,
                automation: IPadWorkboardAutomationMetadata(boardId: boardID)))
    }
}

private enum TestWorkboardFailure: LocalizedError {
    case failed

    var errorDescription: String? {
        "workboard boom"
    }
}
