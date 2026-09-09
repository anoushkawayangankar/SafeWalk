import SwiftUI

struct EmergencyContactView: View {

    @AppStorage("emergencyContactName")
    private var emergencyContactName = ""

    @AppStorage("emergencyContactPhone")
    private var emergencyContactPhone = ""

    @State private var showContactPicker = false

    var body: some View {

        Form {

            // MARK: - Saved Contact

            Section("Trusted Contact") {

                if !emergencyContactName.isEmpty &&
                    !emergencyContactPhone.isEmpty {

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {

                        Label(
                            emergencyContactName,
                            systemImage: "person.crop.circle.fill"
                        )
                        .font(.headline)

                        Text(emergencyContactPhone)
                            .foregroundStyle(.secondary)
                    }

                } else {

                    Text(
                        "No emergency contact has been set yet."
                    )
                    .foregroundStyle(.secondary)
                }
            }


            // MARK: - Choose From Contacts

            Section {

                Button {

                    showContactPicker = true

                } label: {

                    Label(
                        "Choose From Contacts",
                        systemImage:
                            "person.crop.circle.badge.plus"
                    )
                }

            } footer: {

                Text(
                    "Select a trusted person from your iPhone Contacts."
                )
            }


            // MARK: - Manual Entry

            Section(
                "Or Enter Manually"
            ) {

                TextField(
                    "Contact name",
                    text:
                        $emergencyContactName
                )

                TextField(
                    "Phone number",
                    text:
                        $emergencyContactPhone
                )
                .keyboardType(
                    .phonePad
                )
            }


            // MARK: - Status

            Section {

                if emergencyContactName.isEmpty ||
                    emergencyContactPhone.isEmpty {

                    Label(
                        "Emergency contact incomplete",
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)

                } else {

                    Label(
                        "\(emergencyContactName) is your emergency contact.",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
            }


            // MARK: - Remove Contact

            if !emergencyContactName.isEmpty ||
                !emergencyContactPhone.isEmpty {

                Section {

                    Button(
                        role: .destructive
                    ) {

                        emergencyContactName = ""
                        emergencyContactPhone = ""

                    } label: {

                        Label(
                            "Remove Emergency Contact",
                            systemImage: "trash"
                        )
                    }
                }
            }
        }
        .navigationTitle(
            "Emergency Contact"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )

        // MARK: - Contact Picker

        .sheet(
            isPresented:
                $showContactPicker
        ) {

            ContactPicker {
                name,
                phone in

                emergencyContactName =
                    name

                emergencyContactPhone =
                    phone

                showContactPicker =
                    false
            }
        }
    }
}


#Preview {

    NavigationStack {

        EmergencyContactView()
    }
}
