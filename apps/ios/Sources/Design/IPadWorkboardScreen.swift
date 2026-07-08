import ComposableArchitecture
import OpenClawKit
import SwiftUI

struct IPadWorkboardScreen: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var store: StoreOf<IPadWorkboardFeature>
    let headerLeadingAction: OpenClawSidebarHeaderAction?
    let openChat: () -> Void
    let openSettings: () -> Void

    init(
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        openChat: @escaping () -> Void,
        openSettings: @escaping () -> Void = {},
        store: StoreOf<IPadWorkboardFeature>? = nil,
        storeFactory: () -> StoreOf<IPadWorkboardFeature> = {
            Store(initialState: IPadWorkboardFeature.State()) {
                IPadWorkboardFeature()
            }
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.openChat = openChat
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
                self.compactQueueControls
                self.compactCardsPanel
            } else {
                ProMetricGrid(metrics: self.metrics)
                self.controlsCard
                self.kanbanBoard
            }
        }
        .task(id: self.refreshTaskID) {
            await self.loadCards(force: false)
        }
        .refreshable {
            await self.loadCards(force: true)
        }
        .sheet(item: self.presentedSheetBinding) { sheet in
            switch sheet {
            case .create:
                NavigationStack {
                    self.createCardSheet
                }
            case let .card(card):
                IPadWorkboardCardDetailSheet(
                    card: card,
                    presentation: self.store.state.cardPresentation(for: card),
                    moveActions: self.store.state.moveActionPresentations(for: self.store.statusValues),
                    actionControlsPresentation: self.store.state.cardDetailActionControlsPresentation(
                        for: card,
                        canWrite: self.gatewayAccess.canWrite),
                    openSession: { self.open(card) },
                    move: { status in Task { await self.move(card, to: status) } },
                    archive: { Task { await self.archive(card) } })
            }
        }
    }

    private var metrics: [ProMetric] {
        self.store.metricPresentations.map { presentation in
            ProMetric(
                icon: presentation.iconSystemName,
                title: presentation.title,
                value: presentation.value,
                color: Self.metricColor(for: presentation.tone))
        }
    }

    private static func metricColor(for tone: IPadWorkboardMetricTone) -> Color {
        switch tone {
        case .accent:
            OpenClawBrand.accent
        case .ok:
            OpenClawBrand.ok
        case .warn:
            OpenClawBrand.warn
        }
    }

    private static func messageColor(for tone: IPadWorkboardStatusMessageTone) -> Color {
        switch tone {
        case .accent:
            OpenClawBrand.accent
        case .warn:
            OpenClawBrand.warn
        }
    }

    private var controlsCard: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 12) {
                self.boardScopeMenu
                self.searchField
                if self.isCompactWidth {
                    self.statusMenu
                } else {
                    Picker(self.statusFilterControlPresentation.pickerTitle, selection: self.selectedStatusBinding) {
                        ForEach(self.statusFilterControlPresentation.options) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .tint(OpenClawBrand.accent)
                }

                HStack(spacing: 8) {
                    self.newCardButton(expands: false)

                    Button {
                        Task { await self.dispatchCards() }
                    } label: {
                        Label(
                            self.dispatchControlPresentation.title,
                            systemImage: self.dispatchControlPresentation.iconSystemName)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(self.dispatchControlPresentation.isDisabled)

                    Button {
                        Task { await self.loadCards(force: true) }
                    } label: {
                        Label(
                            self.refreshControlPresentation.title,
                            systemImage: self.refreshControlPresentation.iconSystemName)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(self.neutralControlTint)
                    .disabled(self.refreshControlPresentation.isDisabled)

                    if self.refreshControlPresentation.showsProgress {
                        ProgressView().controlSize(.small)
                    }
                }

                self.statusMessageRows
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var compactQueueControls: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(self.queueSummaryPresentation.cardCountLabel)
                        .font(.headline)
                    Spacer(minLength: 8)
                    self.compactRefreshButton
                }

                self.compactBoardScopeMenu
                self.compactStatusPicker

                if self.compactWriteControlsPresentation.showsWriteControls {
                    HStack(spacing: 8) {
                        self.newCardButton(expands: true)

                        Button {
                            Task { await self.dispatchCards() }
                        } label: {
                            Label(
                                self.dispatchControlPresentation.title,
                                systemImage: self.dispatchControlPresentation.iconSystemName)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(self.dispatchControlPresentation.isDisabled)
                    }
                } else {
                    Text(self.compactWriteControlsPresentation.unavailablePresentation.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                self.statusMessageRows
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var statusMessageRows: some View {
        ForEach(self.store.statusMessagePresentations) { message in
            Text(message.text)
                .font(.caption2)
                .foregroundStyle(Self.messageColor(for: message.tone))
        }
    }

    private var compactRefreshButton: some View {
        Button {
            Task { await self.loadCards(force: true) }
        } label: {
            Image(systemName: self.refreshControlPresentation.iconSystemName)
                .font(.caption.weight(.semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(self.neutralControlTint)
        .accessibilityLabel(self.refreshControlPresentation.compactAccessibilityLabel)
        .disabled(self.refreshControlPresentation.isDisabled)
    }

    private func newCardButton(expands: Bool) -> some View {
        Button {
            self.beginCreateCard()
        } label: {
            Label(
                self.createCardPresentation.buttonTitle,
                systemImage: self.createCardPresentation.buttonIconSystemName)
                .frame(maxWidth: expands ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(self.createCardPresentation.isButtonDisabled)
        .accessibilityHint(self.createCardPresentation.buttonAccessibilityHint)
    }

    private var searchField: some View {
        let presentation = self.store.queryFieldPresentation
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

    private var compactBoardScopeMenu: some View {
        Menu {
            self.boardScopeMenuItems
        } label: {
            HStack(spacing: 8) {
                Image(systemName: self.boardScopeMenuPresentation.leadingIconSystemName)
                    .font(.caption.weight(.semibold))
                Text(self.boardScopeMenuPresentation.selectedLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: self.boardScopeMenuPresentation.selectorIconSystemName)
                    .font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(self.boardScopeMenuPresentation.accessibilityLabel)
    }

    private var compactStatusPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(self.statusFilterControlPresentation.compactOptions) { option in
                    self.compactStatusChip(option)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [.clear, Color(uiColor: .secondarySystemGroupedBackground)],
                startPoint: .leading,
                endPoint: .trailing)
                .frame(width: 24)
                .allowsHitTesting(false)
        }
    }

    private func compactStatusChip(_ option: IPadWorkboardStatusFilterOption) -> some View {
        Button {
            self.store.send(.statusChanged(.init(status: .init(value: option.id))))
        } label: {
            Text(option.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    option.isSelected
                        ? OpenClawBrand.accent.opacity(0.12)
                        : Color.primary.opacity(0.06),
                    in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            option.isSelected
                                ? OpenClawBrand.accent.opacity(0.42)
                                : Color.primary.opacity(0.08),
                            lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            option.isSelected
                ? OpenClawBrand.accent
                : .primary)
        .accessibilityLabel(option.accessibilityLabel)
    }

    private var boardScopeMenu: some View {
        HStack(spacing: 8) {
            Text(self.boardScopeMenuPresentation.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Menu {
                self.boardScopeMenuItems
            } label: {
                HStack(spacing: 6) {
                    Text(self.boardScopeMenuPresentation.selectedLabel)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: self.boardScopeMenuPresentation.selectorIconSystemName)
                        .font(.caption2.weight(.bold))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(self.neutralControlTint)
            .accessibilityLabel(self.boardScopeMenuPresentation.accessibilityLabel)
        }
    }

    private var boardScopeMenuItems: some View {
        ForEach(self.boardScopeMenuPresentation.options) { option in
            Button(option.title) {
                self.store.send(.boardScopeChanged(.init(boardID: .init(value: option.id))))
            }
        }
    }

    private var statusMenu: some View {
        HStack(spacing: 8) {
            Text(self.statusFilterControlPresentation.menuTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Menu {
                self.statusFilterMenuItems
            } label: {
                HStack(spacing: 6) {
                    Text(self.statusFilterControlPresentation.selectedLabel)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: self.statusFilterControlPresentation.selectorIconSystemName)
                        .font(.caption2.weight(.bold))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(self.neutralControlTint)
        }
    }

    private var statusFilterMenuItems: some View {
        ForEach(self.statusFilterControlPresentation.options) { option in
            Button(option.title) {
                self.store.send(.statusChanged(.init(status: .init(value: option.id))))
            }
        }
    }

    private var draftNotesBinding: Binding<String> {
        Binding(
            get: { self.store.draftNotes.value },
            set: { self.store.send(.draftNotesChanged(.init(notes: .init(value: $0)))) })
    }

    private var draftTitleBinding: Binding<String> {
        Binding(
            get: { self.store.draftTitle.value },
            set: { self.store.send(.draftTitleChanged(.init(title: .init(value: $0)))) })
    }

    private var presentedSheetBinding: Binding<IPadWorkboardSheet?> {
        Binding(
            get: { self.store.presentedSheet },
            set: { sheet in
                if sheet == nil {
                    self.store.send(.sheetDismissed)
                }
            })
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { self.store.queryFieldPresentation.text },
            set: { self.store.send(.queryChanged(.init(query: .init(value: $0)))) })
    }

    private var selectedStatusBinding: Binding<String> {
        Binding(
            get: { self.statusFilterControlPresentation.selectedFilter },
            set: { self.store.send(.statusChanged(.init(status: .init(value: $0)))) })
    }

    private var neutralControlTint: Color {
        Color.primary.opacity(0.55)
    }

    private var kanbanBoard: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(self.store.visibleKanbanStatuses, id: \.self) { status in
                    let cards = self.store.state.cards(forKanbanStatus: status)
                    IPadWorkboardKanbanColumn(
                        presentation: self.store.state.kanbanLanePresentation(status: status, cards: cards),
                        cards: cards,
                        moveActions: self.store.state.moveActionPresentations(for: self.store.statusValues),
                        actionControlPresentation: { card in
                            self.store.state.cardActionControlPresentation(for: card, context: .kanban)
                        },
                        openSession: { card in
                            self.open(card)
                        },
                        inspect: { card in
                            self.store.send(.cardSheetPresented(.init(card: card)))
                        },
                        move: { card, status in
                            Task { await self.move(card, to: status) }
                        },
                        archive: { card in
                            Task { await self.archive(card) }
                        })
                        .frame(width: 282)
                }
            }
            .padding(.horizontal, OpenClawProMetric.pagePadding)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.visible)
    }

    private var compactCardsPanel: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: self.queueSummaryPresentation.title,
                    value: self.queueSummaryPresentation.value,
                    actionTitle: nil,
                    action: nil)
                if self.store.filteredCards.isEmpty {
                    ProStatusRow(
                        icon: self.compactEmptyStatePresentation.icon,
                        title: self.compactEmptyStatePresentation.title,
                        detail: self.compactEmptyStatePresentation.detail,
                        value: self.compactEmptyStatePresentation.value,
                        color: .secondary,
                        actionTitle: nil,
                        action: nil)
                } else {
                    ForEach(Array(self.store.filteredCards.enumerated()), id: \.element.id) { index, card in
                        if index > 0 {
                            Divider().padding(.leading, 58)
                        }
                        IPadWorkboardQueueRow(
                            card: card,
                            presentation: self.store.state.cardPresentation(for: card),
                            moveActions: self.store.state.moveActionPresentations(for: self.store.statusValues),
                            nextMoveAction: self.store.state.nextMoveActionPresentation(
                                for: card,
                                statuses: self.store.statusValues),
                            actionControlPresentation: self.store.state.cardActionControlPresentation(
                                for: card,
                                context: .queue),
                            inspect: {
                                self.store.send(.cardSheetPresented(.init(card: card)))
                            },
                            openSession: {
                                self.open(card)
                            },
                            move: { status in
                                Task { await self.move(card, to: status) }
                            },
                            archive: {
                                Task { await self.archive(card) }
                            })
                    }
                }
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var createCardSheet: some View {
        Form {
            Section(self.createCardPresentation.sheet.sectionTitle) {
                TextField(self.createCardPresentation.sheet.titlePlaceholder, text: self.draftTitleBinding)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                TextField(
                    self.createCardPresentation.sheet.notesPlaceholder,
                    text: self.draftNotesBinding,
                    axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
            }
            if let errorMessage = self.createCardPresentation.sheet.errorMessage {
                Section {
                    Text(errorMessage.text)
                        .foregroundStyle(Self.messageColor(for: errorMessage.tone))
                }
            }
        }
        .navigationTitle(self.createCardPresentation.sheet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(self.createCardPresentation.sheet.cancelTitle) {
                    self.store.send(.sheetDismissed)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await self.createCard()
                    }
                } label: {
                    Text(self.createCardPresentation.sheet.confirmationTitle)
                }
                .disabled(self.createCardPresentation.sheet.isConfirmationDisabled)
                .accessibilityHint(self.createCardPresentation.sheet.confirmationAccessibilityHint)
            }
        }
    }

    private var refreshTaskID: String {
        self.screenPresentation.refreshTaskID
    }

    private var gatewayAccess: IPadWorkboardGatewayAccess {
        IPadWorkboardFeature.State.gatewayAccess(
            isOperatorGatewayConnected: self.appModel.isOperatorGatewayConnected,
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled)
    }

    private var screenPresentation: IPadWorkboardScreenPresentation {
        self.store.state.screenPresentation(
            gatewayAccess: self.gatewayAccess,
            sceneIsActive: self.scenePhase == .active)
    }

    private var boardScopeMenuPresentation: IPadWorkboardBoardScopeMenuPresentation {
        self.screenPresentation.boardScopeMenuPresentation
    }

    private var queueSummaryPresentation: IPadWorkboardQueueSummaryPresentation {
        self.screenPresentation.queueSummaryPresentation
    }

    private var refreshControlPresentation: IPadWorkboardRefreshControlPresentation {
        self.screenPresentation.refreshControlPresentation
    }

    private var createCardPresentation: IPadWorkboardCreateCardPresentation {
        self.store.state.createCardPresentation(gatewayAccess: self.gatewayAccess)
    }

    private var dispatchControlPresentation: IPadWorkboardDispatchControlPresentation {
        self.store.state.dispatchControlPresentation(gatewayAccess: self.gatewayAccess)
    }

    private var compactEmptyStatePresentation: IPadWorkboardCompactEmptyStatePresentation {
        self.store.state.compactEmptyStatePresentation(gatewayAccess: self.gatewayAccess)
    }

    private var compactWriteControlsPresentation: IPadWorkboardCompactWriteControlsPresentation {
        self.store.state.compactWriteControlsPresentation(gatewayAccess: self.gatewayAccess)
    }

    private var statusFilterControlPresentation: IPadWorkboardStatusFilterControlPresentation {
        self.screenPresentation.statusFilterControlPresentation
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

    private func loadCards(force: Bool) async {
        await self.store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: self.scenePhase == .active),
            readAccess: .init(canRead: self.gatewayAccess.canRead),
            force: .init(isForced: force)))).finish()
    }

    private func beginCreateCard() {
        self.store.send(.beginCreateCardTapped)
    }

    private func createCard() async {
        await self.store.send(.createRequested(.init(
            readAccess: .init(canRead: self.gatewayAccess.canRead),
            writeAccess: .init(canWrite: self.gatewayAccess.canWrite)))).finish()
    }

    private func move(_ card: IPadWorkboardCard, to status: String) async {
        await self.store.send(.moveRequested(.init(
            card: card,
            status: .init(value: status),
            writeAccess: .init(canWrite: self.gatewayAccess.canWrite)))).finish()
    }

    private func archive(_ card: IPadWorkboardCard) async {
        await self.store.send(.archiveRequested(.init(
            card: card,
            writeAccess: .init(canWrite: self.gatewayAccess.canWrite)))).finish()
    }

    private func dispatchCards() async {
        await self.store.send(.dispatchRequested(.init(writeAccess: .init(canWrite: self.gatewayAccess.canWrite))))
            .finish()
    }

    private func open(_ card: IPadWorkboardCard) {
        guard let sessionKey = self.store.state.cardPresentation(for: card).sessionKey else { return }
        self.appModel.openChat(sessionKey: sessionKey)
        self.openChat()
    }
}

struct IPadWorkboardKanbanColumn: View {
    let presentation: IPadWorkboardKanbanLanePresentation
    let cards: [IPadWorkboardCard]
    let moveActions: [IPadWorkboardMoveActionPresentation]
    let actionControlPresentation: (IPadWorkboardCard) -> IPadWorkboardCardActionControlPresentation
    let openSession: (IPadWorkboardCard) -> Void
    let inspect: (IPadWorkboardCard) -> Void
    let move: (IPadWorkboardCard, String) -> Void
    let archive: (IPadWorkboardCard) -> Void

    var body: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: self.presentation.title,
                    value: self.presentation.value,
                    actionTitle: nil,
                    action: nil)

                if self.cards.isEmpty {
                    ProStatusRow(
                        icon: self.presentation.emptyState.icon,
                        title: self.presentation.emptyState.title,
                        detail: self.presentation.emptyState.detail,
                        value: self.presentation.emptyState.value,
                        color: .secondary,
                        actionTitle: nil,
                        action: nil)
                } else {
                    ForEach(Array(self.cards.enumerated()), id: \.element.id) { index, card in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        IPadWorkboardKanbanCard(
                            card: card,
                            presentation: IPadWorkboardFeature.State.cardPresentation(for: card),
                            moveActions: self.moveActions,
                            actionControlPresentation: self.actionControlPresentation(card),
                            openSession: {
                                self.openSession(card)
                            },
                            inspect: {
                                self.inspect(card)
                            },
                            move: { status in
                                self.move(card, status)
                            },
                            archive: {
                                self.archive(card)
                            })
                    }
                }
            }
        }
    }
}

private enum IPadWorkboardCardColor {
    static func value(for tone: IPadWorkboardCardTone) -> Color {
        switch tone {
        case .accent:
            OpenClawBrand.accent
        case .accentHot:
            OpenClawBrand.accentHot
        case .ok:
            OpenClawBrand.ok
        case .secondary:
            .secondary
        case .warn:
            OpenClawBrand.warn
        }
    }
}

private struct IPadWorkboardKanbanCard: View {
    let card: IPadWorkboardCard
    let presentation: IPadWorkboardCardPresentation
    let moveActions: [IPadWorkboardMoveActionPresentation]
    let actionControlPresentation: IPadWorkboardCardActionControlPresentation
    let openSession: () -> Void
    let inspect: () -> Void
    let move: (String) -> Void
    let archive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: self.inspect) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 10) {
                        ProIconBadge(systemName: self.presentation.iconSystemName, color: self.color)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(self.presentation.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text(self.presentation.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }

                    if let labelsSummary = self.presentation.labelsSummary {
                        Text(labelsSummary)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if self.presentation.showsOpenSessionAction {
                    Button(action: self.openSession) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                    }
                    .accessibilityLabel(self.presentation.openSessionActionTitle)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Menu {
                    ForEach(self.moveActions) { action in
                        Button(action.menuTitle) {
                            self.move(action.status)
                        }
                    }
                    Button(self.presentation.archiveActionTitle, action: self.archive)
                } label: {
                    Image(systemName: self.actionControlPresentation.iconSystemName)
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel(self.actionControlPresentation.accessibilityLabel)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(self.actionControlPresentation.isDisabled)

                Spacer(minLength: 4)
                ProValuePill(value: self.presentation.statusLabel, color: self.color)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private var color: Color {
        IPadWorkboardCardColor.value(for: self.presentation.tone)
    }
}

struct IPadWorkboardQueueRow: View {
    let card: IPadWorkboardCard
    let presentation: IPadWorkboardCardPresentation
    let moveActions: [IPadWorkboardMoveActionPresentation]
    let nextMoveAction: IPadWorkboardMoveActionPresentation?
    let actionControlPresentation: IPadWorkboardCardActionControlPresentation
    let inspect: () -> Void
    let openSession: () -> Void
    let move: (String) -> Void
    let archive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: self.inspect) {
                HStack(alignment: .top, spacing: 12) {
                    ProIconBadge(systemName: self.presentation.iconSystemName, color: self.color)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(self.presentation.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(self.presentation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    ProValuePill(value: self.presentation.statusLabel, color: self.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                self.actionMenuItems
            } label: {
                Image(systemName: self.actionControlPresentation.iconSystemName)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(OpenClawBrand.accent)
            .disabled(self.actionControlPresentation.isDisabled)
            .accessibilityLabel(self.actionControlPresentation.accessibilityLabel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contextMenu {
            self.actionMenuItems
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(self.presentation.inspectActionTitle, action: self.inspect)
                .tint(OpenClawBrand.accent)
            if self.presentation.showsOpenSessionAction {
                Button(self.presentation.compactOpenSessionActionTitle, action: self.openSession)
                    .tint(OpenClawBrand.ok)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let nextMoveAction {
                Button(nextMoveAction.title) {
                    self.move(nextMoveAction.status)
                }
                .tint(OpenClawBrand.accentHot)
            }
            Button(self.presentation.archiveActionTitle, action: self.archive)
                .tint(.secondary)
        }
    }

    @ViewBuilder
    private var actionMenuItems: some View {
        if self.presentation.showsOpenSessionAction {
            Button(self.presentation.openSessionActionTitle, action: self.openSession)
        }
        Button(self.presentation.inspectActionTitle, action: self.inspect)
        ForEach(self.moveActions) { action in
            Button(action.menuTitle) {
                self.move(action.status)
            }
        }
        Button(self.presentation.archiveActionTitle, action: self.archive)
    }

    private var color: Color {
        IPadWorkboardCardColor.value(for: self.presentation.tone)
    }
}

private struct IPadWorkboardCardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: IPadWorkboardCard
    let presentation: IPadWorkboardCardPresentation
    let moveActions: [IPadWorkboardMoveActionPresentation]
    let actionControlsPresentation: IPadWorkboardCardDetailActionControlsPresentation
    let openSession: () -> Void
    let move: (String) -> Void
    let archive: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(self.presentation.detailSectionTitle) {
                    LabeledContent(self.presentation.titleFieldTitle, value: self.presentation.title)
                    LabeledContent(self.presentation.statusFieldTitle, value: self.presentation.statusLabel)
                    if let notes = self.presentation.notesText {
                        Text(notes)
                    }
                }

                Section(self.presentation.actionsSectionTitle) {
                    if self.presentation.showsOpenSessionAction {
                        Button(self.presentation.openSessionActionTitle, action: self.openSession)
                    }
                    Menu(self.presentation.moveMenuTitle) {
                        ForEach(self.moveActions) { action in
                            Button(action.title) {
                                self.move(action.status)
                            }
                        }
                    }
                    .disabled(self.actionControlsPresentation.isMutationDisabled)
                    Button(self.presentation.archiveActionTitle, action: self.archive)
                        .disabled(self.actionControlsPresentation.isMutationDisabled)
                }
            }
            .navigationTitle(self.presentation.detailSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(self.presentation.doneActionTitle) {
                        self.dismiss()
                    }
                }
            }
        }
    }
}

// swiftformat:disable redundantSendable
enum IPadWorkboardSheet: Equatable, Identifiable, Sendable {
    case create
    case card(IPadWorkboardCard)

    var id: String {
        switch self {
        case .create:
            "create"
        case let .card(card):
            "card-\(card.id)"
        }
    }
}

enum IPadWorkboardDefaults {
    static let statuses = ["todo", "scheduled", "ready", "running", "review", "blocked", "done"]

    static func label(for status: String) -> String {
        status
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func rank(_ status: String) -> Int {
        self.statuses.firstIndex(of: status) ?? Int.max
    }
}

struct IPadWorkboardCardsResponse: Decodable, Equatable, Sendable {
    let cards: [IPadWorkboardCard]
    let statuses: [String]?
}

struct IPadWorkboardCardResponse: Decodable, Equatable, Sendable {
    let card: IPadWorkboardCard
}

struct IPadWorkboardBoardsResponse: Decodable, Equatable, Sendable {
    let boards: [IPadWorkboardBoardSummary]
}

struct IPadWorkboardBoardSummary: Decodable, Equatable, Sendable {
    let id: String
}

struct IPadWorkboardCard: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let status: String
    let priority: String?
    let labels: [String]
    let agentId: String?
    let sessionKey: String?
    let position: Double
    let updatedAt: Double?
    let metadata: IPadWorkboardMetadata?
}

struct IPadWorkboardMetadata: Decodable, Equatable, Sendable {
    let archivedAt: Double?
    let automation: IPadWorkboardAutomationMetadata?
}

struct IPadWorkboardAutomationMetadata: Decodable, Equatable, Sendable {
    let boardId: String?
}

struct IPadWorkboardListParams: Encodable, Equatable, Sendable {
    let boardId: String?
}

struct IPadWorkboardCreateParams: Encodable, Equatable, Sendable {
    let title: String
    let notes: String
    let status: String
    let priority: String
    let labels: [String]
    let agentId: String
    let sessionKey: String?
    let position: Double
    let boardId: String?
}

struct IPadWorkboardMoveParams: Encodable, Equatable, Sendable {
    let id: String
    let status: String
    let position: Double
}

struct IPadWorkboardArchiveParams: Encodable, Equatable, Sendable {
    let id: String
    let archived: Bool
}

struct IPadWorkboardDispatchSummary: Decodable, Equatable, Sendable {
    private let startedCount: Int
    private let startFailureCount: Int
    private let promotedCount: Int
    private let blockedCount: Int
    private let reclaimedCount: Int
    private let orchestratedCount: Int
    private let dispatchCount: Int

    private enum CodingKeys: String, CodingKey {
        case started
        case startFailures
        case promoted
        case blocked
        case reclaimed
        case orchestrated
        case count
    }

    init(
        startedCount: Int = 0,
        startFailureCount: Int = 0,
        promotedCount: Int = 0,
        blockedCount: Int = 0,
        reclaimedCount: Int = 0,
        orchestratedCount: Int = 0,
        dispatchCount: Int = 0)
    {
        self.startedCount = startedCount
        self.startFailureCount = startFailureCount
        self.promotedCount = promotedCount
        self.blockedCount = blockedCount
        self.reclaimedCount = reclaimedCount
        self.orchestratedCount = orchestratedCount
        self.dispatchCount = dispatchCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startedCount = Self.arrayCount(container, .started)
        self.startFailureCount = Self.arrayCount(container, .startFailures)
        self.promotedCount = Self.arrayCount(container, .promoted)
        self.blockedCount = Self.arrayCount(container, .blocked)
        self.reclaimedCount = Self.arrayCount(container, .reclaimed)
        self.orchestratedCount = Self.arrayCount(container, .orchestrated)
        self.dispatchCount = (try? container.decode(Int.self, forKey: .count)) ?? 0
    }

    var summaryText: String {
        let total = max(
            dispatchCount,
            self.startedCount + self.promotedCount + self.reclaimedCount + self.orchestratedCount +
                self.blockedCount + self.startFailureCount)
        if total == 0, self.startFailureCount == 0, self.blockedCount == 0 {
            return "No cards dispatched."
        }
        let outcomes = [
            Self.outcomeText(self.startedCount, "started"),
            Self.outcomeText(self.promotedCount, "promoted"),
            Self.outcomeText(self.reclaimedCount, "reclaimed"),
            Self.outcomeText(self.orchestratedCount, "orchestrated"),
            Self.outcomeText(self.blockedCount, "blocked"),
            Self.outcomeText(self.startFailureCount, "failed"),
        ].compactMap(\.self)
        guard !outcomes.isEmpty else {
            return "\(total) dispatched."
        }
        return "\(total) dispatched: \(outcomes.joined(separator: ", "))."
    }

    private static func arrayCount(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys) -> Int
    {
        (try? container.decode([IPadWorkboardDispatchEntry].self, forKey: key).count) ?? 0
    }

    private static func outcomeText(_ count: Int, _ label: String) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(label)"
    }
}

private struct IPadWorkboardDispatchEntry: Decodable, Equatable, Sendable {}

// swiftformat:enable redundantSendable
