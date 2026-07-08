import ComposableArchitecture
import Foundation
import OpenClawKit

@Reducer
struct OnboardingStatusFeature {
    static let defaultStatusLine = "In your OpenClaw chat, run /pair qr, then scan the code here."
    static let noSavedPairingStatusLine =
        "No saved pairing found. In your OpenClaw chat, run /pair qr, then scan the code here."

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var connectMessageState = OnboardingConnectionStatusMessage(value: nil)
        var connectingGatewayIDState: OnboardingConnectionID?
        var completionMark = OnboardingGatewayMarkedCompleted(value: false)
        var issue: GatewayConnectionIssue = .none
        var lastPairingAutoResumeAttemptState: OnboardingPairingResumeRequestTime?
        var pairingRequestIdState = OnboardingConnectionIssueRequestID(value: nil)
        var automaticPairingResume = OnboardingAutomaticPairingResume(shouldResume: false)
        var authStepPresentation = OnboardingAuthStepPresentation(shouldShow: false)
        var statusLineState: OnboardingConnectionStatusLine

        init(statusLine: String = OnboardingStatusFeature.defaultStatusLine) {
            self.statusLineState = .init(value: statusLine)
        }

        var connectMessage: String? {
            self.connectMessageState.value
        }

        var connectingGatewayID: String? {
            self.connectingGatewayIDState?.value
        }

        var pairingRequestId: String? {
            self.pairingRequestIdState.value
        }

        var lastPairingAutoResumeAttemptAt: Date? {
            self.lastPairingAutoResumeAttemptState?.value
        }

        var statusLine: String {
            self.statusLineState.value
        }

        var didMarkCompleted: Bool {
            self.completionMark.value
        }

        var shouldResumePairingAutomatically: Bool {
            self.automaticPairingResume.shouldResume
        }

        var shouldShowAuthStep: Bool {
            self.authStepPresentation.shouldShow
        }
    }

    enum Action: Equatable, Sendable {
        struct AutomaticPairingResumeRequest: Equatable, Sendable { var now: OnboardingPairingResumeRequestTime }

        struct ConnectionStart: Equatable, Sendable {
            var id: OnboardingConnectionID
            var message: OnboardingConnectionMessage
            var statusLine: OnboardingConnectionStatusLine
            var clearsIssue: OnboardingConnectionClearsIssue
        }

        struct ConnectionStatusUpdate: Equatable, Sendable {
            var message: OnboardingConnectionStatusMessage
            var statusLine: OnboardingConnectionStatusLine
        }

        struct GatewayConnectionCompletion: Equatable, Sendable {
            var markedCompleted: OnboardingGatewayMarkedCompleted
        }

        struct ConnectionIssueDetection: Equatable, Sendable {
            var issue: GatewayConnectionIssue
            var requestId: OnboardingConnectionIssueRequestID
            var pauseReconnect: OnboardingConnectionPauseReconnect
            var message: OnboardingConnectionIssueMessage
            var statusText: OnboardingConnectionIssueStatusText
        }

        struct ConnectionProblemUpdate: Equatable, Sendable {
            var problem: GatewayConnectionProblem?
            var statusText: OnboardingConnectionIssueStatusText
        }

        struct ConnectionActivityStart: Equatable, Sendable { var id: OnboardingConnectionID }
        struct ScannerError: Equatable, Sendable { var message: OnboardingScannerErrorMessage }

        case automaticPairingResumeRequested(AutomaticPairingResumeRequest)
        case appleReviewDemoModeEnabled
        case connectionFinished
        case connectionIssueDetected(ConnectionIssueDetection)
        case connectionProblemUpdated(ConnectionProblemUpdate)
        case connectionStarted(ConnectionStart)
        case connectionActivityStarted(ConnectionActivityStart)
        case connectionStatusUpdated(ConnectionStatusUpdate)
        case freshQRScanStarted
        case gatewayConnected(GatewayConnectionCompletion)
        case gatewayProblemResetScanStarted
        case introAdvanced
        case navigationBackStarted
        case noSavedPairingFound
        case pairingResumeStarted
        case qrScannerOpeningStarted
        case scannerErrorReceived(ScannerError)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .automaticPairingResumeRequested(request):
                state.automaticPairingResume = .init(shouldResume: false)
                guard state.issue.needsPairing, state.connectingGatewayID == nil else { return .none }
                if let last = state.lastPairingAutoResumeAttemptAt {
                    let elapsedSinceLastAttempt = request.now.value.timeIntervalSince(last)
                    if elapsedSinceLastAttempt < 6 {
                        return .none
                    }
                }
                state.lastPairingAutoResumeAttemptState = request.now
                state.automaticPairingResume = .init(shouldResume: true)
                return .none

            case .appleReviewDemoModeEnabled:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: "Apple Review demo mode enabled.")
                state.statusLineState = .init(value: "Apple Review demo mode enabled.")
                return .none

            case .connectionFinished:
                state.connectingGatewayIDState = nil
                return .none

            case let .connectionIssueDetected(detection):
                Self.applyConnectionIssueDetection(detection, to: &state)
                return .none

            case let .connectionProblemUpdated(update):
                let detectedIssue = GatewayConnectionIssue.detect(problem: update.problem)
                let fallbackIssue = detectedIssue == .none
                    ? GatewayConnectionIssue.detect(from: update.statusText.value)
                    : detectedIssue
                Self.applyConnectionIssueDetection(.init(
                    issue: fallbackIssue,
                    requestId: .init(value: update.problem?.requestId ?? fallbackIssue.requestId),
                    pauseReconnect: .init(value: update.problem?.pauseReconnect == true),
                    message: .init(value: update.problem?.message),
                    statusText: update.statusText), to: &state)
                return .none

            case let .connectionStarted(start):
                state.connectingGatewayIDState = start.id
                if start.clearsIssue.value {
                    state.issue = .none
                    state.authStepPresentation = .init(shouldShow: false)
                }
                state.connectMessageState = .init(value: start.message.value)
                state.statusLineState = start.statusLine
                return .none

            case let .connectionActivityStarted(start):
                state.connectingGatewayIDState = start.id
                return .none

            case let .connectionStatusUpdated(update):
                state.connectMessageState = update.message
                state.statusLineState = update.statusLine
                return .none

            case .freshQRScanStarted:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: nil)
                state.issue = .none
                state.lastPairingAutoResumeAttemptState = nil
                state.pairingRequestIdState = .init(value: nil)
                state.automaticPairingResume = .init(shouldResume: false)
                state.authStepPresentation = .init(shouldShow: false)
                state.statusLineState = .init(value: "Opening QR scanner…")
                return .none

            case let .gatewayConnected(completion):
                state.statusLineState = .init(value: "Connected.")
                if completion.markedCompleted.value {
                    state.completionMark = completion.markedCompleted
                }
                return .none

            case .gatewayProblemResetScanStarted:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: nil)
                state.issue = .none
                state.lastPairingAutoResumeAttemptState = nil
                state.pairingRequestIdState = .init(value: nil)
                state.automaticPairingResume = .init(shouldResume: false)
                state.authStepPresentation = .init(shouldShow: false)
                state.statusLineState = .init(value: "Scan a fresh setup QR code from this gateway.")
                return .none

            case .introAdvanced:
                state.statusLineState = .init(value: Self.defaultStatusLine)
                return .none

            case .navigationBackStarted:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: nil)
                return .none

            case .noSavedPairingFound:
                state.statusLineState = .init(value: Self.noSavedPairingStatusLine)
                return .none

            case .pairingResumeStarted:
                state.issue = .none
                state.automaticPairingResume = .init(shouldResume: false)
                state.authStepPresentation = .init(shouldShow: false)
                state.connectMessageState = .init(value: "Retrying after approval…")
                state.statusLineState = .init(value: "Retrying after approval…")
                return .none

            case .qrScannerOpeningStarted:
                state.statusLineState = .init(value: "Opening QR scanner…")
                return .none

            case let .scannerErrorReceived(error):
                state.statusLineState = .init(value: "Scanner error: \(error.message.value)")
                return .none
            }
        }
        .autoLogActions()
    }

    private static func applyConnectionIssueDetection(
        _ detection: Action.ConnectionIssueDetection,
        to state: inout State)
    {
        state.issue = self.stickyIssue(
            current: state.issue,
            detected: detection.issue,
            pairingRequestId: state.pairingRequestId)
        if let requestId = detection.requestId.value, !requestId.isEmpty {
            state.pairingRequestIdState = .init(value: requestId)
        }
        state.authStepPresentation = .init(shouldShow:
            state.issue.needsAuthToken
                || state.issue.needsPairing
                || detection.pauseReconnect.value)

        if let message = detection.message.value {
            state.connectMessageState = .init(value: message)
            state.statusLineState = .init(value: message)
        } else {
            let trimmedStatus = detection.statusText.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedStatus.isEmpty {
                state.connectMessageState = .init(value: trimmedStatus)
                state.statusLineState = .init(value: trimmedStatus)
            }
        }
    }

    private static func stickyIssue(
        current: GatewayConnectionIssue,
        detected: GatewayConnectionIssue,
        pairingRequestId: String?)
        -> GatewayConnectionIssue
    {
        if current.needsPairing, detected.needsPairing {
            let mergedRequestId = detected.requestId ?? current.requestId ?? pairingRequestId
            return .pairingRequired(requestId: mergedRequestId)
        }
        if current.needsPairing, !detected.needsPairing {
            return current
        }
        if current.needsAuthToken, !detected.needsAuthToken, !detected.needsPairing {
            return current
        }
        return detected
    }
}
