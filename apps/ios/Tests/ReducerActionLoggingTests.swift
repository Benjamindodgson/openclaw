import Testing
@testable import OpenClaw

struct ReducerActionLoggingTests {
    @Test func `label excludes associated payload values`() {
        let action = SampleAction.response(message: "secret-token", code: 401)
        let label = OpenClawTCAActionLog.label(
            feature: "OpenClaw/SampleFeature.swift",
            action: action)

        #expect(label == "SampleFeature.response")
        #expect(!label.contains("secret-token"))
        #expect(!label.contains("401"))
    }
}

private enum SampleAction: Equatable {
    case response(message: String, code: Int)
}
