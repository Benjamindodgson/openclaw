import ComposableArchitecture
import Contacts
import EventKit
import SwiftUI
import UIKit

struct PrivacyAccessClient {
    var snapshot: @Sendable () -> PrivacyAccessSnapshot
    var requestContacts: @Sendable () async -> Bool
    var requestCalendarWriteOnly: @Sendable () async -> Bool
    var requestCalendarFull: @Sendable () async -> Bool
    var requestRemindersFull: @Sendable () async -> Bool
    var openSettings: @Sendable () async -> Void
}

extension PrivacyAccessClient: DependencyKey {
    static let liveValue = PrivacyAccessClient(
        snapshot: { PrivacyAccessSnapshot.current() },
        requestContacts: {
            await PermissionRequestBridge.awaitRequest { completion in
                let store = CNContactStore()
                store.requestAccess(for: .contacts) { granted, _ in
                    completion(granted)
                }
            }
        },
        requestCalendarWriteOnly: {
            await PermissionRequestBridge.awaitRequest { completion in
                let store = EKEventStore()
                store.requestWriteOnlyAccessToEvents { granted, _ in
                    completion(granted)
                }
            }
        },
        requestCalendarFull: {
            await PermissionRequestBridge.awaitRequest { completion in
                let store = EKEventStore()
                store.requestFullAccessToEvents { granted, _ in
                    completion(granted)
                }
            }
        },
        requestRemindersFull: {
            await PermissionRequestBridge.awaitRequest { completion in
                let store = EKEventStore()
                store.requestFullAccessToReminders { granted, _ in
                    completion(granted)
                }
            }
        },
        openSettings: {
            await MainActor.run {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        })

    static let testValue = PrivacyAccessClient(
        snapshot: { PrivacyAccessSnapshot() },
        requestContacts: { false },
        requestCalendarWriteOnly: { false },
        requestCalendarFull: { false },
        requestRemindersFull: { false },
        openSettings: {})
}

extension DependencyValues {
    var privacyAccess: PrivacyAccessClient {
        get { self[PrivacyAccessClient.self] }
        set { self[PrivacyAccessClient.self] = newValue }
    }
}

struct PrivacyAccessSnapshot: Equatable {
    var contacts: PrivacyAccessStatus
    var calendarWrite: PrivacyAccessStatus
    var calendarRead: PrivacyAccessStatus
    var reminders: PrivacyAccessStatus

    init(
        contacts: PrivacyAccessStatus = .notSet,
        calendarWrite: PrivacyAccessStatus = .notSet,
        calendarRead: PrivacyAccessStatus = .notSet,
        reminders: PrivacyAccessStatus = .notSet)
    {
        self.contacts = contacts
        self.calendarWrite = calendarWrite
        self.calendarRead = calendarRead
        self.reminders = reminders
    }

    static func current() -> Self {
        self.init(
            contacts: .contacts(CNContactStore.authorizationStatus(for: .contacts)),
            calendarWrite: .calendarWrite(EKEventStore.authorizationStatus(for: .event)),
            calendarRead: .calendarRead(EKEventStore.authorizationStatus(for: .event)),
            reminders: .reminders(EKEventStore.authorizationStatus(for: .reminder)))
    }
}

enum PrivacyAccessStatus: Equatable {
    case allowed
    case notSet
    case notAllowed
    case addOnly
    case unknown

    var text: String {
        switch self {
        case .allowed:
            "Allowed"
        case .notSet:
            "Not Set"
        case .notAllowed:
            "Not Allowed"
        case .addOnly:
            "Add-Only"
        case .unknown:
            "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .allowed:
            .green
        case .notSet:
            .orange
        case .addOnly:
            .yellow
        case .notAllowed, .unknown:
            .red
        }
    }

    static func contacts(_ status: CNAuthorizationStatus) -> Self {
        switch status {
        case .authorized, .limited:
            .allowed
        case .notDetermined:
            .notSet
        case .denied, .restricted:
            .notAllowed
        @unknown default:
            .unknown
        }
    }

    static func calendarWrite(_ status: EKAuthorizationStatus) -> Self {
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            .allowed
        case .notDetermined:
            .notSet
        case .denied, .restricted:
            .notAllowed
        @unknown default:
            .unknown
        }
    }

    static func calendarRead(_ status: EKAuthorizationStatus) -> Self {
        switch status {
        case .authorized, .fullAccess:
            .allowed
        case .writeOnly:
            .addOnly
        case .notDetermined:
            .notSet
        case .denied, .restricted:
            .notAllowed
        @unknown default:
            .unknown
        }
    }

    static func reminders(_ status: EKAuthorizationStatus) -> Self {
        switch status {
        case .authorized, .fullAccess:
            .allowed
        case .writeOnly:
            .addOnly
        case .notDetermined:
            .notSet
        case .denied, .restricted:
            .notAllowed
        @unknown default:
            .unknown
        }
    }
}

enum PrivacyAccessPermission: Equatable {
    case contacts
    case calendarWrite
    case calendarRead
    case reminders
}

@Reducer
struct PrivacyAccessFeature {
    private let clientOverride: PrivacyAccessClient?

    init(client: PrivacyAccessClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var contactsStatus: PrivacyAccessStatus
        var calendarWriteStatus: PrivacyAccessStatus
        var calendarReadStatus: PrivacyAccessStatus
        var remindersStatus: PrivacyAccessStatus

        init(snapshot: PrivacyAccessSnapshot = .current()) {
            self.contactsStatus = snapshot.contacts
            self.calendarWriteStatus = snapshot.calendarWrite
            self.calendarReadStatus = snapshot.calendarRead
            self.remindersStatus = snapshot.reminders
        }

        var contactsActionTitle: String? {
            Self.requestOrSettingsActionTitle(for: self.contactsStatus, requestTitle: "Request Access")
        }

        var calendarWriteActionTitle: String? {
            Self.requestOrSettingsActionTitle(for: self.calendarWriteStatus, requestTitle: "Request Access")
        }

        var calendarReadActionTitle: String? {
            switch self.calendarReadStatus {
            case .notSet:
                "Request Full Access"
            case .addOnly:
                "Upgrade to Full Access"
            case .notAllowed:
                "Open Settings"
            case .allowed, .unknown:
                nil
            }
        }

        var remindersActionTitle: String? {
            switch self.remindersStatus {
            case .notSet:
                "Request Access"
            case .addOnly:
                "Upgrade to Full Access"
            case .notAllowed:
                "Open Settings"
            case .allowed, .unknown:
                nil
            }
        }

        private static func requestOrSettingsActionTitle(
            for status: PrivacyAccessStatus,
            requestTitle: String) -> String?
        {
            switch status {
            case .notSet:
                requestTitle
            case .notAllowed:
                "Open Settings"
            case .allowed, .addOnly, .unknown:
                nil
            }
        }
    }

    enum Action: Equatable, Sendable {
        struct PermissionRequestCompletion: Equatable, Sendable {
            var permission: PrivacyAccessPermission
            var granted: Bool
            var snapshot: PrivacyAccessSnapshot
        }

        case appeared
        case sceneBecameActive
        case contactsButtonTapped
        case calendarWriteButtonTapped
        case calendarReadButtonTapped
        case remindersButtonTapped
        case snapshotLoaded(PrivacyAccessSnapshot)
        case permissionRequestFinished(PermissionRequestCompletion)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.privacyAccess) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case .appeared, .sceneBecameActive:
                return self.refresh(client: client)

            case .contactsButtonTapped:
                switch state.contactsStatus {
                case .notSet:
                    return self.request(.contacts, client: client)
                case .notAllowed:
                    return self.openSettings(client: client)
                case .allowed, .addOnly, .unknown:
                    return .none
                }

            case .calendarWriteButtonTapped:
                switch state.calendarWriteStatus {
                case .notSet:
                    return self.request(.calendarWrite, client: client)
                case .notAllowed:
                    return self.openSettings(client: client)
                case .allowed, .addOnly, .unknown:
                    return .none
                }

            case .calendarReadButtonTapped:
                switch state.calendarReadStatus {
                case .notSet, .addOnly:
                    return self.request(.calendarRead, client: client)
                case .notAllowed:
                    return self.openSettings(client: client)
                case .allowed, .unknown:
                    return .none
                }

            case .remindersButtonTapped:
                switch state.remindersStatus {
                case .notSet, .addOnly:
                    return self.request(.reminders, client: client)
                case .notAllowed:
                    return self.openSettings(client: client)
                case .allowed, .unknown:
                    return .none
                }

            case let .snapshotLoaded(snapshot):
                state.apply(snapshot)
                return .none

            case let .permissionRequestFinished(completion):
                state.apply(completion.snapshot)
                if completion.granted {
                    state.applyGranted(completion.permission)
                }
                return .none
            }
        }
        .autoLogActions()
    }

    private func refresh(client: PrivacyAccessClient) -> Effect<Action> {
        .run { send in
            await send(.snapshotLoaded(client.snapshot()))
        }
    }

    private func request(_ permission: PrivacyAccessPermission, client: PrivacyAccessClient) -> Effect<Action> {
        .run { send in
            let granted: Bool = switch permission {
            case .contacts:
                await client.requestContacts()
            case .calendarWrite:
                await client.requestCalendarWriteOnly()
            case .calendarRead:
                await client.requestCalendarFull()
            case .reminders:
                await client.requestRemindersFull()
            }
            await send(.permissionRequestFinished(.init(
                permission: permission,
                granted: granted,
                snapshot: client.snapshot())))
        }
    }

    private func openSettings(client: PrivacyAccessClient) -> Effect<Action> {
        .run { _ in
            await client.openSettings()
        }
    }
}

extension PrivacyAccessFeature.State {
    fileprivate mutating func apply(_ snapshot: PrivacyAccessSnapshot) {
        self.contactsStatus = snapshot.contacts
        self.calendarWriteStatus = snapshot.calendarWrite
        self.calendarReadStatus = snapshot.calendarRead
        self.remindersStatus = snapshot.reminders
    }

    fileprivate mutating func applyGranted(_ permission: PrivacyAccessPermission) {
        switch permission {
        case .contacts:
            self.contactsStatus = .allowed
        case .calendarWrite:
            self.calendarWriteStatus = .allowed
            self.calendarReadStatus = .addOnly
        case .calendarRead:
            self.calendarWriteStatus = .allowed
            self.calendarReadStatus = .allowed
        case .reminders:
            self.remindersStatus = .allowed
        }
    }
}

struct PrivacyAccessSectionView: View {
    @State private var store: StoreOf<PrivacyAccessFeature>
    @Environment(\.scenePhase) private var scenePhase

    init(store: StoreOf<PrivacyAccessFeature> = Store(initialState: PrivacyAccessFeature.State()) {
        PrivacyAccessFeature()
    }) {
        self._store = SwiftUI.State(wrappedValue: store)
    }

    var body: some View {
        DisclosureGroup("Privacy & Access") {
            self.permissionRow(
                title: "Contacts",
                icon: "person.crop.circle",
                status: self.store.contactsStatus,
                detail: "Search and add contacts from the assistant.",
                actionTitle: self.store.contactsActionTitle,
                action: { self.store.send(.contactsButtonTapped) })

            self.permissionRow(
                title: "Calendar (Add Events)",
                icon: "calendar.badge.plus",
                status: self.store.calendarWriteStatus,
                detail: "Add events with least privilege.",
                actionTitle: self.store.calendarWriteActionTitle,
                action: { self.store.send(.calendarWriteButtonTapped) })

            self.permissionRow(
                title: "Calendar (View Events)",
                icon: "calendar",
                status: self.store.calendarReadStatus,
                detail: "List and read calendar events.",
                actionTitle: self.store.calendarReadActionTitle,
                action: { self.store.send(.calendarReadButtonTapped) })

            self.permissionRow(
                title: "Reminders",
                icon: "checklist",
                status: self.store.remindersStatus,
                detail: "List, add, and complete reminders.",
                actionTitle: self.store.remindersActionTitle,
                action: { self.store.send(.remindersButtonTapped) })
        }
        .onAppear {
            self.store.send(.appeared)
        }
        .onChange(of: self.scenePhase) { _, phase in
            if phase == .active {
                self.store.send(.sceneBecameActive)
            }
        }
    }

    private func permissionRow(
        title: String,
        icon: String,
        status: PrivacyAccessStatus,
        detail: String,
        actionTitle: String?,
        action: @escaping () -> Void) -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(status.text)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(status.color)
            }
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.footnote)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }
}
