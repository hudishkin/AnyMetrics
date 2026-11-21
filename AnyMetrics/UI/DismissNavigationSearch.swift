import SwiftUI
import UIKit

/// The catalog search uses `displayMode: .always`, so a pushed screen keeps that field under the title.
struct DismissNavigationSearch: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.removeSearch()
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            removeSearch()
            DispatchQueue.main.async { [weak self] in
                self?.removeSearch()
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            removeSearch()
        }

        func removeSearch() {
            guard let navigation = view.enclosingNavigationController(),
                  let top = navigation.topViewController,
                  view.isDescendant(of: top.view) else { return }
            guard top.navigationItem.searchController != nil else { return }
            top.navigationItem.searchController = nil
            navigation.navigationBar.setNeedsLayout()
        }
    }
}

private extension UIView {
    func enclosingNavigationController() -> UINavigationController? {
        var responder: UIResponder? = self
        while let next = responder {
            if let navigation = next as? UINavigationController { return navigation }
            if let controller = next as? UIViewController, let navigation = controller.navigationController {
                return navigation
            }
            responder = next.next
        }
        return nil
    }
}
