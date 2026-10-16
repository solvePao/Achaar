import XCTest
import WebKit
#if os(iOS)
@testable import Achaar
#endif

final class AchaarTests: XCTestCase {
    func testMobileSafariCompatibilityPreservesWebKitIdentity() {
        let engine = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)"
        let version = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 1)
        let expected = engine + " Version/27.0 Mobile/15E148 Safari/604.1"
        XCTAssertEqual(InstagramRouting.mobileSafariUserAgent(from: engine + " Mobile/15E148 Achaar/1.0", version: version), expected)
        XCTAssertEqual(InstagramRouting.mobileSafariUserAgent(from: expected, version: version), expected,
                       "Reapplying compatibility must not duplicate browser tokens.")
        XCTAssertNil(InstagramRouting.mobileSafariUserAgent(from: "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15", version: version))
        XCTAssertNil(InstagramRouting.mobileSafariUserAgent(from: "iPhone unknown engine", version: version))
    }

    @MainActor func testUsageResetsAtThreeAMAndSurvivesRelaunch() {
        let name = "usage.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 2, minute: 59, second: 50))!
        let tracker = UsageTracker(defaults: defaults, calendar: calendar)
        tracker.begin(at: start); tracker.record(at: start.addingTimeInterval(20))
        XCTAssertEqual(tracker.seconds(at: start.addingTimeInterval(20)), 10)
        tracker.end(at: start.addingTimeInterval(30))
        XCTAssertEqual(tracker.seconds(at: start.addingTimeInterval(30)), 20)
        let reloaded = UsageTracker(defaults: defaults, calendar: calendar)
        XCTAssertEqual(reloaded.seconds(at: start.addingTimeInterval(3600)), 20)
        XCTAssertEqual(reloaded.seconds(at: start.addingTimeInterval(86420)), 0)
    }
    @MainActor func testUsageDoesNotCountInactiveTimeOrResumeCrashedInterval() {
        let name = "usage.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let start = Date(timeIntervalSince1970: 1800000000)
        let tracker = UsageTracker(defaults: defaults)
        tracker.begin(at: start); tracker.record(at: start.addingTimeInterval(5))
        let relaunched = UsageTracker(defaults: defaults)
        relaunched.begin(at: start.addingTimeInterval(100)); relaunched.end(at: start.addingTimeInterval(110))
        XCTAssertEqual(relaunched.seconds(at: start.addingTimeInterval(200)), 15)
        relaunched.record(at: start.addingTimeInterval(300))
        XCTAssertEqual(relaunched.seconds(at: start.addingTimeInterval(300)), 15)
    }

    @MainActor func testUsageLifetimeIncludesBothSidesOfResetAndSurvivesRelaunch() {
        withUsageTracker { tracker, defaults, calendar in
            let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 2, minute: 59, second: 50))!
            tracker.begin(at: start)
            tracker.end(at: start.addingTimeInterval(30))
            XCTAssertEqual(tracker.summary(at: start.addingTimeInterval(30)).lifetimeSeconds, 30)
            XCTAssertEqual(tracker.seconds(at: start.addingTimeInterval(30)), 20)
            XCTAssertEqual(tracker.seconds(at: start), 10)
            let reloaded = UsageTracker(defaults: defaults, calendar: calendar)
            XCTAssertEqual(reloaded.summary(at: start.addingTimeInterval(86_400)).lifetimeSeconds, 30)
            reloaded.begin(at: start.addingTimeInterval(86_400))
            reloaded.end(at: start.addingTimeInterval(86_410))
            XCTAssertEqual(reloaded.summary(at: start.addingTimeInterval(86_410)).lifetimeSeconds, 40)
        }
    }

    @MainActor func testUsageMigratesLegacyCounterOnlyOnceIncludingOldDay() {
        withUsageTracker { _, defaults, calendar in
            defaults.removeObject(forKey: "usage.statistics.v1")
            let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 3))!
            defaults.set(day.timeIntervalSince1970, forKey: "usage.day")
            defaults.set(3600.0, forKey: "usage.seconds")
            let migrated = UsageTracker(defaults: defaults, calendar: calendar)
            XCTAssertEqual(migrated.seconds(at: day), 3600)
            let later = day.addingTimeInterval(10 * 86_400)
            migrated.record(at: later)
            XCTAssertEqual(migrated.summary(at: later).lifetimeSeconds, 3600)
            XCTAssertEqual(migrated.summary(at: later).projectedSeconds, 0)
            defaults.set(9000.0, forKey: "usage.seconds")
            let reloaded = UsageTracker(defaults: defaults, calendar: calendar)
            XCTAssertEqual(reloaded.summary(at: later).lifetimeSeconds, 3600)
        }
    }

    @MainActor func testUsageProjectionUsesMaximumWithinSevenDaysAndExpiresIt() {
        withUsageTracker { tracker, _, calendar in
            let first = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
            XCTAssertEqual(tracker.summary(at: first).projectedSeconds, 0)
            tracker.begin(at: first); tracker.end(at: first.addingTimeInterval(7200))
            let second = first.addingTimeInterval(86_400)
            tracker.begin(at: second); tracker.end(at: second.addingTimeInterval(3600))
            let sixth = first.addingTimeInterval(6 * 86_400)
            let yearEnd = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
            XCTAssertEqual(tracker.summary(at: sixth).projectedSeconds,
                           7200 * yearEnd.timeIntervalSince(sixth) / 86_400, accuracy: 0.001)
            let seventh = first.addingTimeInterval(7 * 86_400)
            tracker.record(at: seventh)
            XCTAssertEqual(tracker.summary(at: seventh).projectedSeconds,
                           3600 * yearEnd.timeIntervalSince(seventh) / 86_400, accuracy: 0.001)
            XCTAssertEqual(tracker.summary(at: seventh).lifetimeSeconds, 10_800)
            XCTAssertEqual(tracker.summary(at: first.addingTimeInterval(8 * 86_400)).projectedSeconds, 0)
        }
    }

    @MainActor func testUsageProjectionYearRolloverUsesLocalMidnightAndFormatsDurations() {
        withUsageTracker { _, defaults, _ in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
            let tracker = UsageTracker(defaults: defaults, calendar: calendar)
            let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 12))!
            tracker.begin(at: start); tracker.end(at: start.addingTimeInterval(3600))
            let midnight = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
            XCTAssertEqual(tracker.summary(at: midnight.addingTimeInterval(-1)).projectedSeconds, 3600 / 86_400, accuracy: 0.001)
            XCTAssertEqual(tracker.summary(at: midnight).projectedSeconds, 3600 * 365, accuracy: 0.001)
            XCTAssertEqual(tracker.summary(at: midnight).lifetimeSeconds, 3600)
            let formatted = UsageSummary(todaySeconds: 8159, lifetimeSeconds: 463259, projectedSeconds: 1_058_459)
            XCTAssertEqual(formatted.todayLabel, "Today: 2h 15m")
            XCTAssertEqual(formatted.lifetimeLabel, "Total time spent: 128h 40m")
            XCTAssertEqual(formatted.projectionLabel, "Expected time wasted by Dec 31: 12d 6h 0m")
        }
    }

    @MainActor func testUsageDoesNotDuplicateCheckpointsOrCountInactiveGaps() {
        withUsageTracker { tracker, defaults, calendar in
            let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 12))!
            tracker.begin(at: start); tracker.begin(at: start.addingTimeInterval(10))
            tracker.record(at: start.addingTimeInterval(5))
            tracker.end(at: start.addingTimeInterval(20))
            tracker.record(at: start.addingTimeInterval(100))
            let reloaded = UsageTracker(defaults: defaults, calendar: calendar)
            reloaded.begin(at: start.addingTimeInterval(200)); reloaded.end(at: start.addingTimeInterval(210))
            XCTAssertEqual(reloaded.summary(at: start.addingTimeInterval(210)).lifetimeSeconds, 30)
        }
    }

    @MainActor func testUsageSplitsMultipleDaysAcrossDaylightSavingTime() {
        withUsageTracker { _, defaults, _ in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            let tracker = UsageTracker(defaults: defaults, calendar: calendar)
            let first = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 3))!
            let second = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 3))!
            let third = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 3))!
            tracker.begin(at: first); tracker.end(at: third.addingTimeInterval(60))
            XCTAssertEqual(tracker.seconds(at: first), 23 * 3600)
            XCTAssertEqual(tracker.seconds(at: second), 24 * 3600)
            XCTAssertEqual(tracker.seconds(at: third), 60)
            XCTAssertEqual(tracker.summary(at: third).lifetimeSeconds, 47 * 3600 + 60)
        }
    }

    @MainActor private func withUsageTracker(_ body: (UsageTracker, UserDefaults, Calendar) -> Void) {
        let name = "usage.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        body(UsageTracker(defaults: defaults, calendar: calendar), defaults, calendar)
    }

    func testOnlySecureInstagramOriginsAreEmbedded() {
        for value in ["https://instagram.com/", "https://www.instagram.com/direct/inbox/", "https://accountscenter.instagram.com/"] {
            XCTAssertTrue(InstagramRouting.isInstagram(URL(string: value)), value)
        }
        for value in ["http://instagram.com/", "https://instagram.com.attacker.example/", "https://fakeinstagram.com/",
                      "https://instagram.com:444/", "https://user:secret@instagram.com/", "file:///instagram.com", "javascript:alert(1)"] {
            XCTAssertFalse(InstagramRouting.isInstagram(URL(string: value)), value)
        }
        XCTAssertFalse(InstagramRouting.isInstagram(nil))
    }

    func testBridgeRejectsSubframesAndUntrustedOrigins() {
        XCTAssertTrue(InstagramRouting.allowsBridge(host: "www.instagram.com", scheme: "https", port: 443, mainFrame: true))
        XCTAssertTrue(InstagramRouting.allowsBridge(host: "instagram.com", scheme: "https", port: 0, mainFrame: true))
        XCTAssertFalse(InstagramRouting.allowsBridge(host: "www.instagram.com", scheme: "https", port: 443, mainFrame: false))
        XCTAssertFalse(InstagramRouting.allowsBridge(host: "accountscenter.instagram.com", scheme: "https", port: 443, mainFrame: true))
        XCTAssertFalse(InstagramRouting.allowsBridge(host: "www.instagram.com", scheme: "http", port: 80, mainFrame: true))
        XCTAssertFalse(InstagramRouting.allowsBridge(host: "www.instagram.com.attacker.example", scheme: "https", port: 443, mainFrame: true))
    }

    func testRoutesDoNotMisclassifyProfilesOrAuthentication() {
        XCTAssertEqual(InstagramRouting.tab(for: "/"), .home)
        XCTAssertEqual(InstagramRouting.tab(for: "/direct/t/123/"), .messages)
        XCTAssertEqual(InstagramRouting.tab(for: "/explore/tags/test/"), .explore)
        XCTAssertEqual(InstagramRouting.tab(for: "/reels/"), .reels)
        XCTAssertNil(InstagramRouting.tab(for: "/accounts/login/"))
        XCTAssertNil(InstagramRouting.tab(for: "/some_username/"))
        XCTAssertNil(InstagramRouting.tab(for: "/direct-impersonation/"))
    }

    func testExternalLinksUnwrapShimAndRejectUnsafeSchemes() {
        let shim = URL(string: "https://l.instagram.com/?u=https%3A%2F%2Fexample.com%2Fhello")!
        XCTAssertEqual(InstagramRouting.externalURL(shim)?.absoluteString, "https://example.com/hello")
        XCTAssertNil(InstagramRouting.externalURL(URL(string: "javascript:alert(1)")!))
        XCTAssertNil(InstagramRouting.externalURL(URL(string: "https://user:secret@example.com/")!))
        XCTAssertNil(InstagramRouting.externalURL(URL(string: "file:///tmp/private")!))
        XCTAssertNil(InstagramRouting.externalURL(URL(string: "https:missing-host")!))
    }

    func testShareURLsExcludePrivateRoutesAndQueryStrings() {
        XCTAssertNil(InstagramRouting.shareURL(URL(string: "https://www.instagram.com/accounts/login/?token=private")))
        XCTAssertNil(InstagramRouting.shareURL(URL(string: "https://www.instagram.com/direct/t/123/")))
        XCTAssertNil(InstagramRouting.shareURL(URL(string: "https://www.instagram.com/fixture_username/saved/")))
        XCTAssertNil(InstagramRouting.shareURL(URL(string: "https://www.instagram.com/archive/stories/")))
        XCTAssertNil(InstagramRouting.shareURL(URL(string: "https://www.instagram.com/notifications/")))
        XCTAssertNil(InstagramRouting.shareURL(URL(string: "https://example.com/")))
        XCTAssertEqual(InstagramRouting.shareURL(URL(string: "https://www.instagram.com/p/fixture/?tracking=1#fragment"))?.absoluteString,
                       "https://www.instagram.com/p/fixture/")
    }

    @MainActor
    func testPreferencesPersistAndSafeDefaults() {
        let suite = "AchaarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppSettings(defaults: defaults)
        XCTAssertFalse(first.appLock)
        XCTAssertFalse(first.blockTrackers)
        XCTAssertTrue(first.confirmExternalLinks)
        XCTAssertTrue(first.obscureAppSwitcher)
        first.appearance = .dark
        first.startupTab = .messages
        first.enhancements = false
        first.blockTrackers = true
        first.compatibilityScrolling = false
        first.keepMessagesReady = false
        first.cacheBudgetMB = 128
        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.appearance, .dark)
        XCTAssertEqual(second.startupTab, .messages)
        XCTAssertFalse(second.enhancements)
        XCTAssertTrue(second.blockTrackers)
        XCTAssertFalse(second.compatibilityScrolling)
        XCTAssertFalse(second.keepMessagesReady)
        XCTAssertEqual(second.cacheBudgetMB, 128)
    }

    func testInterruptedBrowsingShowsRecoveryAndNormalExitResetsIt() {
        let suite = "AchaarRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(BrowsingRecovery.beginSession(in: defaults))
        XCTAssertFalse(BrowsingRecovery.beginSession(in: defaults))
        XCTAssertTrue(BrowsingRecovery.beginSession(in: defaults))
        BrowsingRecovery.endSession(in: defaults)
        XCTAssertFalse(BrowsingRecovery.beginSession(in: defaults))
        BrowsingRecovery.endSession(in: defaults)
        BrowsingRecovery.markActive(in: defaults)
        XCTAssertTrue(defaults.bool(forKey: "browsingWasActive"))
    }

    func testCacheBudgetMeasuresFilesWithoutFollowingLinks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("fixture")
        try Data(repeating: 0, count: 4096).write(to: file)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("link"), withDestinationURL: file)
        XCTAssertEqual(CacheBudget.bytes(in: directory), 4096)
        XCTAssertFalse(CacheBudget.shouldTrim(bytes: 64 * 1_048_576, budgetMB: 64))
        XCTAssertTrue(CacheBudget.shouldTrim(bytes: 64 * 1_048_576 + 1, budgetMB: 64))
        XCTAssertTrue(CacheBudget.shouldTrim(bytes: 0, budgetMB: 0))
    }

    @MainActor
    func testTrackerRulesCompileAndCanBeDisabled() async throws {
        let bundle = Bundle(for: AchaarTests.self)
        let url = bundle.url(forResource: "TrackerRules", withExtension: "json")
            ?? Bundle.main.url(forResource: "TrackerRules", withExtension: "json")
        XCTAssertNotNil(url)
        let protection = TrackerProtection(rulesURL: url)
        let content = WKUserContentController()
        try await protection.apply(enabled: true, to: [content])
        XCTAssertNotNil(protection.activeRuleList)
        try await protection.apply(enabled: false, to: [content])
        XCTAssertNil(protection.activeRuleList)
    }

    @MainActor
    func testWebsiteDataClearingPreservesOrRemovesCookies() async {
        let store = WKWebsiteDataStore.nonPersistent()
        let cookie = HTTPCookie(properties: [.domain: "www.instagram.com", .path: "/", .name: "achaar-test",
                                            .value: "fixture", .secure: "TRUE"])!
        await store.httpCookieStore.setCookie(cookie)
        await WebsiteDataCleaner.clear(in: store, includeSession: false)
        let preserved = await store.httpCookieStore.allCookies()
        XCTAssertTrue(preserved.contains { $0.name == "achaar-test" })
        await WebsiteDataCleaner.clear(in: store, includeSession: true)
        let cleared = await store.httpCookieStore.allCookies()
        XCTAssertFalse(cleared.contains { $0.name == "achaar-test" })
    }

    #if os(iOS)
    @MainActor
    func testCacheClearingPreservesCookieButSessionClearingRemovesIt() async {
        let suite = "AchaarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WKWebsiteDataStore.nonPersistent()
        let browser = BrowserModel(settings: AppSettings(defaults: defaults), dataStore: store)
        let cookie = HTTPCookie(properties: [.domain: "www.instagram.com", .path: "/", .name: "achaar-test", .value: "fixture", .secure: "TRUE"])!
        await store.httpCookieStore.setCookie(cookie)
        let originalView = browser.webView
        await browser.clearWebsiteData(includeSession: false, reload: false)
        XCTAssertTrue(browser.webView === originalView)
        browser.webView.stopLoading()
        let preserved = await store.httpCookieStore.allCookies()
        XCTAssertTrue(preserved.contains { $0.name == "achaar-test" })
        await browser.clearWebsiteData(includeSession: true, reload: false)
        browser.webView.stopLoading()
        let cleared = await store.httpCookieStore.allCookies()
        XCTAssertFalse(cleared.contains { $0.name == "achaar-test" })
        XCTAssertFalse(browser.webView === originalView)
        XCTAssertFalse(browser.canGoBack)
        XCTAssertFalse(browser.isClearing)
        XCTAssertEqual(browser.selectedTab, .home)
    }
    #endif
}
