import SwiftUI
import Observation

@MainActor @Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var colorScheme: ColorScheme? {
            switch self { case .system: nil; case .light: .light; case .dark: .dark }
        }
    }

    private let defaults: UserDefaults
    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var startupTab: InstagramTab { didSet { defaults.set(startupTab.rawValue, forKey: "startupTab") } }
    var nativeScreens: Bool { didSet { defaults.set(nativeScreens, forKey: "nativeScreens") } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    var enhancements: Bool { didSet { defaults.set(enhancements, forKey: "enhancements") } }
    var keepMessagesReady: Bool { didSet { defaults.set(keepMessagesReady, forKey: "keepMessagesReady") } }
    var compatibilityScrolling: Bool { didSet { defaults.set(compatibilityScrolling, forKey: "compatibilityScrolling") } }
    var cacheBudgetMB: Int { didSet { defaults.set(cacheBudgetMB, forKey: "cacheBudgetMB") } }
    static let cacheBudgets = [0, 64, 128, 256, 512, 1024]
    var appLock: Bool { didSet { defaults.set(appLock, forKey: "appLock") } }
    var obscureAppSwitcher: Bool { didSet { defaults.set(obscureAppSwitcher, forKey: "obscureAppSwitcher") } }
    var confirmExternalLinks: Bool { didSet { defaults.set(confirmExternalLinks, forKey: "confirmExternalLinks") } }
    var blockTrackers: Bool { didSet { defaults.set(blockTrackers, forKey: "blockTrackers") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        startupTab = InstagramTab(rawValue: defaults.string(forKey: "startupTab") ?? "") ?? .home
        nativeScreens = defaults.object(forKey: "nativeScreens") == nil ? true : defaults.bool(forKey: "nativeScreens")
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        enhancements = defaults.object(forKey: "enhancements") as? Bool ?? true
        // Re-enable integration once for the upgraded navigation implementation.
        // The explicit Original web interface recovery switch still persists.
        if defaults.integer(forKey: "navigationIntegrationVersion") < 2 {
            enhancements = true
            defaults.set(true, forKey: "enhancements")
            defaults.set(2, forKey: "navigationIntegrationVersion")
        }
        keepMessagesReady = defaults.object(forKey: "keepMessagesReady") as? Bool ?? true
        compatibilityScrolling = defaults.object(forKey: "compatibilityScrolling") as? Bool ?? true
        let budget = defaults.object(forKey: "cacheBudgetMB") as? Int ?? 256
        cacheBudgetMB = Self.cacheBudgets.contains(budget) ? budget : 256
        appLock = defaults.bool(forKey: "appLock")
        obscureAppSwitcher = defaults.object(forKey: "obscureAppSwitcher") as? Bool ?? true
        confirmExternalLinks = defaults.object(forKey: "confirmExternalLinks") as? Bool ?? true
        blockTrackers = defaults.bool(forKey: "blockTrackers")
    }
}

// Records only foreground lifecycle state, never website data. An interrupted
// session can be a crash or an OS termination; do not claim to diagnose it.
enum BrowsingRecovery {
    static func beginSession(in defaults: UserDefaults = .standard) -> Bool {
        let count = defaults.bool(forKey: "browsingWasActive")
            ? defaults.integer(forKey: "browsingInterruptedStarts") + 1 : 0
        defaults.set(count, forKey: "browsingInterruptedStarts")
        defaults.set(true, forKey: "browsingWasActive")
        return count >= 2
    }
    static func markActive(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: "browsingWasActive")
    }
    static func endSession(in defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: "browsingWasActive")
        defaults.set(0, forKey: "browsingInterruptedStarts")
    }
}
