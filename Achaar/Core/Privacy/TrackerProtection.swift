import WebKit

@MainActor
final class TrackerProtection {
    private static let identifier = "achaar.optional-trackers.v1"
    private(set) var activeRuleList: WKContentRuleList?
    private var revision = 0
    private let rulesURL: URL?

    init(rulesURL: URL? = Bundle.main.url(forResource: "TrackerRules", withExtension: "json")) {
        self.rulesURL = rulesURL
    }

    func apply(enabled: Bool, to controllers: [WKUserContentController]) async throws {
        revision += 1
        let token = revision
        if let activeRuleList {
            controllers.forEach { $0.remove(activeRuleList) }
            self.activeRuleList = nil
        }
        guard enabled else { return }
        guard let url = rulesURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let rules = try String(contentsOf: url, encoding: .utf8)
        let compiled: WKContentRuleList = try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: Self.identifier,
                                                                    encodedContentRuleList: rules) { list, error in
                if let list { continuation.resume(returning: list) }
                else { continuation.resume(throwing: error ?? CocoaError(.coderInvalidValue)) }
            }
        }
        guard token == revision else { return }
        activeRuleList = compiled
        controllers.forEach { $0.add(compiled) }
    }
}
