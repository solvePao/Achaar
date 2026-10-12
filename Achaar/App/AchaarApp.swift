import UIKit

// The browsing surface has a UIKit root: no SwiftUI hosting recognizers sit
// above WebKit's scrolling view. SwiftUI remains confined to Settings sheets.
@main
@MainActor
final class AchaarApp: UIResponder, UIApplicationDelegate {
    let settings = AppSettings()
    lazy var browser = BrowserModel(settings: settings)
    lazy var appLock = AppLock(enabled: settings.appLock)
    private var privacyShield: PrivacyShield?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // A SwiftUI-created session can survive an app update. Rebind its
        // delegate without deleting the website store or signing the user out.
        for session in application.openSessions {
            session.configuration.delegateClass = AchaarSceneDelegate.self
        }
        privacyShield = PrivacyShield(settings: settings)
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
        configuration.delegateClass = AchaarSceneDelegate.self
        return configuration
    }
}

@MainActor
final class AchaarSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var screen: BrowserViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene, let app = UIApplication.shared.delegate as? AchaarApp else { return }
        let controller = BrowserViewController(browser: app.browser, settings: app.settings, appLock: app.appLock)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        self.window = window
        screen = controller
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) { screen?.activate() }
    func sceneWillResignActive(_ scene: UIScene) { screen?.deactivate() }
    func sceneDidEnterBackground(_ scene: UIScene) { screen?.enterBackground() }
}
