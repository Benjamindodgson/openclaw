import ComposableArchitecture
import SwiftUI
import Testing
@testable import OpenClaw

@MainActor
struct PrivacyAccessFeatureTests {
    @Test func `permission statuses expose presentation color`() {
        #expect(PrivacyAccessStatus.allowed.color == .green)
        #expect(PrivacyAccessStatus.notSet.color == .orange)
        #expect(PrivacyAccessStatus.notAllowed.color == .red)
        #expect(PrivacyAccessStatus.addOnly.color == .yellow)
        #expect(PrivacyAccessStatus.unknown.color == .red)
    }

    @Test func `refresh loads permission snapshot`() async {
        let probe = PrivacyAccessProbe(snapshot: .init(
            contacts: .allowed,
            calendarWrite: .allowed,
            calendarRead: .addOnly,
            reminders: .notAllowed))
        let store = TestStore(initialState: PrivacyAccessFeature.State(snapshot: .init())) {
            PrivacyAccessFeature(client: probe.client)
        }

        await store.send(.appeared)
        await store.receive(.snapshotLoaded(probe.snapshot)) {
            $0.contactsStatus = .allowed
            $0.calendarWriteStatus = .allowed
            $0.calendarReadStatus = .addOnly
            $0.remindersStatus = .notAllowed
        }
    }

    @Test func `contacts request refreshes and applies granted status`() async {
        let probe = PrivacyAccessProbe(
            snapshot: .init(contacts: .notSet),
            contactsGranted: true)
        let store = TestStore(initialState: PrivacyAccessFeature.State(snapshot: .init(contacts: .notSet))) {
            PrivacyAccessFeature(client: probe.client)
        }

        await store.send(.contactsButtonTapped)
        await store.receive(.permissionRequestFinished(.init(
            permission: .contacts,
            granted: true,
            snapshot: probe.snapshot)))
        {
            $0.contactsStatus = .allowed
        }

        #expect(probe.contactsRequestCount == 1)
    }

    @Test func `calendar write grant keeps read status add only`() async {
        let probe = PrivacyAccessProbe(
            snapshot: .init(calendarWrite: .notSet, calendarRead: .notSet),
            calendarWriteGranted: true)
        let store = TestStore(initialState: PrivacyAccessFeature.State(
            snapshot: .init(calendarWrite: .notSet, calendarRead: .notSet)))
        {
            PrivacyAccessFeature(client: probe.client)
        }

        await store.send(.calendarWriteButtonTapped)
        await store.receive(.permissionRequestFinished(.init(
            permission: .calendarWrite,
            granted: true,
            snapshot: probe.snapshot)))
        {
            $0.calendarWriteStatus = .allowed
            $0.calendarReadStatus = .addOnly
        }

        #expect(probe.calendarWriteRequestCount == 1)
    }

    @Test func `calendar read upgrade grants full calendar access`() async {
        let probe = PrivacyAccessProbe(
            snapshot: .init(calendarWrite: .allowed, calendarRead: .addOnly),
            calendarFullGranted: true)
        let store = TestStore(initialState: PrivacyAccessFeature.State(
            snapshot: .init(calendarWrite: .allowed, calendarRead: .addOnly)))
        {
            PrivacyAccessFeature(client: probe.client)
        }

        await store.send(.calendarReadButtonTapped)
        await store.receive(.permissionRequestFinished(.init(
            permission: .calendarRead,
            granted: true,
            snapshot: probe.snapshot)))
        {
            $0.calendarReadStatus = .allowed
        }

        #expect(probe.calendarFullRequestCount == 1)
    }

    @Test func `denied permission opens settings`() async {
        let probe = PrivacyAccessProbe(snapshot: .init(contacts: .notAllowed))
        let store = TestStore(initialState: PrivacyAccessFeature.State(snapshot: .init(contacts: .notAllowed))) {
            PrivacyAccessFeature(client: probe.client)
        }

        await store.send(.contactsButtonTapped)
        await store.finish()

        #expect(probe.openSettingsCount == 1)
    }
}

private final class PrivacyAccessProbe: @unchecked Sendable {
    var snapshot: PrivacyAccessSnapshot
    var contactsGranted: Bool
    var calendarWriteGranted: Bool
    var calendarFullGranted: Bool
    var remindersGranted: Bool
    var contactsRequestCount = 0
    var calendarWriteRequestCount = 0
    var calendarFullRequestCount = 0
    var remindersRequestCount = 0
    var openSettingsCount = 0

    init(
        snapshot: PrivacyAccessSnapshot,
        contactsGranted: Bool = false,
        calendarWriteGranted: Bool = false,
        calendarFullGranted: Bool = false,
        remindersGranted: Bool = false)
    {
        self.snapshot = snapshot
        self.contactsGranted = contactsGranted
        self.calendarWriteGranted = calendarWriteGranted
        self.calendarFullGranted = calendarFullGranted
        self.remindersGranted = remindersGranted
    }

    var client: PrivacyAccessClient {
        PrivacyAccessClient(
            snapshot: { self.snapshot },
            requestContacts: {
                self.contactsRequestCount += 1
                return self.contactsGranted
            },
            requestCalendarWriteOnly: {
                self.calendarWriteRequestCount += 1
                return self.calendarWriteGranted
            },
            requestCalendarFull: {
                self.calendarFullRequestCount += 1
                return self.calendarFullGranted
            },
            requestRemindersFull: {
                self.remindersRequestCount += 1
                return self.remindersGranted
            },
            openSettings: {
                self.openSettingsCount += 1
            })
    }
}
