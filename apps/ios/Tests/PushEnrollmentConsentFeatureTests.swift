import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct PushEnrollmentConsentFeatureTests {
    @Test func `reducer refreshes disclosure accepted from client`() async {
        let probe = ConsentProbe(disclosureAccepted: true)
        let store = TestStore(initialState: PushEnrollmentConsentFeature.State(disclosureAccepted: false)) {
            PushEnrollmentConsentFeature(consent: probe.client)
        }

        await store.send(.refresh) {
            $0.disclosureAccepted = true
        }
    }

    @Test func `reducer accepts disclosure and persists consent`() async {
        let probe = ConsentProbe(disclosureAccepted: false)
        let store = TestStore(initialState: PushEnrollmentConsentFeature.State(disclosureAccepted: false)) {
            PushEnrollmentConsentFeature(consent: probe.client)
        }

        await store.send(.acceptDisclosure) {
            $0.disclosureAccepted = true
        }

        #expect(probe.markDisclosureAcceptedCount == 1)
    }

    @Test func `reducer reset clears disclosure accepted state`() async {
        let probe = ConsentProbe(disclosureAccepted: true)
        let store = TestStore(initialState: PushEnrollmentConsentFeature.State(disclosureAccepted: true)) {
            PushEnrollmentConsentFeature(consent: probe.client)
        }

        await store.send(.reset) {
            $0.disclosureAccepted = false
        }

        #expect(probe.resetCount == 1)
    }

    @Test func `static consent store supports injected defaults`() throws {
        let suiteName = "PushEnrollmentConsentFeatureTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(!PushEnrollmentConsent.disclosureAccepted(defaults: defaults))
        PushEnrollmentConsent.markDisclosureAccepted(defaults: defaults)
        #expect(PushEnrollmentConsent.disclosureAccepted(defaults: defaults))
    }
}

private final class ConsentProbe: @unchecked Sendable {
    var disclosureAccepted: Bool
    var markDisclosureAcceptedCount = 0
    var resetCount = 0

    init(disclosureAccepted: Bool) {
        self.disclosureAccepted = disclosureAccepted
    }

    var client: PushEnrollmentConsentClient {
        PushEnrollmentConsentClient(
            disclosureAccepted: { self.disclosureAccepted },
            markDisclosureAccepted: {
                self.disclosureAccepted = true
                self.markDisclosureAcceptedCount += 1
            },
            reset: {
                self.disclosureAccepted = false
                self.resetCount += 1
            })
    }
}
