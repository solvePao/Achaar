import SwiftUI
import WebKit
import AVFoundation
import Observation

struct WebPopup: Identifiable {
    let id = UUID()
    let webView: WKWebView
}

struct ExternalDestination: Identifiable {
    let id = UUID()
    let url: URL
}

struct BrowserDialog: Identifiable {
    enum Kind { case alert, confirm, prompt }
    let id = UUID()
    let kind: Kind
    let source: ObjectIdentifier
    let message: String
    let defaultText: String
    let complete: @MainActor (Bool, String?) -> Void
}

private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var owner: BrowserModel?
    init(owner: BrowserModel) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        owner?.receive(message)
    }
}

@MainActor @Observable
final class BrowserModel: NSObject {
    let settings: AppSettings
    private(set) var webView: WKWebView
    private let protection = TrackerProtection()
    private var observations: [NSKeyValueObservation] = []
    private var hasStarted = false
    private var navigationRevision = 0
    private var pendingStartupProfile = false
    private var dialogs: [BrowserDialog] = []
    private var retainedPopup: WKWebView?
    private var pausedCapture: [ObjectIdentifier: (camera: Bool, microphone: Bool)] = [:]
    private var internalBlankNavigation = false

    var selectedTab: InstagramTab
    var isPresentationAllowed = true
    var isLoading = false
    var progress = 0.0
    var canGoBack = false
    var failure: String?
    var notice: String?
    var popup: WebPopup?
    var externalRequest: ExternalDestination?
    var externalDestination: ExternalDestination?
    var dialog: BrowserDialog?
    private(set) var isClearing = false

    init(settings: AppSettings, dataStore: WKWebsiteDataStore = .default()) {
        self.settings = settings
        selectedTab = settings.startupTab
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio]
        // Use WebKit's genuine mobile user agent. No browser/device spoofing.
        configuration.applicationNameForUserAgent = "Achaar/1.0"
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        let content = configuration.userContentController
        content.add(WeakScriptHandler(owner: self), name: "achaar")
        installScripts(into: content)
        attachWebView()
    }

    private func attachWebView() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.setAllMediaPlaybackSuspended(!isPresentationAllowed, completionHandler: nil)
        observations = [
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.isLoading = view.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.progress = view.estimatedProgress }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoBack = view.canGoBack }
            }
        ]
    }

    private func installScripts(into content: WKUserContentController) {
        guard let jsURL = Bundle.main.url(forResource: "Navigation", withExtension: "js"),
              let cssURL = Bundle.main.url(forResource: "Enhancements", withExtension: "css"),
              let js = try? String(contentsOf: jsURL, encoding: .utf8),
              let css = try? String(contentsOf: cssURL, encoding: .utf8),
              let data = try? JSONEncoder().encode(css), let cssLiteral = String(data: data, encoding: .utf8)
        else { notice = "Web enhancements are unavailable. Instagram’s original interface will remain visible."; return }
        let originGuard = "if (!['instagram.com','www.instagram.com'].includes(location.hostname) || location.protocol !== 'https:') return;"
        let source = "(() => { \(originGuard) const style = document.createElement('style'); style.id = 'achaar-style'; style.textContent = \(cssLiteral); document.documentElement.appendChild(style); })();\n" +
            "(() => { \(originGuard) \(js) })();"
        content.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await updateProtection(reload: false)
        pendingStartupProfile = selectedTab == .profile
        load(path: selectedTab.path ?? "/")
    }

    func select(_ tab: InstagramTab) {
        guard !isClearing else { return }
        navigationRevision += 1
        let previous = selectedTab
        if settings.haptics && previous != tab { UISelectionFeedbackGenerator().selectionChanged() }
        if tab == .profile {
            perform(.profile)
        } else if let path = tab.path {
            selectedTab = tab
            if webView.url?.path == path {
                webView.scrollView.setContentOffset(.zero, animated: true)
                return
            }
            let revision = navigationRevision
            // Let Instagram's own anchors perform SPA navigation when available.
            // A direct HTTPS route remains the fallback for missing page controls.
            webView.evaluateJavaScript("window.AchaarWeb?.navigate('\(tab.rawValue)') ?? false") { [weak self] result, _ in
                guard let self, !self.isClearing, self.navigationRevision == revision else { return }
                if result as? Bool != true { self.load(path: path) }
            }
        }
    }

    private func load(path: String) {
        navigationRevision += 1
        failure = nil
        webView.load(URLRequest(url: URL(string: path, relativeTo: InstagramRouting.home)!.absoluteURL))
    }

    func refresh() {
        guard !isClearing else { return }
        navigationRevision += 1
        failure = nil
        if webView.url == nil { load(path: "/") } else { webView.reload() }
    }

    func goBack() {
        if !isClearing { navigationRevision += 1; webView.goBack() }
    }

    func perform(_ action: WebAction) {
        guard !isClearing else { return }
        navigationRevision += 1
        let revision = navigationRevision
        guard InstagramRouting.isInstagram(webView.url) else { revealOriginalNavigation(); return }
        webView.evaluateJavaScript("window.AchaarWeb?.action('\(action.rawValue)') ?? false") { [weak self] result, _ in
            guard let self, !self.isClearing, self.navigationRevision == revision else { return }
            if result as? Bool == true {
                if action == .profile { self.selectedTab = .profile }
            } else { self.revealOriginalNavigation() }
        }
    }

    private func revealOriginalNavigation() {
        settings.enhancements = false
        updateEnhancements()
        notice = "Use Instagram’s web controls for this action. The original interface has been restored; you can re-enable enhancements in Settings."
    }

    func updateEnhancements() {
        let script = "window.AchaarWeb?.setEnhanced(\(settings.enhancements ? "true" : "false"))"
        webView.evaluateJavaScript(script, completionHandler: nil)
        popup?.webView.evaluateJavaScript("window.AchaarWeb?.setEnhanced(false)", completionHandler: nil)
    }

    func updateProtection(reload: Bool = true) async {
        var controllers = [webView.configuration.userContentController]
        if let controller = popup?.webView.configuration.userContentController,
           controller !== controllers[0] { controllers.append(controller) }
        do {
            try await protection.apply(enabled: settings.blockTrackers, to: controllers)
            if reload { refresh(); popup?.webView.reload() }
        } catch {
            settings.blockTrackers = false
            notice = "Tracker protection could not be enabled. It is switched off so Instagram can continue loading."
        }
    }

    func receive(_ message: WKScriptMessage) {
        let origin = message.frameInfo.securityOrigin
        guard !isClearing, message.webView === webView,
              InstagramRouting.allowsBridge(host: origin.host, scheme: origin.protocol,
                                             port: origin.port, mainFrame: message.frameInfo.isMainFrame),
              let body = message.body as? [String: Any], body.count == 2,
              body["type"] as? String == "tab", let value = body["value"] as? String,
              let tab = InstagramTab(rawValue: value), tab != .profile else { return }
        selectedTab = tab
        tryStartupProfile()
    }

    private func tryStartupProfile() {
        guard pendingStartupProfile, selectedTab == .home else { return }
        pendingStartupProfile = false
        perform(.profile)
    }

    func clearWebsiteData(includeSession: Bool, reload: Bool = true) async {
        guard !isClearing else { return }
        isClearing = true
        navigationRevision += 1
        pendingStartupProfile = false
        defer { isClearing = false }
        webView.stopLoading()
        closePopup()
        externalRequest = nil
        externalDestination = nil
        cancelDialogs()
        internalBlankNavigation = true
        webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        await webView.setAllMediaPlaybackSuspended(true)
        pausedCapture.removeAll()
        await WebsiteDataCleaner.clear(in: webView.configuration.websiteDataStore, includeSession: includeSession)
        if includeSession {
            // Replacing only during a full session wipe also discards the back-forward
            // list and in-memory page cache. Normal navigation retains the same view.
            let configuration = webView.configuration
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            observations.removeAll()
            webView = WKWebView(frame: .zero, configuration: configuration)
            attachWebView()
        } else {
            await webView.setAllMediaPlaybackSuspended(!isPresentationAllowed)
        }
        selectedTab = .home
        failure = nil
        internalBlankNavigation = false
        isClearing = false
        if reload { load(path: includeSession ? "/accounts/login/" : "/") }
    }

    func suspendMedia(_ suspended: Bool) {
        isPresentationAllowed = !suspended
        for view in [webView, popup?.webView].compactMap({ $0 }) {
            view.setAllMediaPlaybackSuspended(suspended, completionHandler: nil)
            let id = ObjectIdentifier(view)
            if suspended {
                let prior = pausedCapture[id] ?? (camera: false, microphone: false)
                let camera = view.cameraCaptureState == .active
                let microphone = view.microphoneCaptureState == .active
                pausedCapture[id] = (prior.camera || camera, prior.microphone || microphone)
                if camera { view.setCameraCaptureState(.muted, completionHandler: nil) }
                if microphone { view.setMicrophoneCaptureState(.muted, completionHandler: nil) }
            } else if let prior = pausedCapture.removeValue(forKey: id) {
                if prior.camera && view.cameraCaptureState == .muted {
                    view.setCameraCaptureState(.active, completionHandler: nil)
                }
                if prior.microphone && view.microphoneCaptureState == .muted {
                    view.setMicrophoneCaptureState(.active, completionHandler: nil)
                }
            }
        }
    }

    func prepareForLock() {
        closePopup()
        externalRequest = nil
        externalDestination = nil
        notice = nil
        cancelDialogs()
    }

    func closePopup() {
        guard let child = popup?.webView ?? retainedPopup else { return }
        child.stopLoading()
        child.setAllMediaPlaybackSuspended(true, completionHandler: nil)
        child.navigationDelegate = nil
        child.uiDelegate = nil
        popup = nil
        retainedPopup = nil
        pausedCapture.removeValue(forKey: ObjectIdentifier(child))
        cancelDialogs(source: ObjectIdentifier(child))
    }

    func finishDialog(accepted: Bool, text: String? = nil) {
        guard let current = dialog else { return }
        dialog = nil
        current.complete(accepted, text)
        if !dialogs.isEmpty { dialog = dialogs.removeFirst() }
    }

    private func enqueue(_ next: BrowserDialog) {
        if dialog == nil { dialog = next } else { dialogs.append(next) }
    }

    private func cancelDialogs(source: ObjectIdentifier? = nil) {
        let pending = [dialog].compactMap { $0 } + dialogs
        let cancelled = pending.filter { source == nil || $0.source == source }
        let remaining = pending.filter { source != nil && $0.source != source }
        dialog = remaining.first
        dialogs = Array(remaining.dropFirst())
        cancelled.forEach { $0.complete(false, nil) }
    }

    private func requestExternal(_ url: URL) {
        guard let destination = InstagramRouting.externalURL(url) else {
            notice = "This link uses an unsupported scheme. Open the original web interface if needed."
            return
        }
        let request = ExternalDestination(url: destination)
        if settings.confirmExternalLinks { externalRequest = request }
        else { externalDestination = request }
    }
}

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString == "about:blank", internalBlankNavigation || webView !== self.webView {
            decisionHandler(.allow); return
        }
        guard !isClearing else { decisionHandler(.cancel); return }
        if InstagramRouting.isInstagram(url), url.host?.lowercased() != "l.instagram.com" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            // Only top-level/user navigations leave the app; never third-party subframes.
            if navigationAction.targetFrame?.isMainFrame != false {
                requestExternal(url)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isClearing else { return }
        internalBlankNavigation = false
        if webView === self.webView {
            failure = nil
            if let path = webView.url?.path, let tab = InstagramRouting.tab(for: path) { selectedTab = tab }
            updateEnhancements()
            tryStartupProfile()
        } else { webView.evaluateJavaScript("window.AchaarWeb?.setEnhanced(false)", completionHandler: nil) }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailure(webView, error: error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(webView, error: error)
    }
    private func handleFailure(_ view: WKWebView, error: Error) {
        guard !isClearing, (error as NSError).code != NSURLErrorCancelled else { return }
        if view === webView { failure = "Instagram couldn’t load. Check your connection and try again." }
        else { notice = "The additional Instagram window couldn’t load. Close it and try again." }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !isClearing else { return }
        if webView === self.webView { failure = "The web session stopped responding. Tap Retry to reload it." }
        else { notice = "The additional Instagram window stopped responding. Close it and try again." }
    }
}

extension BrowserModel: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !isClearing, let url = navigationAction.request.url else { return nil }
        guard InstagramRouting.isInstagram(url), url.host?.lowercased() != "l.instagram.com" else {
            requestExternal(url); return nil
        }
        guard popup == nil else { notice = "Close the current Instagram window before opening another."; return nil }
        configuration.websiteDataStore = self.webView.configuration.websiteDataStore
        let child = WKWebView(frame: .zero, configuration: configuration)
        child.navigationDelegate = self
        child.uiDelegate = self
        child.allowsBackForwardNavigationGestures = true
        if configuration.userContentController !== self.webView.configuration.userContentController,
           let list = protection.activeRuleList { configuration.userContentController.add(list) }
        retainedPopup = child
        popup = WebPopup(webView: child)
        return child
    }
    func webViewDidClose(_ webView: WKWebView) { if popup?.webView === webView { closePopup() } }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        guard frame.isMainFrame, InstagramRouting.isInstagram(frame.request.url), !isClearing else {
            completionHandler(); return
        }
        enqueue(BrowserDialog(kind: .alert, source: ObjectIdentifier(webView), message: message, defaultText: "") { _, _ in completionHandler() })
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard frame.isMainFrame, InstagramRouting.isInstagram(frame.request.url), !isClearing else {
            completionHandler(false); return
        }
        enqueue(BrowserDialog(kind: .confirm, source: ObjectIdentifier(webView), message: message, defaultText: "") { accepted, _ in completionHandler(accepted) })
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        guard frame.isMainFrame, InstagramRouting.isInstagram(frame.request.url), !isClearing else {
            completionHandler(nil); return
        }
        enqueue(BrowserDialog(kind: .prompt, source: ObjectIdentifier(webView), message: prompt, defaultText: defaultText ?? "") { accepted, text in
            completionHandler(accepted ? text : nil)
        })
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void) {
        guard isPresentationAllowed, !isClearing,
              InstagramRouting.allowsBridge(host: origin.host, scheme: origin.protocol, port: origin.port,
                                            mainFrame: frame.isMainFrame) else {
            decisionHandler(.deny); return
        }
        // Prompt through WebKit and the OS only in response to a website capture request.
        decisionHandler(.prompt)
    }
}
