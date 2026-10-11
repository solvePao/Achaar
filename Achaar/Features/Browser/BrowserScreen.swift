import SwiftUI

struct BrowserScreen: View {
    @Bindable var browser: BrowserModel
    @Bindable var settings: AppSettings
    let appLock: AppLock
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    WebViewHost(webView: browser.webView)
                        .id(ObjectIdentifier(browser.webView))
                        .accessibilityIdentifier("instagram.web")
                    if browser.isLoading {
                        ProgressView(value: browser.progress)
                            .progressViewStyle(.linear)
                            .accessibilityLabel("Loading Instagram")
                    }
                    if let failure = browser.failure {
                        ContentUnavailableView {
                            Label("Unable to load Instagram", systemImage: "wifi.exclamationmark")
                        } description: { Text(failure) } actions: {
                            Button("Retry", systemImage: "arrow.clockwise", action: browser.refresh)
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                    }
                    if browser.isClearing {
                        ProgressView("Clearing website data…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.background)
                    }
                }
                NativeTabBar(selection: browser.selectedTab, onSelect: browser.select)
                    .frame(height: 49)
                    .disabled(browser.isClearing)
            }
            .navigationTitle(browser.selectedTab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.backward", action: browser.goBack)
                        .disabled(!browser.canGoBack || browser.isClearing)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Create", systemImage: "plus.app") { browser.perform(.create) }
                    Button("Activity", systemImage: "heart") { browser.perform(.activity) }
                    Menu {
                        Button("Refresh", systemImage: "arrow.clockwise", action: browser.refresh)
                        if let url = InstagramRouting.shareURL(browser.webView.url) {
                            ShareLink(item: url) { Label("Share page", systemImage: "square.and.arrow.up") }
                        }
                        Button("Original web interface", systemImage: "globe") {
                            settings.enhancements = false
                        }
                        Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    } label: { Label("More", systemImage: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsScreen(settings: settings, browser: browser, appLock: appLock)
            }
            .sheet(item: $browser.popup, onDismiss: browser.closePopup) { popup in
                NavigationStack {
                    WebViewHost(webView: popup.webView)
                        .navigationTitle("Instagram")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Back", systemImage: "chevron.backward") { popup.webView.goBack() }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done", action: browser.closePopup)
                            }
                        }
                }
            }
            .background {
                BrowserPresentationHost(browser: browser,
                    state: BrowserPresentationState(dialogID: browser.dialog?.id,
                        externalID: browser.externalRequest?.id,
                        destinationID: browser.externalDestination?.id,
                        notice: browser.notice, allowed: browser.isPresentationAllowed))
                    .frame(width: 0, height: 0)
            }
            .onChange(of: appLock.isUnlocked) { _, unlocked in
                if !unlocked { showingSettings = false }
            }

        }
    }
}
