import SwiftUI
import MessageUI

struct MessageComposer: UIViewControllerRepresentable {

    let recipients: [String]
    let body: String

    @Environment(\.dismiss)
    private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(
            dismiss: dismiss
        )
    }

    func makeUIViewController(
        context: Context
    ) -> MFMessageComposeViewController {

        let controller =
            MFMessageComposeViewController()

        controller.messageComposeDelegate =
            context.coordinator

        controller.recipients =
            recipients

        controller.body =
            body

        return controller
    }

    func updateUIViewController(
        _ uiViewController: MFMessageComposeViewController,
        context: Context
    ) {
    }


    final class Coordinator:
        NSObject,
        MFMessageComposeViewControllerDelegate {

        let dismiss: DismissAction

        init(
            dismiss: DismissAction
        ) {
            self.dismiss = dismiss
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result:
                MessageComposeResult
        ) {

            dismiss()
        }
    }
}
