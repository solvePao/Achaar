import LocalAuthentication
import UIKit
import Observation

@MainActor @Observable
final class AppLock {
    private(set) var isUnlocked: Bool
    private(set) var isAuthenticating = false
    var error: String?
    private var context: LAContext?
    private var generation = 0

    init(enabled: Bool) { isUnlocked = !enabled }

    func lock(enabled: Bool) {
        generation += 1
        context?.invalidate()
        context = nil
        isAuthenticating = false
        isUnlocked = !enabled
        error = nil
    }

    func authenticate() async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        error = nil
        let token = generation
        let attempt = LAContext()
        context = attempt
        defer { if token == generation { isAuthenticating = false; context = nil } }
        do {
            let accepted = try await attempt.evaluatePolicy(.deviceOwnerAuthentication,
                                                           localizedReason: "Unlock your Instagram session in Achaar.")
            guard token == generation else { return false }
            isUnlocked = accepted
            return accepted
        } catch {
            guard token == generation else { return false }
            self.error = "Could not unlock. Try again using Face ID or your device passcode."
            return false
        }
    }
}

// A cover attached directly to the window also obscures presented sheets and Safari.
// A SwiftUI overlay in the underlying screen alone would miss those surfaces.
@MainActor
final class PrivacyShield: NSObject {
    private let settings: AppSettings
    private var covers: [UIWindow: UIView] = [:]

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(coverWindows),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uncoverWindows),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func coverWindows() {
        guard settings.obscureAppSwitcher || settings.appLock else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows where !window.isHidden {
                guard covers[window] == nil else { continue }
                let cover = UIView(frame: window.bounds)
                cover.backgroundColor = .systemBackground
                cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                let label = UILabel()
                label.text = "Achaar"
                label.font = .preferredFont(forTextStyle: .largeTitle)
                label.textColor = .label
                label.translatesAutoresizingMaskIntoConstraints = false
                cover.addSubview(label)
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
                ])
                window.addSubview(cover)
                covers[window] = cover
            }
        }
    }

    @objc private func uncoverWindows() {
        covers.values.forEach { $0.removeFromSuperview() }
        covers.removeAll()
    }
}
