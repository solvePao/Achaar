import SwiftUI

@main
struct AchaarApp: App {
    @State private var settings: AppSettings
    @State private var browser: BrowserModel
    @State private var appLock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    private let privacyShield: PrivacyShield

    init() {
        let settings = AppSettings()
        privacyShield = PrivacyShield(settings: settings)
        _settings = State(initialValue: settings)
        _browser = State(initialValue: BrowserModel(settings: settings))
        _appLock = State(initialValue: AppLock(enabled: settings.appLock))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                BrowserScreen(browser: browser, settings: settings, appLock: appLock)
                    .allowsHitTesting(!settings.appLock || appLock.isUnlocked)
                    .accessibilityHidden(settings.appLock && !appLock.isUnlocked)
                if settings.appLock && !appLock.isUnlocked {
                    lockScreen
                }
                if scenePhase != .active && (settings.obscureAppSwitcher || settings.appLock) {
                    privacyCover
                }
            }
            .preferredColorScheme(settings.appearance.colorScheme)
            .task {
                if settings.appLock && !appLock.isUnlocked { _ = await appLock.authenticate() }
                if !settings.appLock || appLock.isUnlocked { await browser.start() }
            }
            .onChange(of: settings.enhancements) { _, _ in browser.updateEnhancements() }
            .onChange(of: settings.blockTrackers) { _, _ in Task { await browser.updateProtection() } }
            .onChange(of: appLock.isUnlocked) { _, unlocked in
                browser.suspendMedia(scenePhase != .active || (settings.appLock && !unlocked))
                if unlocked { Task { await browser.start() } }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    appLock.lock(enabled: settings.appLock)
                    if settings.appLock { browser.prepareForLock() }
                }
                browser.suspendMedia(phase != .active || (settings.appLock && !appLock.isUnlocked))
            }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Achaar is locked").font(.title2.bold())
            Text("Unlock to return to your Instagram session.").foregroundStyle(.secondary)
            Button("Unlock", systemImage: "faceid") {
                Task {
                    if await appLock.authenticate() {
                        browser.suspendMedia(scenePhase != .active)
                        await browser.start()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appLock.isAuthenticating)
            if let error = appLock.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var privacyCover: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill").font(.largeTitle).foregroundStyle(.tint)
            Text("Achaar").font(.title.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .ignoresSafeArea()
        .accessibilityLabel("Achaar privacy screen")
    }
}
