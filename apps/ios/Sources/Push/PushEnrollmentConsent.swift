import ComposableArchitecture
import Foundation

struct PushEnrollmentConsentClient {
    var disclosureAccepted: @Sendable () -> Bool
    var markDisclosureAccepted: @Sendable () -> Void
    var reset: @Sendable () -> Void
}

extension PushEnrollmentConsentClient: DependencyKey {
    static let liveValue = PushEnrollmentConsentClient(
        disclosureAccepted: { PushEnrollmentConsent.disclosureAccepted },
        markDisclosureAccepted: { PushEnrollmentConsent.markDisclosureAccepted() },
        reset: { PushEnrollmentConsent.resetIfAvailable() })

    static let testValue = PushEnrollmentConsentClient(
        disclosureAccepted: { false },
        markDisclosureAccepted: {},
        reset: {})
}

extension DependencyValues {
    var pushEnrollmentConsent: PushEnrollmentConsentClient {
        get { self[PushEnrollmentConsentClient.self] }
        set { self[PushEnrollmentConsentClient.self] = newValue }
    }
}

@Reducer
struct PushEnrollmentConsentFeature {
    private let consentOverride: PushEnrollmentConsentClient?

    init(consent: PushEnrollmentConsentClient? = nil) {
        self.consentOverride = consent
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var disclosureAccepted: Bool

        init(disclosureAccepted: Bool = PushEnrollmentConsent.disclosureAccepted) {
            self.disclosureAccepted = disclosureAccepted
        }
    }

    enum Action: Equatable, Sendable {
        case refresh
        case acceptDisclosure
        case reset
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.pushEnrollmentConsent) var dependencyConsent
            let consent = self.consentOverride ?? dependencyConsent

            switch action {
            case .refresh:
                state.disclosureAccepted = consent.disclosureAccepted()
                return .none

            case .acceptDisclosure:
                consent.markDisclosureAccepted()
                state.disclosureAccepted = true
                return .none

            case .reset:
                consent.reset()
                state.disclosureAccepted = false
                return .none
            }
        }
        .autoLogActions()
    }
}

enum PushEnrollmentConsent {
    static let disclosureAcceptedKey = "push.enrollment.disclosureAccepted"

    static var disclosureAccepted: Bool {
        self.disclosureAccepted(defaults: .standard)
    }

    static func disclosureAccepted(defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: self.disclosureAcceptedKey)
    }

    static func markDisclosureAccepted() {
        self.markDisclosureAccepted(defaults: .standard)
    }

    static func markDisclosureAccepted(defaults: UserDefaults) {
        defaults.set(true, forKey: self.disclosureAcceptedKey)
    }

    #if DEBUG
    static func reset() {
        self.reset(defaults: .standard)
    }

    static func reset(defaults: UserDefaults) {
        defaults.removeObject(forKey: self.disclosureAcceptedKey)
    }
    #endif

    static func resetIfAvailable() {
        #if DEBUG
        self.reset()
        #endif
    }
}
