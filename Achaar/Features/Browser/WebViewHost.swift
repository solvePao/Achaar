import SwiftUI
import WebKit
import SafariServices

struct BrowserPresentationState: Equatable {
    let dialogID: UUID?
    let externalID: UUID?
    let destinationID: UUID?
    let notice: String?
    let allowed: Bool
}

// Present above the current sheet, so web dialogs and outbound links also work
// when an Instagram popup or native Settings is already on screen.
struct BrowserPresentationHost: UIViewControllerRepresentable {
    let browser: BrowserModel
    let state: BrowserPresentationState

    func makeCoordinator() -> Coordinator { Coordinator(browser: browser) }
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.schedule(from: controller)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
        let browser: BrowserModel
        weak var anchor: UIViewController?
        private var activeController: UIViewController?
        private var active: BrowserPresentationState?
        private var transitioning = false

        init(browser: BrowserModel) { self.browser = browser }

        func schedule(from controller: UIViewController) {
            anchor = controller
            DispatchQueue.main.async { [weak self] in self?.presentNext() }
        }

        private func presentNext() {
            guard !transitioning, let anchor else { return }
            if let activeController, active != nil {
                if !activeRequestIsValid {
                    transitioning = true
                    activeController.dismiss(animated: false) { [weak self] in
                        self?.activeController = nil; self?.active = nil; self?.transitioning = false
                        self?.presentNext()
                    }
                }
                return
            }
            guard browser.isPresentationAllowed, !browser.isClearing,
                  let window = anchor.view.window, var presenter = window.rootViewController else { return }
            while let next = presenter.presentedViewController { presenter = next }
            guard !presenter.isBeingDismissed, !presenter.isBeingPresented,
                  !(presenter is UIAlertController) else { return }

            if let dialog = browser.dialog {
                let alert = UIAlertController(title: "Instagram", message: dialog.message, preferredStyle: .alert)
                if dialog.kind == .prompt { alert.addTextField { $0.text = dialog.defaultText } }
                if dialog.kind != .alert {
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self, weak alert] _ in
                        guard let alert else { return }
                        self?.finish(alert) { self?.browser.finishDialog(accepted: false) }
                    })
                }
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak alert] _ in
                    guard let alert else { return }
                    let text = alert.textFields?.first?.text
                    self?.finish(alert) { self?.browser.finishDialog(accepted: true, text: text) }
                })
                show(alert, from: presenter, state: BrowserPresentationState(dialogID: dialog.id,
                    externalID: nil, destinationID: nil, notice: nil, allowed: true))
            } else if let request = browser.externalRequest {
                let alert = UIAlertController(title: "Open external link?",
                    message: request.url.host ?? "Open this link in another app.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self, weak alert] _ in
                    guard let alert else { return }
                    self?.finish(alert) { self?.browser.externalRequest = nil }
                })
                alert.addAction(UIAlertAction(title: "Open", style: .default) { [weak self, weak alert] _ in
                    guard let alert else { return }
                    self?.finish(alert) {
                        self?.browser.externalDestination = request
                        self?.browser.externalRequest = nil
                    }
                })
                show(alert, from: presenter, state: BrowserPresentationState(dialogID: nil,
                    externalID: request.id, destinationID: nil, notice: nil, allowed: true))
            } else if let destination = browser.externalDestination {
                if ["https", "http"].contains(destination.url.scheme?.lowercased() ?? "") {
                    let safari = SFSafariViewController(url: destination.url)
                    safari.delegate = self
                    safari.dismissButtonStyle = .close
                    show(safari, from: presenter, state: BrowserPresentationState(dialogID: nil,
                        externalID: nil, destinationID: destination.id, notice: nil, allowed: true))
                    safari.presentationController?.delegate = self
                } else {
                    browser.externalDestination = nil
                    UIApplication.shared.open(destination.url, options: [:]) { [weak self] opened in
                        if !opened { Task { @MainActor in self?.browser.notice = "No installed app can open this link." } }
                    }
                }
            } else if let notice = browser.notice {
                let alert = UIAlertController(title: "Achaar", message: notice, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak alert] _ in
                    guard let alert else { return }
                    self?.finish(alert) { self?.browser.notice = nil }
                })
                show(alert, from: presenter, state: BrowserPresentationState(dialogID: nil,
                    externalID: nil, destinationID: nil, notice: notice, allowed: true))
            }
        }

        private var activeRequestIsValid: Bool {
            guard let active else { return false }
            if let id = active.dialogID { return browser.dialog?.id == id }
            if let id = active.externalID { return browser.externalRequest?.id == id }
            if let id = active.destinationID { return browser.externalDestination?.id == id }
            return browser.notice == active.notice
        }

        private func show(_ controller: UIViewController, from presenter: UIViewController,
                          state: BrowserPresentationState) {
            active = state
            activeController = controller
            transitioning = true
            presenter.present(controller, animated: true) { [weak self] in
                self?.transitioning = false
                self?.presentNext()
            }
        }

        private func finish(_ controller: UIViewController, action: @escaping () -> Void) {
            transitioning = true
            controller.dismiss(animated: true) { [weak self] in
                if self?.activeRequestIsValid == true { action() }
                self?.activeController = nil
                self?.active = nil
                self?.transitioning = false
                self?.presentNext()
            }
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            finish(controller) { [weak self] in self?.browser.externalDestination = nil }
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            if presentationController.presentedViewController === activeController {
                browser.externalDestination = nil
                activeController = nil
                active = nil
                transitioning = false
                presentNext()
            }
        }
    }
}
