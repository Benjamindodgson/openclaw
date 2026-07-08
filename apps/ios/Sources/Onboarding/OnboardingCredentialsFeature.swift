import ComposableArchitecture
import Foundation
import OpenClawKit

@Reducer
struct OnboardingCredentialsFeature {
    private let credentialsPersistenceClientOverride: OnboardingGatewayCredentialsPersistenceClient?
    private let setupAuthPersistenceClientOverride: OnboardingGatewaySetupAuthPersistenceClient?

    init(
        credentialsPersistenceClient: OnboardingGatewayCredentialsPersistenceClient? = nil,
        setupAuthPersistenceClient: OnboardingGatewaySetupAuthPersistenceClient? = nil)
    {
        self.credentialsPersistenceClientOverride = credentialsPersistenceClient
        self.setupAuthPersistenceClientOverride = setupAuthPersistenceClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayPasswordState = OnboardingGatewayPassword(value: "")
        var gatewayTokenState = OnboardingGatewayToken(value: "")
        var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?
        var setupAuthPersistenceRequest: OnboardingGatewaySetupAuthPersistenceRequest?

        var gatewayPassword: String {
            self.gatewayPasswordState.value
        }

        var gatewayToken: String {
            self.gatewayTokenState.value
        }

        var hasGatewayPassword: Bool {
            !self.gatewayPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var hasGatewayToken: Bool {
            !self.gatewayToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: Equatable, Sendable {
        struct CredentialsLoadRequest: Equatable, Sendable {
            var instanceId: OnboardingGatewayCurrentInstanceID
        }

        struct LoadedCredentials: Equatable, Sendable {
            var token: OnboardingGatewayToken
            var password: OnboardingGatewayPassword
        }

        struct GatewayPasswordChange: Equatable, Sendable { var password: OnboardingGatewayPassword }
        struct GatewayTokenChange: Equatable, Sendable { var token: OnboardingGatewayToken }
        struct ManualCredentialPersistenceRequest: Equatable, Sendable {
            var value: OnboardingGatewayCredentialValue
            var instanceId: OnboardingGatewayCurrentInstanceID
        }

        struct SetupAuthApplication: Equatable, Sendable {
            var setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth
        }

        struct SetupLinkApplication: Equatable, Sendable { var link: GatewayConnectDeepLink }

        case credentialsLoadRequested(CredentialsLoadRequest)
        case credentialsLoaded(LoadedCredentials)
        case gatewayPasswordChanged(GatewayPasswordChange)
        case gatewayPasswordInputChanged(OnboardingManualCredentialInputChange)
        case gatewayPasswordPersistenceRequested(ManualCredentialPersistenceRequest)
        case gatewayTokenChanged(GatewayTokenChange)
        case gatewayTokenInputChanged(OnboardingManualCredentialInputChange)
        case gatewayTokenPersistenceRequested(ManualCredentialPersistenceRequest)
        case pendingManualAuthOverrideConsumed
        case reset
        case setupAuthApplied(SetupAuthApplication)
        case setupAuthPersistenceRequested(OnboardingGatewaySetupAuthPersistenceRequest)
        case setupAuthPersistenceRequestHandled
        case setupLinkApplied(SetupLinkApplication)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingGatewayCredentialsPersistence) var dependencyCredentialsPersistenceClient
            @Dependency(\.onboardingGatewaySetupAuthPersistence) var dependencySetupAuthPersistenceClient
            let credentialsPersistenceClient = self.credentialsPersistenceClientOverride
                ?? dependencyCredentialsPersistenceClient
            let setupAuthPersistenceClient = self.setupAuthPersistenceClientOverride
                ?? dependencySetupAuthPersistenceClient

            switch action {
            case let .credentialsLoadRequested(request):
                guard request.instanceId.trimmedValue != nil else { return .none }
                let credentials = credentialsPersistenceClient.loadCredentials(request.instanceId)
                state.gatewayTokenState = .init(value: credentials.token)
                state.gatewayPasswordState = .init(value: credentials.password)
                return .none

            case let .credentialsLoaded(credentials):
                state.gatewayTokenState = credentials.token
                state.gatewayPasswordState = credentials.password
                return .none

            case let .gatewayPasswordChanged(change):
                state.gatewayPasswordState = change.password
                return .none

            case let .gatewayPasswordInputChanged(change):
                state.gatewayPasswordState = .init(value: change.value.value)
                return .send(.gatewayPasswordPersistenceRequested(.init(
                    value: .init(rawValue: change.value.value),
                    instanceId: change.instanceId)))

            case let .gatewayPasswordPersistenceRequested(persistence):
                guard let request = Self.manualCredentialPersistenceRequest(
                    value: persistence.value,
                    instanceId: persistence.instanceId)
                else { return .none }
                return .run { _ in
                    await credentialsPersistenceClient.saveGatewayPassword(request.value, request.instanceId)
                }

            case let .gatewayTokenChanged(change):
                state.gatewayTokenState = change.token
                return .none

            case let .gatewayTokenInputChanged(change):
                state.gatewayTokenState = .init(value: change.value.value)
                return .send(.gatewayTokenPersistenceRequested(.init(
                    value: .init(rawValue: change.value.value),
                    instanceId: change.instanceId)))

            case let .gatewayTokenPersistenceRequested(persistence):
                guard let request = Self.manualCredentialPersistenceRequest(
                    value: persistence.value,
                    instanceId: persistence.instanceId)
                else { return .none }
                return .run { _ in
                    await credentialsPersistenceClient.saveGatewayToken(request.value, request.instanceId)
                }

            case .pendingManualAuthOverrideConsumed:
                state.pendingManualAuthOverride = nil
                return .none

            case .reset:
                state.gatewayTokenState = .init(value: "")
                state.gatewayPasswordState = .init(value: "")
                state.pendingManualAuthOverride = nil
                state.setupAuthPersistenceRequest = nil
                return .none

            case let .setupAuthApplied(application):
                Self.applySetupAuth(application.setupAuth, to: &state)
                return .none

            case let .setupAuthPersistenceRequested(request):
                guard request.trimmedInstanceId != nil else { return .none }
                return .run { _ in
                    if request.hasBootstrapToken {
                        await setupAuthPersistenceClient.prepareForBootstrapPairing(request.instanceId)
                    }
                    await setupAuthPersistenceClient.saveSetupAuth(request)
                }

            case .setupAuthPersistenceRequestHandled:
                state.setupAuthPersistenceRequest = nil
                return .none

            case let .setupLinkApplied(application):
                let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: application.link)
                Self.applySetupAuth(setupAuth, to: &state)
                state.setupAuthPersistenceRequest = OnboardingGatewaySetupAuthPersistenceRequest(
                    setupAuth: setupAuth,
                    instanceId: setupAuthPersistenceClient.currentInstanceID())
                return .none
            }
        }
        .autoLogActions()
    }

    private static func manualCredentialPersistenceRequest(
        value: OnboardingGatewayCredentialValue,
        instanceId: OnboardingGatewayCurrentInstanceID)
        -> Action.ManualCredentialPersistenceRequest?
    {
        guard instanceId.trimmedValue != nil else { return nil }
        return .init(value: value, instanceId: instanceId)
    }

    private static func applySetupAuth(
        _ setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth,
        to state: inout State)
    {
        if setupAuth.shouldApplyTokenField {
            state.gatewayTokenState = .init(value: setupAuth.token)
        }
        if setupAuth.shouldApplyPasswordField {
            state.gatewayPasswordState = .init(value: setupAuth.password)
        }
        state.pendingManualAuthOverride = setupAuth.manualAuthOverride
    }
}
