import ComposableArchitecture
import OSLog

private let openClawTCAReducerLogger = Logger(
    subsystem: "ai.openclawfoundation.OpenClaw",
    category: "tca")

extension Reducer {
    func autoLogActions(
        feature: StaticString = #fileID,
        logger: Logger = openClawTCAReducerLogger) -> some Reducer<State, Action>
    {
        Reduce { state, action in
            #if DEBUG
            logger.debug("\(OpenClawTCAActionLog.label(feature: feature, action: action), privacy: .public)")
            #endif
            return self._reduce(into: &state, action: action)
        }
    }
}

enum OpenClawTCAActionLog {
    static func label(feature: StaticString, action: some Any) -> String {
        "\(self.featureName(from: feature)).\(self.actionName(action))"
    }

    static func featureName(from feature: StaticString) -> String {
        let fileID = String(describing: feature)
        let fileName = fileID.split(separator: "/").last.map(String.init) ?? fileID
        return fileName.replacingOccurrences(of: ".swift", with: "")
    }

    static func actionName(_ action: some Any) -> String {
        if let caseName = Mirror(reflecting: action).children.first?.label, !caseName.isEmpty {
            return caseName
        }

        let description = String(describing: action)
        guard let payloadStart = description.firstIndex(of: "(") else {
            return description
        }
        return String(description[..<payloadStart])
    }
}
