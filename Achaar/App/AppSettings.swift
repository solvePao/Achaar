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
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    var enhancements: Bool { didSet { defaults.set(enhancements, forKey: "enhancements") } }
    var appLock: Bool { didSet { defaults.set(appLock, forKey: "appLock") } }
    var obscureAppSwitcher: Bool { didSet { defaults.set(obscureAppSwitcher, forKey: "obscureAppSwitcher") } }
    var confirmExternalLinks: Bool { didSet { defaults.set(confirmExternalLinks, forKey: "confirmExternalLinks") } }
    var blockTrackers: Bool { didSet { defaults.set(blockTrackers, forKey: "blockTrackers") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        startupTab = InstagramTab(rawValue: defaults.string(forKey: "startupTab") ?? "") ?? .home
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        enhancements = defaults.object(forKey: "enhancements") as? Bool ?? true
        appLock = defaults.bool(forKey: "appLock")
        obscureAppSwitcher = defaults.object(forKey: "obscureAppSwitcher") as? Bool ?? true
        confirmExternalLinks = defaults.object(forKey: "confirmExternalLinks") as? Bool ?? true
        blockTrackers = defaults.bool(forKey: "blockTrackers")
    }
}
