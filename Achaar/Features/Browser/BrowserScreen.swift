import UIKit
import SwiftUI
import WebKit
import Observation

@MainActor
final class BrowserViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    let browser: BrowserModel
    let settings: AppSettings
    let appLock: AppLock
    private let content = UIView()
    private let usage = UsageTracker()
    private var usageTimer: Timer?
    private var launchCoverUntil = Date.distantPast
    private let brandName = UILabel()
    private let usageLabel = UILabel()
    private let lifetimeUsageLabel = UILabel()
    private let projectedUsageLabel = UILabel()
    private let reelSound = UIButton(type: .system)
    private let bar = InstagramNavigationPill()
    private let more = UIButton(type: .system)
    private let messageReactionButton = UIButton(type: .system)
    private var reactionRectPending = false
    private let conversationBack = UIButton(type: .system)
    private let activityButton = UIButton(type: .system)
    private let createButton = UIButton(type: .system)
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let cover = UIView()
    private let status = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let retry = UIButton(type: .system)
    private let unlock = UIButton(type: .system)
    private var embedded: WKWebView?
    private var withBar: NSLayoutConstraint!
    private var withoutBar: NSLayoutConstraint!
    private var moreBottom: NSLayoutConstraint!
    private var keyboardVisible = false
    private var active = false
    private var checkedRecovery = false
    private var recoveryRequired = false
    private var previousCompatibility: Bool
    private var previousEnhancements: Bool
    private var previousProtection: Bool
    private var previousWarm: Bool
    private var presentingID: String?
    private var menuTab: InstagramTab?
    private var menuShareURL: URL?
    private var capturingAvatar = false
    private var previousUnlocked: Bool

    init(browser: BrowserModel, settings: AppSettings, appLock: AppLock) {
        self.browser = browser; self.settings = settings; self.appLock = appLock
        previousEnhancements = settings.enhancements
        previousProtection = settings.blockTrackers
        previousCompatibility = settings.compatibilityScrolling
        previousWarm = settings.keepMessagesReady
        previousUnlocked = appLock.isUnlocked
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use model initializer") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 11 / 255, green: 16 / 255, blue: 20 / 255, alpha: 1) : .systemBackground }
        content.translatesAutoresizingMaskIntoConstraints = false
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.onSelect = { [weak self] tab in self?.browser.select(tab) }
        view.addSubview(content); view.addSubview(bar)
        withBar = content.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        withoutBar = content.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: 12),
            bar.heightAnchor.constraint(equalToConstant: 58)
        ])
        for (button, action) in [(createButton, WebAction.create), (activityButton, .activity)] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setImage(UIImage(systemName: action == .create ? "plus" : "heart",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .regular)), for: .normal)
            button.tintColor = .label
            button.accessibilityLabel = action.title
            button.addAction(UIAction { [weak self] _ in self?.browser.perform(action) }, for: .touchUpInside)
            view.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
                button.widthAnchor.constraint(equalToConstant: 44), button.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        var reactionConfig = UIButton.Configuration.glass()
        reactionConfig.image = UIImage(systemName: "face.smiling", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17))
        reactionConfig.cornerStyle = .capsule
        messageReactionButton.configuration = reactionConfig
        messageReactionButton.accessibilityIdentifier = "message.react"
        messageReactionButton.accessibilityLabel = "React to message"
        messageReactionButton.isHidden = true
        messageReactionButton.addAction(UIAction { [weak self] _ in
            self?.browser.webView.evaluateJavaScript("window.AchaarWeb?.openVisibleReaction() ?? false") { [weak self] value, _ in
                if value as? Bool != true { self?.browser.notice = "This message’s reaction control is no longer visible. Scroll to the message and try again." }
            }
        }, for: .touchUpInside)
        view.addSubview(messageReactionButton)
        conversationBack.translatesAutoresizingMaskIntoConstraints = false
        var backConfig = UIButton.Configuration.glass()
        backConfig.image = UIImage(systemName: "chevron.backward")
        backConfig.cornerStyle = .capsule
        conversationBack.configuration = backConfig
        conversationBack.accessibilityLabel = "Back to messages"
        conversationBack.addAction(UIAction { [weak self] _ in self?.browser.webView.endEditing(true); self?.browser.perform(.inbox) }, for: .touchUpInside)
        view.addSubview(conversationBack)
        NSLayoutConstraint.activate([
            conversationBack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            conversationBack.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
            conversationBack.widthAnchor.constraint(equalToConstant: 44), conversationBack.heightAnchor.constraint(equalToConstant: 44)
        ])
        createButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12).isActive = true
        activityButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12).isActive = true
        var config = UIButton.Configuration.glass()
        config.image = UIImage(systemName: "ellipsis")
        config.cornerStyle = .capsule
        more.configuration = config
        more.tintColor = .label
        more.accessibilityLabel = "More"
        more.showsMenuAsPrimaryAction = true
        more.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(more)
        moreBottom = more.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -10)
        NSLayoutConstraint.activate([
            more.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            more.widthAnchor.constraint(equalToConstant: 44), more.heightAnchor.constraint(equalToConstant: 44), moreBottom
        ])
        progress.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(progress)
        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: content.topAnchor), progress.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        var soundConfig = UIButton.Configuration.glass()
        soundConfig.cornerStyle = .capsule
        reelSound.configuration = soundConfig
        reelSound.translatesAutoresizingMaskIntoConstraints = false
        reelSound.accessibilityIdentifier = "reels.sound"
        reelSound.addAction(UIAction { [weak self] _ in self?.browser.toggleReelSound() }, for: .touchUpInside)
        view.addSubview(reelSound)
        NSLayoutConstraint.activate([
            reelSound.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            reelSound.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            reelSound.widthAnchor.constraint(equalToConstant: 44), reelSound.heightAnchor.constraint(equalToConstant: 44)
        ])
        cover.backgroundColor = UIColor(named: "LaunchBackground")
        cover.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(cover)
        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: content.topAnchor), cover.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            cover.leadingAnchor.constraint(equalTo: content.leadingAnchor), cover.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        status.numberOfLines = 0; status.textAlignment = .center
        status.font = .preferredFont(forTextStyle: .body); status.adjustsFontForContentSizeCategory = true
        retry.setTitle("Retry", for: .normal)
        retry.addAction(UIAction { [weak self] _ in self?.retryBrowsing() }, for: .touchUpInside)
        unlock.setTitle("Unlock", for: .normal)
        unlock.addAction(UIAction { [weak self] _ in self?.authenticate() }, for: .touchUpInside)
        let icon = UIImageView(image: UIImage(named: "BrandIcon"))
        icon.contentMode = .scaleAspectFit
        icon.layer.cornerRadius = 32; icon.clipsToBounds = true
        icon.widthAnchor.constraint(equalToConstant: 160).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 160).isActive = true
        brandName.text = "Achaar"; brandName.font = .preferredFont(forTextStyle: .largeTitle)
        brandName.textColor = .black; brandName.adjustsFontForContentSizeCategory = true
        for (label, identifier) in [(usageLabel, "usage.today"), (lifetimeUsageLabel, "usage.lifetime"),
                                    (projectedUsageLabel, "usage.projection")] {
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.textColor = .darkGray
            label.numberOfLines = 0; label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = true
            label.accessibilityIdentifier = identifier
        }
        status.textColor = .darkGray; spinner.color = .darkGray
        let statistics = UIStackView(arrangedSubviews: [usageLabel, lifetimeUsageLabel, projectedUsageLabel])
        statistics.axis = .vertical; statistics.spacing = 8; statistics.alignment = .fill
        let stack = UIStackView(arrangedSubviews: [icon, brandName, statistics, spinner, status, retry, unlock])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(scroll)
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(container)
        container.addSubview(stack)
        let viewportHeight = container.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        viewportHeight.priority = .defaultLow
        viewportHeight.isActive = true
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: cover.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: cover.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: cover.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: cover.trailingAnchor),
            container.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            container.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            statistics.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(memoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        observeState()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { cover.isHidden ? .default : .darkContent }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !conversationBack.isHidden { updateMessageReactionPosition() }
    }

    private func observeState() {
        withObservationTracking { render() } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeState() }
        }
    }

    private func render() {
        if settings.compatibilityScrolling != previousCompatibility {
            previousCompatibility = settings.compatibilityScrolling; browser.updateScrollingCompatibility()
        }
        if settings.enhancements != previousEnhancements {
            previousEnhancements = settings.enhancements; browser.updateEnhancements()
        }
        if settings.blockTrackers != previousProtection {
            previousProtection = settings.blockTrackers
            Task { await browser.updateProtection() }
        }
        if settings.keepMessagesReady != previousWarm {
            previousWarm = settings.keepMessagesReady; browser.updateWarmMessagesPreference()
        }
        let unlocked = !settings.appLock || appLock.isUnlocked
        if unlocked != previousUnlocked {
            previousUnlocked = unlocked
            browser.suspendMedia(!active || !unlocked)
            if unlocked && !recoveryRequired { Task { await browser.start() } }
        }
        overrideUserInterfaceStyle = settings.appearance == .system ? .unspecified : (settings.appearance == .dark ? .dark : .light)
        presentedViewController?.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        if embedded !== browser.webView {
            embedded?.removeFromSuperview()
            let web = browser.webView
            web.translatesAutoresizingMaskIntoConstraints = false
            web.accessibilityIdentifier = "instagram.web"
            content.insertSubview(web, at: 0)
            NSLayoutConstraint.activate([
                web.topAnchor.constraint(equalTo: content.topAnchor), web.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                web.leadingAnchor.constraint(equalTo: content.leadingAnchor), web.trailingAnchor.constraint(equalTo: content.trailingAnchor)
            ])
            embedded = web
        }
        let showBar = settings.enhancements && !browser.originalNavigationVisible && !browser.immersivePresentation && !browser.modalPresentation && !keyboardVisible
        if showBar {
            withoutBar.isActive = false; withBar.isActive = true
        } else {
            withBar.isActive = false; withoutBar.isActive = true
        }
        conversationBack.isHidden = !browser.immersivePresentation || browser.selectedTab != .messages || !unlocked || browser.isClearing || browser.failure != nil
        _ = browser.messageControlsRevision
        if browser.immersivePresentation && browser.selectedTab == .messages && unlocked && !browser.isClearing && browser.failure == nil {
            updateMessageReactionPosition()
        } else { messageReactionButton.isHidden = true }
        bar.isHidden = !showBar || recoveryRequired || !unlocked || browser.isClearing
        bar.isUserInteractionEnabled = unlocked && !recoveryRequired && !browser.isClearing && browser.isWebInterfaceReady
        bar.setEnabled(bar.isUserInteractionEnabled)
        bar.select(browser.selectedTab)
        let showFeedActions = showBar && browser.selectedTab == .home && browser.isWebInterfaceReady
            && browser.webView.url?.path == "/" && unlocked && !recoveryRequired && browser.failure == nil
        createButton.isHidden = !showFeedActions; activityButton.isHidden = !showFeedActions
        moreBottom.constant = showBar ? -10 : 39
        more.isHidden = browser.immersivePresentation || browser.modalPresentation || keyboardVisible || (showBar && !recoveryRequired && browser.failure == nil)
        more.isEnabled = unlocked && !browser.isClearing
        let shareURL = InstagramRouting.shareURL(browser.webView.url)
        if more.menu == nil || menuTab != browser.selectedTab || menuShareURL != shareURL {
            menuTab = browser.selectedTab; menuShareURL = shareURL
            more.menu = actionMenu()
            bar.profileButton.menu = more.menu
        }
        if browser.isClearing || browser.webView.url?.path.hasPrefix("/accounts/") == true {
            bar.profileImage = nil
        } else if unlocked && browser.isWebInterfaceReady && [.home, .profile].contains(browser.selectedTab) {
            captureNavigationAvatar()
        }
        progress.progress = Float(browser.progress)
        progress.isHidden = !browser.isLoading
        refreshUsageLabels()
        let waiting = (settings.enhancements && !browser.isWebInterfaceReady) || browser.isLoading || Date() < launchCoverUntil
        cover.isHidden = unlocked && !recoveryRequired && !waiting && !browser.isClearing && browser.failure == nil
        reelSound.isHidden = !cover.isHidden || browser.selectedTab != .reels || !settings.enhancements || browser.modalPresentation || keyboardVisible
        reelSound.configuration?.image = UIImage(systemName: browser.reelsMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        reelSound.accessibilityLabel = browser.reelsMuted ? "Unmute Reels" : "Mute Reels"
        view.backgroundColor = cover.isHidden ? UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 11 / 255, green: 16 / 255, blue: 20 / 255, alpha: 1) : .systemBackground } : UIColor(named: "LaunchBackground")
        setNeedsStatusBarAppearanceUpdate()
        if !cover.isHidden {
            bar.isHidden = true; more.isHidden = true; createButton.isHidden = true; activityButton.isHidden = true
            conversationBack.isHidden = true; messageReactionButton.isHidden = true; progress.isHidden = true
        }
        embedded?.isUserInteractionEnabled = cover.isHidden
        embedded?.accessibilityElementsHidden = !cover.isHidden
        if !unlocked { status.text = appLock.error ?? "Achaar is locked" }
        else if recoveryRequired { status.text = "Browsing stopped unexpectedly more than once. Retry when ready." }
        else if let failure = browser.failure { status.text = failure }
        else { status.text = browser.isClearing ? "Clearing website data…" : "Opening Instagram…" }
        let failed = unlocked && (browser.failure != nil || recoveryRequired)
        retry.isHidden = !failed
        unlock.isHidden = unlocked
        unlock.isEnabled = !appLock.isAuthenticating
        if !cover.isHidden && unlocked && !failed { spinner.startAnimating() } else { spinner.stopAnimating() }
        presentBrowserRequest()
    }

    // The website returns only normalized bounds for a recognized reaction
    // control. Its DOM reference and message contents remain inside WebKit.
    private func updateMessageReactionPosition() {
        guard !reactionRectPending else { return }
        reactionRectPending = true
        let web = browser.webView
        web.evaluateJavaScript("window.AchaarWeb?.setViewportHeight(\(Int(web.bounds.height))); window.AchaarWeb?.reactionControlRect() ?? null") { [weak self, weak web] value, _ in
            guard let self else { return }
            self.reactionRectPending = false
            guard let web, web === self.browser.webView, self.browser.immersivePresentation, self.browser.selectedTab == .messages,
                  !self.browser.isClearing, (!self.settings.appLock || self.appLock.isUnlocked), let rect = value as? [String: Double],
                  let x = rect["x"], let y = rect["y"], let width = rect["width"], let height = rect["height"],
                  [x,y,width,height].allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }), width > 0, height > 0, x + width <= 1, y + height <= 1 else {
                self.messageReactionButton.isHidden = true; return
            }
            let center = web.convert(CGPoint(x: (x + width/2) * web.bounds.width, y: (y + height/2) * web.bounds.height), to: self.view)
            self.messageReactionButton.frame = CGRect(x: center.x - 22, y: center.y - 22, width: 44, height: 44)
            self.messageReactionButton.isHidden = false
        }
    }

    private func captureNavigationAvatar() {
        guard bar.profileImage == nil, !capturingAvatar else { return }
        capturingAvatar = true
        let web = browser.webView, url = web.url
        web.evaluateJavaScript("window.AchaarWeb?.navigationAvatarRect() ?? null") { [weak self, weak web] value, _ in
            guard let self, let web else { return }
            guard web === self.browser.webView, web.url == url, !self.browser.isClearing,
                  let bounds = value as? [String: Double],
                  let x = bounds["x"], let y = bounds["y"], let width = bounds["width"], let height = bounds["height"],
                  [x, y, width, height].allSatisfy(\.isFinite), width >= 20, width <= 180, height >= 20, height <= 180 else {
                self.capturingAvatar = false; return
            }
            let rect = CGRect(x: x, y: y, width: width, height: height)
            guard web.bounds.contains(rect) else { self.capturingAvatar = false; return }
            let configuration = WKSnapshotConfiguration()
            configuration.rect = rect
            configuration.snapshotWidth = 78
            web.takeSnapshot(with: configuration) { [weak self, weak web] image, _ in
                guard let self else { return }
                self.capturingAvatar = false
                guard let web, web === self.browser.webView, web.url == url,
                      !self.browser.isClearing, let image else { return }
                let icon = UIGraphicsImageRenderer(size: CGSize(width: 26, height: 26)).image { _ in
                    image.draw(in: CGRect(x: 0, y: 0, width: 26, height: 26))
                }
                self.bar.profileImage = icon.withRenderingMode(.alwaysOriginal)
                self.bar.select(self.browser.selectedTab)
            }
        }
    }

    private func action(_ title: String, symbol: String, handler: @escaping () -> Void) -> UIAction {
        UIAction(title: title, image: UIImage(systemName: symbol)) { _ in handler() }
    }
    private func webAction(_ action: WebAction) -> UIAction {
        self.action(action.title, symbol: action.symbol) { [weak self] in self?.browser.perform(action) }
    }
    private func actionMenu() -> UIMenu {
        let posts = UIMenu(title: "Visible post", image: UIImage(systemName: "rectangle.stack"), children:
            [WebAction.like, .save, .comments, .sharePost].map(webAction))
        let messages = UIMenu(title: "Message shortcuts", image: UIImage(systemName: "paperplane"), children:
            [WebAction.inbox, .newMessage, .requests].map(webAction))
        let profile = UIMenu(title: "Profile shortcuts", image: UIImage(systemName: "person.crop.circle"), children:
            [WebAction.profile, .saved, .archive, .accountSettings].map(webAction))
        let instagram = UIMenu(title: "Instagram", options: .displayInline, children: [webAction(.activity), webAction(.search), posts, messages, profile])
        var utilities: [UIMenuElement] = [action("Back", symbol: "chevron.backward") { [weak self] in self?.browser.goBack() },
            action("Refresh", symbol: "arrow.clockwise") { [weak self] in self?.browser.refresh() },
            action("Original web interface", symbol: "globe") { [weak self] in self?.settings.enhancements = false },
            action("Open Instagram in Safari", symbol: "safari") { UIApplication.shared.open(InstagramRouting.home) }]
        if let url = InstagramRouting.shareURL(browser.webView.url) {
            utilities.insert(action("Share page", symbol: "square.and.arrow.up") { [weak self] in
                guard let self else { return }
                let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                sheet.popoverPresentationController?.sourceView = self.more
                self.present(sheet, animated: true)
            }, at: 2)
        }
        return UIMenu(children: [instagram,
            UIMenu(title: "Browser controls", image: UIImage(systemName: "globe"), children: utilities),
            action("Settings", symbol: "gearshape") { [weak self] in self?.showSettings() }])
    }

    private func showSettings() {
        let host = UIHostingController(rootView: SettingsScreen(settings: settings, browser: browser, appLock: appLock,
            onDone: { [weak self] in self?.dismiss(animated: true) }))
        host.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        present(host, animated: true)
    }

    private func refreshUsageLabels() {
        let summary = usage.summary()
        usageLabel.text = summary.todayLabel
        lifetimeUsageLabel.text = summary.lifetimeLabel
        projectedUsageLabel.text = summary.projectionLabel
    }

    func activate() {
        active = true
        usage.begin()
        launchCoverUntil = Date().addingTimeInterval(0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in self?.render() }
        usageTimer?.invalidate()
        usageTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.usage.record(); self?.refreshUsageLabels() }
        }
        if !checkedRecovery {
            checkedRecovery = true
            recoveryRequired = BrowsingRecovery.beginSession()
        } else { BrowsingRecovery.markActive() }
        render()
        guard !recoveryRequired else { return }
        browser.suspendMedia(settings.appLock && !appLock.isUnlocked)
        if settings.appLock && !appLock.isUnlocked { authenticate() }
        else { Task { await browser.start() } }
    }
    private func retryBrowsing() {
        if recoveryRequired {
            recoveryRequired = false
            render()
            if settings.appLock && !appLock.isUnlocked { authenticate() }
            else { Task { await browser.start() } }
        } else { browser.refresh() }
    }
    private func authenticate() {
        Task {
            if await appLock.authenticate() {
                browser.suspendMedia(!active)
                if !recoveryRequired { await browser.start() }
            }
        }
    }
    func deactivate() { usage.end(); usageTimer?.invalidate(); usageTimer = nil; active = false; BrowsingRecovery.endSession(); browser.suspendMedia(true) }
    func enterBackground() {
        appLock.lock(enabled: settings.appLock)
        if settings.appLock { browser.prepareForLock(); presentedViewController?.dismiss(animated: false) }
        Task { await browser.maintainCache() }
    }
    @objc private func keyboardChanged(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = view.window else { return }
        let local = view.convert(frame, from: window.screen.coordinateSpace)
        keyboardVisible = local.intersects(view.bounds) && local.minY < view.bounds.maxY - view.safeAreaInsets.bottom - 1
        render()
    }
    @objc private func memoryWarning() { browser.releaseInactivePages() }

    // Existing native dialog/external-link coordinator remains shared with popup
    // windows. It does not host the browser or sit in its gesture ancestry.
    private lazy var presentationCoordinator = BrowserPresentationHost.Coordinator(browser: browser)
    private func presentBrowserRequest() {
        _ = browser.dialog?.id; _ = browser.externalRequest?.id; _ = browser.externalDestination?.id
        _ = browser.notice; _ = browser.isPresentationAllowed
        presentationCoordinator.schedule(from: self)
        if let popup = browser.popup, presentingID == nil, presentedViewController == nil {
            let host = PopupViewController(popup: popup, browser: browser)
            presentingID = popup.id.uuidString
            host.presentationController?.delegate = self
            present(host, animated: true)
        } else if browser.popup == nil && presentingID != nil {
            presentedViewController?.dismiss(animated: true)
            presentingID = nil
        }
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        presentingID = nil; browser.closePopup()
    }
}

@MainActor
private final class PopupViewController: UIViewController {
    let popup: WebPopup
    let browser: BrowserModel
    init(popup: WebPopup, browser: BrowserModel) {
        self.popup = popup; self.browser = browser
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use popup initializer") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let close = UIButton(type: .system)
        close.setTitle("Done", for: .normal)
        close.addAction(UIAction { [weak self] _ in self?.browser.closePopup() }, for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        popup.webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(popup.webView); view.addSubview(close)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), close.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            close.heightAnchor.constraint(equalToConstant: 44),
            popup.webView.topAnchor.constraint(equalTo: close.bottomAnchor), popup.webView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            popup.webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), popup.webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
    }
}

// The screenshots use a floating 58-point pill rather than a full-width tab
// shelf. Keep it native, keyboard-aware, and outside WebKit's touch ancestry.
@MainActor
private final class InstagramNavigationPill: UIView {
    var onSelect: ((InstagramTab) -> Void)?
    private var buttons: [InstagramTab: UIButton] = [:]
    var profileImage: UIImage?
    var profileButton: UIButton { buttons[.profile]! }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.layer.cornerRadius = 29
        glass.clipsToBounds = true
        addSubview(glass)
        let stack = UIStackView()
        stack.axis = .horizontal; stack.distribution = .fillEqually; stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.addSubview(stack)
        glass.contentView.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? .black.withAlphaComponent(0.55) : .white.withAlphaComponent(0.5) }
        for tab in InstagramTab.displayOrder {
            let button = UIButton(type: .system)
            button.accessibilityIdentifier = "tab.\(tab.rawValue)"
            button.accessibilityLabel = tab.title
            button.tintColor = .label
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(tab) }, for: .touchUpInside)
            buttons[tab] = button
            stack.addArrangedSubview(button)
        }
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: topAnchor), glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor), glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: glass.contentView.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor, constant: -5),
            stack.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -5)
        ])
        accessibilityLabel = "Instagram navigation"
        select(.home)
    }
    required init?(coder: NSCoder) { fatalError("Use programmatic initializer") }
    func setEnabled(_ enabled: Bool) { buttons.values.forEach { $0.isEnabled = enabled } }
    func select(_ tab: InstagramTab) {
        for (destination, button) in buttons {
            button.isSelected = destination == tab
            let base = destination == .reels ? "play.square" : destination.symbol
            let filled = destination == .home || destination == .messages
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: destination == tab && filled ? base + ".fill" : base,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 21, weight: .regular))
            if destination == .profile, let profileImage {
                config.image = profileImage
                button.imageView?.layer.cornerRadius = 13
                button.imageView?.clipsToBounds = true
            }
            config.baseForegroundColor = .label
            config.contentInsets = .zero
            config.background.cornerRadius = 24
            config.background.backgroundColor = destination == tab ? .secondarySystemFill : .clear
            button.configuration = config
            button.accessibilityHint = destination == .profile ? "Long press for navigation options and Achaar Settings" : nil
        }
    }
}
