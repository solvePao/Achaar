import XCTest
import WebKit
#if os(iOS)
@testable import Achaar
#endif

final class AchaarTests: XCTestCase {
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
        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.appearance, .dark)
        XCTAssertEqual(second.startupTab, .messages)
        XCTAssertFalse(second.enhancements)
        XCTAssertTrue(second.blockTrackers)
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
