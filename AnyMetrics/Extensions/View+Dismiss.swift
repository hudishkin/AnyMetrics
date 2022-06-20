//
//  View+Dismiss.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 17.06.2022.
//

import SwiftUI

class ModalHostingController<Content: View>: UIHostingController<Content>, UIAdaptivePresentationControllerDelegate {
    var canDismissSheet: Binding<Bool> = .constant(true)
    var onDismissalAttempt: (() -> ())?

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        parent?.presentationController?.delegate = self
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        canDismissSheet.wrappedValue
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        onDismissalAttempt?()
    }
}

struct ModalView<T: View>: UIViewControllerRepresentable {
    let view: T
    let canDismissSheet: Binding<Bool>
    let onDismissalAttempt: (() -> ())?

    func makeUIViewController(context: Context) -> ModalHostingController<T> {
        let controller = ModalHostingController(rootView: view)
        controller.canDismissSheet = canDismissSheet
        controller.onDismissalAttempt = onDismissalAttempt
        return controller
    }

    func updateUIViewController(_ uiViewController: ModalHostingController<T>, context: Context) {
        uiViewController.rootView = view
        uiViewController.canDismissSheet = canDismissSheet
        uiViewController.onDismissalAttempt = onDismissalAttempt
    }
}

extension View {
    func interactiveDismiss(canDismissSheet: Binding<Bool>, onDismissalAttempt: (() -> ())? = nil) -> some View {
        ModalView(
            view: self,
            canDismissSheet: canDismissSheet,
            onDismissalAttempt: onDismissalAttempt
        ).edgesIgnoringSafeArea(.all)
    }
}
