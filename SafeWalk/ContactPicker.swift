import SwiftUI
import ContactsUI

struct ContactPicker: UIViewControllerRepresentable {

    var onContactSelected: (String, String) -> Void

    func makeUIViewController(
        context: Context
    ) -> CNContactPickerViewController {

        let picker = CNContactPickerViewController()

        picker.delegate = context.coordinator

        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey
        ]

        return picker
    }

    func updateUIViewController(
        _ uiViewController: CNContactPickerViewController,
        context: Context
    ) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }


    class Coordinator:
        NSObject,
        CNContactPickerDelegate {

        let parent: ContactPicker

        init(parent: ContactPicker) {
            self.parent = parent
        }

        func contactPicker(
            _ picker: CNContactPickerViewController,
            didSelect contact: CNContact
        ) {

            let name = CNContactFormatter.string(
                from: contact,
                style: .fullName
            ) ?? "Emergency Contact"

            guard let phoneNumber =
                    contact.phoneNumbers.first?
                        .value
                        .stringValue
            else {
                return
            }

            parent.onContactSelected(
                name,
                phoneNumber
            )
        }
    }
}
