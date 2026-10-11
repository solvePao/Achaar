import SwiftUI

struct SettingsScreen: View {
    @Bindable var settings: AppSettings
    @Bindable var browser: BrowserModel
    @Bindable var appLock: AppLock
    @Environment(\.dismiss) private var dismiss
    @State private var clearingSession = false
    @State private var clearingCache = false
    @State private var authenticating = false
    @State private var lockError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Open on", selection: $settings.startupTab) {
                        ForEach(InstagramTab.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Navigation haptics", isOn: $settings.haptics)
                    Toggle("Web enhancements", isOn: $settings.enhancements)
                } header: { Text("Appearance & navigation") } footer: {
                    Text("Enhancements adjust the website and hide duplicate bottom navigation only when it is recognized. Switch off to restore Instagram’s original interface.")
                }
                Section {
                    Toggle("Face ID / passcode lock", isOn: Binding(
                        get: { settings.appLock }, set: { enabled in
                            Task {
                                authenticating = true
                                let accepted = await appLock.authenticate()
                                authenticating = false
                                if accepted { settings.appLock = enabled }
                                else { lockError = appLock.error }
                            }
                        }))
                        .disabled(authenticating)
                    Toggle("Hide app-switcher preview", isOn: $settings.obscureAppSwitcher)
                    Toggle("Confirm external links", isOn: $settings.confirmExternalLinks)
                    LabeledContent("Camera & microphone") {
                        Link("iOS Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    }
                } header: { Text("Local privacy") } footer: {
                    Text("Achaar has no backend or analytics and never reads your password. Instagram still receives your activity and stores its own website data. Device permissions are requested only when a web feature needs them.")
                }
                Section {
                    Toggle("Block known third-party trackers", isOn: $settings.blockTrackers)
                } header: { Text("Extra protection") } footer: {
                    Text("Optional and off by default. Blocks a small list of Google Analytics and DoubleClick requests. This does not block Instagram’s own tracking or remove ads. Changing this reloads Instagram and may discard unsaved work. Switch it off if a feature stops working.")
                }
                Section {
                    Button("Clear cached files") { clearingCache = true }
                    Button("Clear local session & sign out", role: .destructive) { clearingSession = true }
                } header: { Text("Website data") } footer: {
                    Text("Clearing cache preserves cookies and login. Clearing the local session removes Instagram cookies, storage and cached data from Achaar; it does not sign you out on other devices.")
                }
                Section("About Achaar") {
                    LabeledContent("Version", value: "1.0 (1)")
                    Text("Personal Instagram web wrapper. Features depend on Instagram’s website and your account. Background notifications and full official-app parity are not available.")
                    Link("Instagram help", destination: URL(string: "https://help.instagram.com/")!)
                }
            }
            .disabled(browser.isClearing)
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Clear all local Instagram data?", isPresented: $clearingSession, titleVisibility: .visible) {
                Button("Clear session", role: .destructive) {
                    Task { await browser.clearWebsiteData(includeSession: true) }
                }
            } message: { Text("You will need to sign in again. Unsaved website drafts may be lost.") }
            .confirmationDialog("Clear cached website files?", isPresented: $clearingCache, titleVisibility: .visible) {
                Button("Clear cache") { Task { await browser.clearWebsiteData(includeSession: false) } }
            } message: { Text("Instagram will reload. Your login will be kept, but unsaved work may be lost.") }
            .alert("Device authentication", isPresented: Binding(
                get: { lockError != nil }, set: { if !$0 { lockError = nil } }
            )) { Button("OK", role: .cancel) { lockError = nil } }
            message: { Text(lockError ?? "") }
        }
    }
}
