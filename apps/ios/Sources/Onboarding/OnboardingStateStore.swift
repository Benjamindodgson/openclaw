import ComposableArchitecture
import Foundation
import OpenClawKit

enum OnboardingStep: Int, CaseIterable {
    case intro
    case welcome
    case mode
    case connect
    case auth
    case success

    var previous: Self? {
        Self(rawValue: self.rawValue - 1)
    }

    /// Progress label for the manual setup flow (mode -> connect -> auth -> success).
    var manualProgressTitle: String {
        let manualSteps: [OnboardingStep] = [.mode, .connect, .auth, .success]
        guard let idx = manualSteps.firstIndex(of: self) else { return "" }
        return "Step \(idx + 1) of \(manualSteps.count)"
    }

    var title: String {
        switch self {
        case .intro: "Welcome"
        case .welcome: "Connect Gateway"
        case .mode: "Connection Mode"
        case .connect: "Connect"
        case .auth: "Authentication"
        case .success: "Connected"
        }
    }

    var canGoBack: Bool {
        self != .intro && self != .welcome && self != .success
    }
}

enum OnboardingConnectionMode: String, CaseIterable {
    case homeNetwork = "home_network"
    case remoteDomain = "remote_domain"
    case developerLocal = "developer_local"

    var title: String {
        switch self {
        case .homeNetwork:
            "Home Network"
        case .remoteDomain:
            "Remote Domain"
        case .developerLocal:
            "Same Machine (Dev)"
        }
    }
}

// swiftformat:disable redundantSendable
struct OnboardingConnectionID: Equatable, Sendable { var value: String }

struct OnboardingConnectionMessage: Equatable, Sendable { var value: String }

struct OnboardingConnectionStatusLine: Equatable, Sendable { var value: String }

struct OnboardingConnectionStatusMessage: Equatable, Sendable { var value: String? }

struct OnboardingConnectionIssueMessage: Equatable, Sendable { var value: String? }

struct OnboardingConnectionIssueRequestID: Equatable, Sendable { var value: String? }

struct OnboardingConnectionIssueStatusText: Equatable, Sendable { var value: String }

struct OnboardingConnectionPauseReconnect: Equatable, Sendable { var value: Bool }

struct OnboardingConnectionClearsIssue: Equatable, Sendable { var value: Bool }

struct OnboardingRetryConnectionSilence: Equatable, Sendable { var value: Bool }

struct OnboardingGatewayMarkedCompleted: Equatable, Sendable { var value: Bool }

struct OnboardingAutomaticPairingResume: Equatable, Sendable { var shouldResume: Bool }

struct OnboardingAuthStepPresentation: Equatable, Sendable { var shouldShow: Bool }

struct OnboardingPairingResumeRequestTime: Equatable, Sendable { var value: Date }

struct OnboardingCompletion: Equatable, Sendable { var isCompleted: Bool }

struct OnboardingFirstRunIntroSeen: Equatable, Sendable { var value: Bool }

struct OnboardingGatewayServerName: Equatable, Sendable { var value: String? }

struct OnboardingHasSavedGatewayConnection: Equatable, Sendable { var value: Bool }

struct OnboardingLaunchPresentation: Equatable, Sendable { var shouldPresent: Bool }

struct OnboardingFirstRunIntroPresentation: Equatable, Sendable { var shouldPresent: Bool }

struct OnboardingGatewayToken: Equatable, Sendable { var value: String }

struct OnboardingGatewayPassword: Equatable, Sendable { var value: String }

struct OnboardingGatewayCredentialInput: Equatable, Sendable { var value: String }

struct OnboardingManualCredentialInputChange: Equatable, Sendable {
    var value: OnboardingGatewayCredentialInput
    var instanceId: OnboardingGatewayCurrentInstanceID
}

struct OnboardingGatewayStoredCredentials: Equatable, Sendable {
    var token: String
    var password: String
}

struct OnboardingGatewayCredentialValue: Equatable, Sendable {
    var value: String

    init(rawValue: String) {
        self.value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct OnboardingGatewayCurrentInstanceID: Equatable, Sendable {
    var value: String

    var trimmedValue: String? {
        let trimmed = self.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct OnboardingResetClient {
    var reset: @MainActor @Sendable (_ instanceId: OnboardingGatewayCurrentInstanceID) -> Void
}

extension OnboardingResetClient: DependencyKey {
    static let liveValue = OnboardingResetClient(reset: { _ in })
    static let testValue = OnboardingResetClient(reset: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        OnboardingResetClient(reset: { instanceId in
            GatewayOnboardingReset.reset(appModel: appModel, instanceId: instanceId.value)
        })
    }
}

extension DependencyValues {
    var onboardingReset: OnboardingResetClient {
        get { self[OnboardingResetClient.self] }
        set { self[OnboardingResetClient.self] = newValue }
    }
}

struct OnboardingProgressPersistenceClient {
    var markCompleted: @MainActor @Sendable (_ mode: OnboardingConnectionMode?) -> Void
    var markFirstRunIntroSeen: @MainActor @Sendable () -> Void
}

extension OnboardingProgressPersistenceClient: DependencyKey {
    static let liveValue = OnboardingProgressPersistenceClient(
        markCompleted: { mode in
            OnboardingStateStore.markCompleted(mode: mode)
        },
        markFirstRunIntroSeen: {
            OnboardingStateStore.markFirstRunIntroSeen()
        })

    static let testValue = OnboardingProgressPersistenceClient(
        markCompleted: { _ in },
        markFirstRunIntroSeen: {})
}

extension DependencyValues {
    var onboardingProgressPersistence: OnboardingProgressPersistenceClient {
        get { self[OnboardingProgressPersistenceClient.self] }
        set { self[OnboardingProgressPersistenceClient.self] = newValue }
    }
}

struct OnboardingQRMessage: Equatable, Sendable { var value: String? }

struct OnboardingQRPhotoImportFailureMessage: Equatable, Sendable { var value: String }

struct OnboardingSetupCode: Equatable, Sendable { var value: String }

struct OnboardingSetupCodeStatusMessage: Equatable, Sendable { var value: String? }

struct OnboardingDiscoveryRestartRequestID: Equatable, Sendable { var value: Int }

struct OnboardingDiscoveredGatewayName: Equatable, Sendable { var value: String }

struct OnboardingDiscoveredGatewayHost: Equatable, Sendable {
    var value: String?

    var trimmedValue: String? {
        let trimmed = self.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct OnboardingManualHost: Equatable, Sendable { var value: String }

struct OnboardingManualPort: Equatable, Sendable { var value: Int }

struct OnboardingManualPortText: Equatable, Sendable { var value: String }

struct OnboardingManualTLS: Equatable, Sendable { var value: Bool }

struct OnboardingScannerErrorMessage: Equatable, Sendable { var value: String }

struct OnboardingConnectionFormDefaults: Equatable, Sendable {
    var host: OnboardingManualHost
    var port: OnboardingManualPort
    var tls: OnboardingManualTLS
    var lastMode: OnboardingConnectionMode?
    var hasSavedGatewayConnection: OnboardingHasSavedGatewayConnection
}

// swiftformat:enable redundantSendable

struct OnboardingConnectionFormDefaultsClient {
    var loadDefaults: @Sendable () -> OnboardingConnectionFormDefaults
}

extension OnboardingConnectionFormDefaultsClient: DependencyKey {
    static let liveValue = OnboardingConnectionFormDefaultsClient(loadDefaults: {
        let lastGatewayConnection = GatewaySettingsStore.loadLastGatewayConnection()
        var initialConnection: (host: String, port: Int, tls: Bool) = ("openclaw.local", 18789, true)
        if let lastGatewayConnection {
            switch lastGatewayConnection {
            case let .manual(host, port, useTLS, _):
                initialConnection = (host, port, useTLS)
            case .discovered:
                break
            }
        }
        return .init(
            host: .init(value: initialConnection.host),
            port: .init(value: initialConnection.port),
            tls: .init(value: initialConnection.tls),
            lastMode: OnboardingStateStore.lastMode(),
            hasSavedGatewayConnection: .init(value: lastGatewayConnection != nil))
    })

    static let testValue = OnboardingConnectionFormDefaultsClient(loadDefaults: {
        .init(
            host: .init(value: "openclaw.local"),
            port: .init(value: 18789),
            tls: .init(value: true),
            lastMode: nil,
            hasSavedGatewayConnection: .init(value: false))
    })
}

extension DependencyValues {
    var onboardingConnectionFormDefaults: OnboardingConnectionFormDefaultsClient {
        get { self[OnboardingConnectionFormDefaultsClient.self] }
        set { self[OnboardingConnectionFormDefaultsClient.self] = newValue }
    }
}

@Reducer
struct OnboardingStateFeature {
    private let progressPersistenceClientOverride: OnboardingProgressPersistenceClient?
    private let resetClientOverride: OnboardingResetClient?

    init(
        progressPersistenceClient: OnboardingProgressPersistenceClient? = nil,
        resetClient: OnboardingResetClient? = nil)
    {
        self.progressPersistenceClientOverride = progressPersistenceClient
        self.resetClientOverride = resetClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var completion: OnboardingCompletion
        var firstRunIntroSeenState: OnboardingFirstRunIntroSeen
        var lastMode: OnboardingConnectionMode?
        var savedGatewayConnection: OnboardingHasSavedGatewayConnection
        var gatewayServerNameState: OnboardingGatewayServerName
        var launchPresentation: OnboardingLaunchPresentation
        var firstRunIntroPresentation: OnboardingFirstRunIntroPresentation

        init(
            isCompleted: Bool = false,
            firstRunIntroSeen: Bool = false,
            lastMode: OnboardingConnectionMode? = nil,
            hasSavedGatewayConnection: Bool = false,
            gatewayServerName: String? = nil)
        {
            self.completion = .init(isCompleted: isCompleted)
            self.firstRunIntroSeenState = .init(value: firstRunIntroSeen)
            self.lastMode = lastMode
            self.savedGatewayConnection = .init(value: hasSavedGatewayConnection)
            self.gatewayServerNameState = .init(value: gatewayServerName)
            self.launchPresentation = .init(shouldPresent: false)
            self.firstRunIntroPresentation = .init(shouldPresent: true)
            self.refreshPresentation()
        }

        var gatewayServerName: String? {
            self.gatewayServerNameState.value
        }

        var shouldPresentOnLaunch: Bool {
            self.launchPresentation.shouldPresent
        }

        var shouldPresentFirstRunIntro: Bool {
            self.firstRunIntroPresentation.shouldPresent
        }

        mutating func refreshPresentation() {
            self.launchPresentation = .init(shouldPresent:
                !self.completion.isCompleted &&
                    !self.savedGatewayConnection.value &&
                    self.gatewayServerName == nil)
            self.firstRunIntroPresentation = .init(shouldPresent: !self.firstRunIntroSeenState.value)
        }
    }

    enum Action: Equatable, Sendable {
        struct GatewaySnapshotChange: Equatable, Sendable {
            var gatewayServerName: OnboardingGatewayServerName
            var hasSavedGatewayConnection: OnboardingHasSavedGatewayConnection
        }

        struct CompletionMark: Equatable, Sendable { var mode: OnboardingConnectionMode? }

        struct OnboardingResetRequest: Equatable, Sendable { var instanceId: OnboardingGatewayCurrentInstanceID }

        case refreshPresentation
        case gatewaySnapshotChanged(GatewaySnapshotChange)
        case markCompleted(CompletionMark)
        case markFirstRunIntroSeen
        case onboardingResetRequested(OnboardingResetRequest)
        case reset
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingProgressPersistence) var dependencyProgressPersistenceClient
            @Dependency(\.onboardingReset) var dependencyResetClient
            let progressPersistenceClient = self.progressPersistenceClientOverride
                ?? dependencyProgressPersistenceClient
            let resetClient = self.resetClientOverride ?? dependencyResetClient

            switch action {
            case .refreshPresentation:
                state.refreshPresentation()
                return .none

            case let .gatewaySnapshotChanged(snapshot):
                state.gatewayServerNameState = snapshot.gatewayServerName
                state.savedGatewayConnection = snapshot.hasSavedGatewayConnection
                state.refreshPresentation()
                return .none

            case let .markCompleted(mark):
                state.completion = .init(isCompleted: true)
                if let mode = mark.mode {
                    state.lastMode = mode
                }
                state.refreshPresentation()
                return .run { _ in
                    await progressPersistenceClient.markCompleted(mark.mode)
                }

            case .markFirstRunIntroSeen:
                state.firstRunIntroSeenState = .init(value: true)
                state.refreshPresentation()
                return .run { _ in
                    await progressPersistenceClient.markFirstRunIntroSeen()
                }

            case let .onboardingResetRequested(request):
                Self.resetState(&state)
                return .run { _ in
                    await resetClient.reset(request.instanceId)
                }

            case .reset:
                Self.resetState(&state)
                return .none
            }
        }
        .autoLogActions()
    }

    private static func resetState(_ state: inout State) {
        state.completion = .init(isCompleted: false)
        state.firstRunIntroSeenState = .init(value: false)
        state.refreshPresentation()
    }
}

@Reducer
struct OnboardingStepFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var step: OnboardingStep

        init(step: OnboardingStep = .welcome) {
            self.step = step
        }

        var isFullScreenStep: Bool {
            self.step == .intro || self.step == .welcome || self.step == .success
        }
    }

    enum Action: Equatable, Sendable {
        struct StepChange: Equatable, Sendable { var step: OnboardingStep }

        case backButtonTapped
        case stepChanged(StepChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                guard state.step.canGoBack, let previous = state.step.previous else { return .none }
                state.step = previous
                return .none

            case let .stepChanged(change):
                state.step = change.step
                return .none
            }
        }
        .autoLogActions()
    }
}

struct OnboardingGatewaySetupAuthPersistenceRequest: Equatable {
    let setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth
    let instanceId: OnboardingGatewayCurrentInstanceID

    var hasBootstrapToken: Bool {
        self.setupAuth.hasBootstrapToken
    }

    var trimmedInstanceId: String? {
        self.instanceId.trimmedValue
    }
}

struct OnboardingGatewaySetupAuthPersistenceClient {
    var currentInstanceID: @Sendable () -> OnboardingGatewayCurrentInstanceID
    var prepareForBootstrapPairing: @MainActor @Sendable (_ instanceId: OnboardingGatewayCurrentInstanceID) -> Void
    var saveSetupAuth: @MainActor @Sendable (_ request: OnboardingGatewaySetupAuthPersistenceRequest) -> Void

    init(
        currentInstanceID: @escaping @Sendable () -> OnboardingGatewayCurrentInstanceID,
        prepareForBootstrapPairing: @escaping @MainActor @Sendable (
            _ instanceId: OnboardingGatewayCurrentInstanceID) -> Void = { _ in },
        saveSetupAuth: @escaping @MainActor @Sendable (_ request: OnboardingGatewaySetupAuthPersistenceRequest) -> Void)
    {
        self.currentInstanceID = currentInstanceID
        self.prepareForBootstrapPairing = prepareForBootstrapPairing
        self.saveSetupAuth = saveSetupAuth
    }
}

extension OnboardingGatewaySetupAuthPersistenceClient: DependencyKey {
    static let liveValue = OnboardingGatewaySetupAuthPersistenceClient(
        currentInstanceID: {
            .init(value: GatewaySettingsStore.currentInstanceID())
        },
        saveSetupAuth: { request in
            guard let instanceId = request.trimmedInstanceId else { return }

            let bootstrapToken = request.setupAuth.bootstrapToken.trimmingCharacters(in: .whitespacesAndNewlines)
            GatewaySettingsStore.saveGatewayBootstrapToken(bootstrapToken, instanceId: instanceId)
            if request.setupAuth.shouldApplyTokenField {
                let token = request.setupAuth.token.trimmingCharacters(in: .whitespacesAndNewlines)
                GatewaySettingsStore.saveGatewayToken(token, instanceId: instanceId)
            }
            if request.setupAuth.shouldApplyPasswordField {
                let password = request.setupAuth.password.trimmingCharacters(in: .whitespacesAndNewlines)
                GatewaySettingsStore.saveGatewayPassword(password, instanceId: instanceId)
            }
        })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        OnboardingGatewaySetupAuthPersistenceClient(
            currentInstanceID: {
                .init(value: GatewaySettingsStore.currentInstanceID())
            },
            prepareForBootstrapPairing: { instanceId in
                guard let instanceId = instanceId.trimmedValue else { return }
                GatewayOnboardingReset.prepareForBootstrapPairing(appModel: appModel, instanceId: instanceId)
            },
            saveSetupAuth: self.liveValue.saveSetupAuth)
    }

    static let testValue = OnboardingGatewaySetupAuthPersistenceClient(
        currentInstanceID: { .init(value: "") },
        saveSetupAuth: { _ in })
}

extension DependencyValues {
    var onboardingGatewaySetupAuthPersistence: OnboardingGatewaySetupAuthPersistenceClient {
        get { self[OnboardingGatewaySetupAuthPersistenceClient.self] }
        set { self[OnboardingGatewaySetupAuthPersistenceClient.self] = newValue }
    }
}

struct OnboardingGatewayCredentialsPersistenceClient {
    var loadCredentials: @Sendable (_ instanceId: OnboardingGatewayCurrentInstanceID)
        -> OnboardingGatewayStoredCredentials
    var saveGatewayPassword: @MainActor @Sendable (
        _ value: OnboardingGatewayCredentialValue,
        _ instanceId: OnboardingGatewayCurrentInstanceID)
        -> Void
    var saveGatewayToken: @MainActor @Sendable (
        _ value: OnboardingGatewayCredentialValue,
        _ instanceId: OnboardingGatewayCurrentInstanceID)
        -> Void
}

extension OnboardingGatewayCredentialsPersistenceClient: DependencyKey {
    static let liveValue = OnboardingGatewayCredentialsPersistenceClient(
        loadCredentials: { instanceId in
            guard let instanceId = instanceId.trimmedValue else {
                return .init(token: "", password: "")
            }
            return OnboardingGatewayStoredCredentials(
                token: GatewaySettingsStore.loadGatewayToken(instanceId: instanceId) ?? "",
                password: GatewaySettingsStore.loadGatewayPassword(instanceId: instanceId) ?? "")
        },
        saveGatewayPassword: { value, instanceId in
            guard let instanceId = instanceId.trimmedValue else { return }
            GatewaySettingsStore.saveGatewayPassword(value.value, instanceId: instanceId)
        },
        saveGatewayToken: { value, instanceId in
            guard let instanceId = instanceId.trimmedValue else { return }
            GatewaySettingsStore.saveGatewayToken(value.value, instanceId: instanceId)
        })

    static let testValue = OnboardingGatewayCredentialsPersistenceClient(
        loadCredentials: { _ in .init(token: "", password: "") },
        saveGatewayPassword: { _, _ in },
        saveGatewayToken: { _, _ in })
}

extension DependencyValues {
    var onboardingGatewayCredentialsPersistence: OnboardingGatewayCredentialsPersistenceClient {
        get { self[OnboardingGatewayCredentialsPersistenceClient.self] }
        set { self[OnboardingGatewayCredentialsPersistenceClient.self] = newValue }
    }
}

enum OnboardingStateStore {
    private static let completedDefaultsKey = "onboarding.completed"
    private static let firstRunIntroSeenDefaultsKey = "onboarding.first_run_intro_seen"
    private static let lastModeDefaultsKey = "onboarding.last_mode"
    private static let lastSuccessTimeDefaultsKey = "onboarding.last_success_time"

    @MainActor
    static func shouldPresentOnLaunch(
        appModel: NodeAppModel,
        defaults: UserDefaults = .standard,
        hasSavedGatewayConnection: Bool? = nil)
        -> Bool
    {
        let hasSavedGatewayConnection =
            hasSavedGatewayConnection ?? (GatewaySettingsStore.loadLastGatewayConnection() != nil)
        return Self.featureState(
            defaults: defaults,
            gatewayServerName: appModel.gatewayServerName,
            hasSavedGatewayConnection: hasSavedGatewayConnection)
            .shouldPresentOnLaunch
    }

    static func markCompleted(mode: OnboardingConnectionMode? = nil, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: self.completedDefaultsKey)
        if let mode {
            defaults.set(mode.rawValue, forKey: self.lastModeDefaultsKey)
        }
        defaults.set(Int(Date().timeIntervalSince1970), forKey: Self.lastSuccessTimeDefaultsKey)
    }

    static func shouldPresentFirstRunIntro(defaults: UserDefaults = .standard) -> Bool {
        self.featureState(defaults: defaults).shouldPresentFirstRunIntro
    }

    static func markFirstRunIntroSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: self.firstRunIntroSeenDefaultsKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: self.completedDefaultsKey)
        defaults.set(false, forKey: self.firstRunIntroSeenDefaultsKey)
    }

    static func lastMode(defaults: UserDefaults = .standard) -> OnboardingConnectionMode? {
        let raw = defaults.string(forKey: Self.lastModeDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return OnboardingConnectionMode(rawValue: raw)
    }

    private static func featureState(
        defaults: UserDefaults,
        gatewayServerName: String? = nil,
        hasSavedGatewayConnection: Bool = false)
        -> OnboardingStateFeature.State
    {
        OnboardingStateFeature.State(
            isCompleted: defaults.bool(forKey: self.completedDefaultsKey),
            firstRunIntroSeen: defaults.bool(forKey: self.firstRunIntroSeenDefaultsKey),
            lastMode: self.lastMode(defaults: defaults),
            hasSavedGatewayConnection: hasSavedGatewayConnection,
            gatewayServerName: gatewayServerName)
    }
}
