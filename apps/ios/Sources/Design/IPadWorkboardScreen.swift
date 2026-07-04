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
        store: StoreOf<IPadWorkboardFeature> = Store(
            initialState: IPadWorkboardFeature.State())
        {
            IPadWorkboardFeature()
        })
    {
        self.headerLeadingAction = headerLeadingAction
        self.openChat = openChat
        self.openSettings = openSettings
        self._store = State(wrappedValue: store)
    }

    var body: some View {
        IPadSidebarScreenChrome(
            title: "Workboard",
            subtitle: self.currentWorkboardSubtitle,
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
        .task(id: self.refreshID) {
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
                    statuses: self.store.statuses,
                    isBusy: self.store.busyCardID == card.id,
                    canWrite: self.canWrite,
                    openSession: { self.open(card) },
                    move: { status in Task { await self.move(card, to: status) } },
                    archive: { Task { await self.archive(card) } })
            }
        }
    }

    private var metrics: [ProMetric] {
        [
            ProMetric(
                icon: "tray.full",
                title: "Cards",
                value: "\(self.store.cards.count)",
                color: OpenClawBrand.accent),
            ProMetric(
                icon: "figure.run",
                title: "Running",
                value: "\(self.store.cards.count(where: { $0.status == "running" }))",
                color: OpenClawBrand.ok),
            ProMetric(
                icon: "exclamationmark.triangle",
                title: "Blocked",
                value: "\(self.store.cards.count(where: { $0.status == "blocked" }))",
                color: OpenClawBrand.warn),
        ]
    }

    private var controlsCard: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 12) {
                self.boardScopeMenu
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Search cards", text: self.queryBinding)
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
                if self.isCompactWidth {
                    self.statusMenu
                } else {
                    Picker("Scope", selection: self.selectedStatusBinding) {
                        Text("Active").tag("active")
                        ForEach(self.store.statuses, id: \.self) { status in
                            Text(IPadWorkboardDefaults.label(for: status)).tag(status)
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
                        Label("Dispatch", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!self.canWrite || self.store.isLoading)

                    Button {
                        Task { await self.loadCards(force: true) }
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

                if let dispatchSummaryText = self.store.dispatchSummaryText {
                    Text(dispatchSummaryText)
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

    private var compactQueueControls: some View {
        ProCard(radius: OpenClawProMetric.cardRadius) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(self.store.filteredCards.count) cards")
                        .font(.headline)
                    Spacer(minLength: 8)
                    self.compactRefreshButton
                }

                self.compactBoardScopeMenu
                self.compactStatusPicker

                if self.canWrite {
                    HStack(spacing: 8) {
                        self.newCardButton(expands: true)

                        Button {
                            Task { await self.dispatchCards() }
                        } label: {
                            Label("Dispatch", systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(self.store.isLoading)
                    }
                } else {
                    Text(Self.compactWriteUnavailableMessage(canRead: self.canRead))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let dispatchSummaryText = self.store.dispatchSummaryText {
                    Text(dispatchSummaryText)
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

    private var compactRefreshButton: some View {
        Button {
            Task { await self.loadCards(force: true) }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(self.neutralControlTint)
        .accessibilityLabel("Refresh workboard")
        .disabled(self.store.isLoading)
    }

    private func newCardButton(expands: Bool) -> some View {
        Button {
            self.beginCreateCard()
        } label: {
            Label("New Card", systemImage: "plus")
                .frame(maxWidth: expands ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(self.store.isCreatingCard)
        .accessibilityHint("Opens card title and notes entry")
    }

    private var compactBoardScopeMenu: some View {
        Menu {
            Button("All boards") {
                self.store.send(.boardScopeChanged(""))
            }
            ForEach(self.boardScopeOptions, id: \.self) { boardID in
                Button(Self.boardScopeLabel(for: boardID)) {
                    self.store.send(.boardScopeChanged(boardID))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack")
                    .font(.caption.weight(.semibold))
                Text(self.boardScopeLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
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
        .accessibilityLabel("Workboard board scope")
    }

    private var compactStatusPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                self.compactStatusChip("active")
                ForEach(self.store.compactStatuses, id: \.self) { status in
                    self.compactStatusChip(status)
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

    private func compactStatusChip(_ status: String) -> some View {
        Button {
            self.store.send(.statusChanged(status))
        } label: {
            Text(IPadWorkboardDefaults.label(for: status))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    self.store.selectedStatus == status
                        ? OpenClawBrand.accent.opacity(0.12)
                        : Color.primary.opacity(0.06),
                    in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            self.store.selectedStatus == status
                                ? OpenClawBrand.accent.opacity(0.42)
                                : Color.primary.opacity(0.08),
                            lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(self.store.selectedStatus == status ? OpenClawBrand.accent : .primary)
        .accessibilityLabel("Show \(IPadWorkboardDefaults.label(for: status)) cards")
    }

    private var boardScopeMenu: some View {
        HStack(spacing: 8) {
            Text("Board")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Menu {
                Button("All boards") {
                    self.store.send(.boardScopeChanged(""))
                }
                ForEach(self.boardScopeOptions, id: \.self) { boardID in
                    Button(Self.boardScopeLabel(for: boardID)) {
                        self.store.send(.boardScopeChanged(boardID))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(self.boardScopeLabel)
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
            .accessibilityLabel("Workboard board scope")
        }
    }

    private var statusMenu: some View {
        HStack(spacing: 8) {
            Text("Status")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Menu {
                Button("Active") {
                    self.store.send(.statusChanged("active"))
                }
                ForEach(self.store.statuses, id: \.self) { status in
                    Button(IPadWorkboardDefaults.label(for: status)) {
                        self.store.send(.statusChanged(status))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(IPadWorkboardDefaults.label(for: self.store.selectedStatus))
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(self.neutralControlTint)
        }
    }

    private var draftNotesBinding: Binding<String> {
        Binding(
            get: { self.store.draftNotes },
            set: { self.store.send(.draftNotesChanged($0)) })
    }

    private var draftTitleBinding: Binding<String> {
        Binding(
            get: { self.store.draftTitle },
            set: { self.store.send(.draftTitleChanged($0)) })
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
            get: { self.store.query },
            set: { self.store.send(.queryChanged($0)) })
    }

    private var selectedStatusBinding: Binding<String> {
        Binding(
            get: { self.store.selectedStatus },
            set: { self.store.send(.statusChanged($0)) })
    }

    private var neutralControlTint: Color {
        Color.primary.opacity(0.55)
    }

    private var kanbanBoard: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(self.store.visibleKanbanStatuses, id: \.self) { status in
                    IPadWorkboardKanbanColumn(
                        status: status,
                        cards: self.cards(forKanbanStatus: status),
                        statuses: self.store.statuses,
                        busyCardID: self.store.busyCardID,
                        openSession: { card in
                            self.open(card)
                        },
                        inspect: { card in
                            self.store.send(.cardSheetPresented(card))
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
                    title: "Queue",
                    value: "\(self.store.filteredCards.count)",
                    actionTitle: nil,
                    action: nil)
                if self.store.filteredCards.isEmpty {
                    ProStatusRow(
                        icon: self.canRead ? "tray" : "wifi.slash",
                        title: self.canRead ? "No cards" : "No cards loaded",
                        detail: self.canRead
                            ? "Create a card or change the filter."
                            : "Connect from Settings to load workboard cards.",
                        value: self.canRead ? "empty" : nil,
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
                            statuses: self.store.statuses,
                            isBusy: self.store.busyCardID == card.id,
                            inspect: {
                                self.store.send(.cardSheetPresented(card))
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
            Section("Card") {
                TextField("Title", text: self.draftTitleBinding)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                TextField("Notes", text: self.draftNotesBinding, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
            }
            if let errorText = self.store.errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(OpenClawBrand.warn)
                }
            }
        }
        .navigationTitle("New Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    self.store.send(.sheetDismissed)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await self.createCard()
                    }
                } label: {
                    Text(self.store.isCreatingCard ? "Creating..." : "Create")
                }
                .disabled(self.store.isCreatingCard)
                .accessibilityHint(self.createUnavailableMessage ?? "Creates a workboard card")
            }
        }
    }

    private var refreshID: String {
        [
            self.canRead ? "connected" : "offline",
            self.scenePhase == .active ? "active" : "inactive",
            self.store.selectedBoardID.isEmpty ? "all" : self.store.selectedBoardID,
        ].joined(separator: ":")
    }

    private var canRead: Bool {
        self.appModel.isOperatorGatewayConnected
    }

    private var canWrite: Bool {
        self.appModel.isOperatorGatewayConnected && !self.appModel
            .isAppleReviewDemoModeEnabled
    }

    private var currentWorkboardSubtitle: String {
        Self.workboardSubtitle(
            boardScopeLabel: self.boardScopeLabel,
            selectedStatus: self.store.selectedStatus)
    }

    private var boardScopeOptions: [String] {
        self.store.boardScopeOptions
    }

    private var boardScopeLabel: String {
        self.store.boardScopeLabel
    }

    private var createUnavailableMessage: String? {
        IPadWorkboardFeature.State.createUnavailableMessage(
            isCreatingCard: self.store.isCreatingCard,
            trimmedDraftTitle: self.store.trimmedDraftTitle,
            canRead: self.canRead,
            canWrite: self.canWrite)
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

    nonisolated static func workboardSubtitle(boardScopeLabel: String, selectedStatus: String) -> String {
        "\(boardScopeLabel) / \(IPadWorkboardDefaults.label(for: selectedStatus))"
    }

    nonisolated static func compactWriteUnavailableMessage(canRead: Bool) -> String {
        canRead ? "Read-only gateway." : "Connect from Settings to create, move, and dispatch cards."
    }

    nonisolated static func boardScopeOptions(knownBoardIDs: [String], cardBoardIDs: [String]) -> [String] {
        Array(Set((knownBoardIDs + cardBoardIDs).map { self.normalizedScopeID($0) }.filter { !$0.isEmpty }))
            .sorted()
    }

    private func cards(forKanbanStatus status: String) -> [IPadWorkboardCard] {
        IPadWorkboardFeature.State.cardsForKanbanStatus(
            cards: self.store.cards,
            status: status,
            selectedStatus: self.store.selectedStatus,
            query: self.store.query)
    }

    private func loadCards(force: Bool) async {
        await self.store.send(.refreshRequested(
            sceneActive: self.scenePhase == .active,
            canRead: self.canRead,
            force: force)).finish()
    }

    private func beginCreateCard() {
        self.store.send(.beginCreateCardTapped)
    }

    private func createCard() async {
        await self.store.send(.createRequested(.init(canRead: self.canRead, canWrite: self.canWrite))).finish()
    }

    private func move(_ card: IPadWorkboardCard, to status: String) async {
        await self.store.send(.moveRequested(card, status: status, canWrite: self.canWrite)).finish()
    }

    private func archive(_ card: IPadWorkboardCard) async {
        await self.store.send(.archiveRequested(card, canWrite: self.canWrite)).finish()
    }

    private func dispatchCards() async {
        await self.store.send(.dispatchRequested(canWrite: self.canWrite)).finish()
    }

    private func open(_ card: IPadWorkboardCard) {
        guard let sessionKey = Self.normalized(card.sessionKey) else { return }
        self.appModel.openChat(sessionKey: sessionKey)
        self.openChat()
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func boardID(for card: IPadWorkboardCard) -> String {
        self.normalizedScopeID(card.metadata?.automation?.boardId).isEmpty
            ? "default"
            : self.normalizedScopeID(card.metadata?.automation?.boardId)
    }

    nonisolated static func normalizedScopeID(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func boardScopeLabel(for boardID: String) -> String {
        let normalized = self.normalizedScopeID(boardID)
        return normalized.isEmpty ? "All boards" : normalized
    }
}

struct IPadWorkboardKanbanColumn: View {
    let status: String
    let cards: [IPadWorkboardCard]
    let statuses: [String]
    let busyCardID: String?
    let openSession: (IPadWorkboardCard) -> Void
    let inspect: (IPadWorkboardCard) -> Void
    let move: (IPadWorkboardCard, String) -> Void
    let archive: (IPadWorkboardCard) -> Void

    var body: some View {
        ProCard(padding: 0, radius: OpenClawProMetric.cardRadius) {
            VStack(spacing: 0) {
                ProPanelHeader(
                    title: IPadWorkboardDefaults.label(for: self.status),
                    value: "\(self.cards.count)",
                    actionTitle: nil,
                    action: nil)

                if self.cards.isEmpty {
                    ProStatusRow(
                        icon: "tray",
                        title: "No \(IPadWorkboardDefaults.label(for: self.status).lowercased()) cards",
                        detail: "Cards moved into this lane appear here.",
                        value: "empty",
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
                            statuses: self.statuses,
                            isBusy: self.busyCardID == card.id,
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

private struct IPadWorkboardKanbanCard: View {
    let card: IPadWorkboardCard
    let statuses: [String]
    let isBusy: Bool
    let openSession: () -> Void
    let inspect: () -> Void
    let move: (String) -> Void
    let archive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: self.inspect) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 10) {
                        ProIconBadge(systemName: self.icon, color: self.color)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(self.card.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text(self.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }

                    if !self.card.labels.isEmpty {
                        Text(self.card.labels.prefix(3).joined(separator: ", "))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if self.card.sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Button(action: self.openSession) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                    }
                    .accessibilityLabel("Open Session")
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Menu {
                    ForEach(self.statuses, id: \.self) { status in
                        Button("Move to \(IPadWorkboardDefaults.label(for: status))") {
                            self.move(status)
                        }
                    }
                    Button(self.card.metadata?.archivedAt == nil ? "Archive" : "Unarchive", action: self.archive)
                } label: {
                    Image(systemName: self.isBusy ? "hourglass" : "ellipsis")
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel("Card Actions")
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(self.isBusy)

                Spacer(minLength: 4)
                ProValuePill(value: IPadWorkboardDefaults.label(for: self.card.status), color: self.color)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch self.card.status {
        case "running": "figure.run"
        case "review": "checklist"
        case "blocked": "exclamationmark.triangle"
        case "done": "checkmark.circle"
        default: "tray"
        }
    }

    private var color: Color {
        switch self.card.status {
        case "running": OpenClawBrand.ok
        case "review": OpenClawBrand.accent
        case "blocked": OpenClawBrand.warn
        case "done": .secondary
        default: OpenClawBrand.accentHot
        }
    }

    private var detail: String {
        if let notes = card.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return notes
        }
        if let sessionKey = card.sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines), !sessionKey.isEmpty {
            return sessionKey
        }
        return self.card.agentId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? self.card.agentId ?? "Default agent"
            : "Default agent"
    }
}

struct IPadWorkboardQueueRow: View {
    let card: IPadWorkboardCard
    let statuses: [String]
    let isBusy: Bool
    let inspect: () -> Void
    let openSession: () -> Void
    let move: (String) -> Void
    let archive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: self.inspect) {
                HStack(alignment: .top, spacing: 12) {
                    ProIconBadge(systemName: self.icon, color: self.color)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(self.card.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(self.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    ProValuePill(value: IPadWorkboardDefaults.label(for: self.card.status), color: self.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                self.actionMenuItems
            } label: {
                Image(systemName: self.isBusy ? "hourglass" : "ellipsis.circle")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(OpenClawBrand.accent)
            .disabled(self.isBusy)
            .accessibilityLabel("Card Actions")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contextMenu {
            self.actionMenuItems
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Inspect", action: self.inspect)
                .tint(OpenClawBrand.accent)
            if self.card.sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button("Open", action: self.openSession)
                    .tint(OpenClawBrand.ok)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let nextStatus {
                Button(IPadWorkboardDefaults.label(for: nextStatus)) {
                    self.move(nextStatus)
                }
                .tint(OpenClawBrand.accentHot)
            }
            Button(self.card.metadata?.archivedAt == nil ? "Archive" : "Unarchive", action: self.archive)
                .tint(.secondary)
        }
    }

    @ViewBuilder
    private var actionMenuItems: some View {
        if self.card.sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            Button("Open Session", action: self.openSession)
        }
        Button("Inspect", action: self.inspect)
        ForEach(self.statuses, id: \.self) { status in
            Button("Move to \(IPadWorkboardDefaults.label(for: status))") {
                self.move(status)
            }
        }
        Button(self.card.metadata?.archivedAt == nil ? "Archive" : "Unarchive", action: self.archive)
    }

    private var nextStatus: String? {
        guard let currentIndex = statuses.firstIndex(of: card.status) else {
            return self.statuses.first
        }
        let nextIndex = self.statuses.index(after: currentIndex)
        guard self.statuses.indices.contains(nextIndex) else { return nil }
        return self.statuses[nextIndex]
    }

    private var icon: String {
        switch self.card.status {
        case "running": "figure.run"
        case "review": "checklist"
        case "blocked": "exclamationmark.triangle"
        case "done": "checkmark.circle"
        default: "tray"
        }
    }

    private var color: Color {
        switch self.card.status {
        case "running": OpenClawBrand.ok
        case "review": OpenClawBrand.accent
        case "blocked": OpenClawBrand.warn
        case "done": .secondary
        default: OpenClawBrand.accentHot
        }
    }

    private var detail: String {
        if let notes = card.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return notes
        }
        if let sessionKey = card.sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines), !sessionKey.isEmpty {
            return sessionKey
        }
        return self.card.agentId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? self.card.agentId ?? "Default agent"
            : "Default agent"
    }
}

private struct IPadWorkboardCardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: IPadWorkboardCard
    let statuses: [String]
    let isBusy: Bool
    let canWrite: Bool
    let openSession: () -> Void
    let move: (String) -> Void
    let archive: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    LabeledContent("Title", value: self.card.title)
                    LabeledContent("Status", value: IPadWorkboardDefaults.label(for: self.card.status))
                    if let notes = self.card.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                        Text(notes)
                    }
                }

                Section("Actions") {
                    if self.card.sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Button("Open Session", action: self.openSession)
                    }
                    Menu("Move") {
                        ForEach(self.statuses, id: \.self) { status in
                            Button(IPadWorkboardDefaults.label(for: status)) {
                                self.move(status)
                            }
                        }
                    }
                    .disabled(!self.canWrite || self.isBusy)
                    Button(self.card.metadata?.archivedAt == nil ? "Archive" : "Unarchive", action: self.archive)
                        .disabled(!self.canWrite || self.isBusy)
                }
            }
            .navigationTitle("Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
