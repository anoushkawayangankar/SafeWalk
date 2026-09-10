import SwiftUI
import MessageUI
import UIKit

struct EmergencyView: View {

    // MARK: - Emergency Contact

    @AppStorage("emergencyContactName")
    private var emergencyContactName = ""

    @AppStorage("emergencyContactPhone")
    private var emergencyContactPhone = ""


    // MARK: - Shared Tracking

    @EnvironmentObject var trackingService:
        JourneyTrackingService


    // MARK: - Message Composer

    @State private var showMessageComposer = false

    @State private var showMessagingUnavailableAlert = false


    // MARK: - Current Location

    private var latitude: Double? {

        trackingService
            .locationManager
            .latitude
    }


    private var longitude: Double? {

        trackingService
            .locationManager
            .longitude
    }


    // MARK: - Location URL

    private var currentLocationURL: URL? {

        guard
            let latitude,
            let longitude
        else {
            return nil
        }

        return URL(
            string:
                "https://maps.apple.com/?ll=\(latitude),\(longitude)"
        )
    }


    // MARK: - Emergency Message

    private var emergencyMessage: String {

        var message = """
        SafeWalk safety alert.

        I missed a safety check-in during an active journey.

        Please check on me.
        """


        if let currentLocationURL {

            message += """


            My current location:
            \(currentLocationURL.absoluteString)
            """
        }


        return message
    }


    // MARK: - Body

    var body: some View {

        ScrollView {

            VStack(spacing: 24) {

                // MARK: Header

                Image(
                    systemName:
                        "exclamationmark.triangle.fill"
                )
                .font(
                    .system(size: 60)
                )
                .foregroundStyle(.red)


                Text("Emergency Options")
                    .font(.largeTitle)
                    .bold()


                Text(
                    "Choose what you would like to do."
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)


                Divider()


                // MARK: Trusted Contact

                if !emergencyContactName.isEmpty {

                    VStack(spacing: 6) {

                        Text("Trusted Contact")
                            .font(.caption)
                            .foregroundStyle(.secondary)


                        Text(emergencyContactName)
                            .font(.headline)


                        if !emergencyContactPhone.isEmpty {

                            Text(emergencyContactPhone)
                                .foregroundStyle(.secondary)
                        }
                    }
                }


                // MARK: Message Trusted Contact

                Button {

                    openMessageComposer()

                } label: {

                    Label(
                        emergencyContactName.isEmpty
                            ? "Message Trusted Contact"
                            : "Message \(emergencyContactName)",
                        systemImage:
                            "message.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(
                    "Opens a text message with your safety alert and current location when available"
                )
                .disabled(
                    cleanedPhoneNumber.isEmpty
                )


                // MARK: Call Trusted Contact

                Button {

                    callEmergencyContact()

                } label: {

                    Label(
                        emergencyContactName.isEmpty
                            ? "Call Trusted Contact"
                            : "Call \(emergencyContactName)",
                        systemImage:
                            "phone.fill"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityHint(
                    "Opens the Phone app with your trusted contact's number"
                )
                .disabled(
                    cleanedPhoneNumber.isEmpty
                )


                // MARK: Share Location

                if let currentLocationURL {

                    ShareLink(
                        item:
                            currentLocationURL,

                        subject:
                            Text(
                                "SafeWalk Safety Alert"
                            ),

                        message:
                            Text(
                                "I may need assistance. This is my current location."
                            )
                    ) {

                        Label(
                            "Share Current Location",
                            systemImage:
                                "location.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(
                        "Opens the system share sheet with your current Apple Maps location"
                    )
                }


                // MARK: Emergency Services

                Button {

                    callEmergencyServices()

                } label: {

                    Label(
                        "Call Emergency Services",
                        systemImage:
                            "cross.case.fill"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityHint(
                    "Opens the Phone app with emergency services number 112"
                )


                Divider()


                // MARK: Current Location

                VStack(spacing: 8) {

                    Text("Current Location")
                        .font(.headline)


                    if let latitude,
                       let longitude {

                        Text(
                            "Latitude: \(latitude)"
                        )
                        .font(.caption)


                        Text(
                            "Longitude: \(longitude)"
                        )
                        .font(.caption)


                        if let currentLocationURL {

                            Link(
                                "Open in Apple Maps",
                                destination:
                                    currentLocationURL
                            )
                            .font(.caption)
                        }

                    } else {

                        Text(
                            "Current location unavailable."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }


                Spacer()
            }
            .padding()
        }
        .navigationTitle("Emergency")
        .navigationBarTitleDisplayMode(.inline)


        // MARK: Message Composer

        .sheet(
            isPresented:
                $showMessageComposer
        ) {

            MessageComposer(
                recipients: [
                    cleanedPhoneNumber
                ],
                body:
                    emergencyMessage
            )
        }


        // MARK: Messaging Unavailable

        .alert(
            "Messaging Unavailable",
            isPresented:
                $showMessagingUnavailableAlert
        ) {

            Button(
                "OK",
                role: .cancel
            ) {
            }

        } message: {

            Text(
                "Messages cannot be opened on this device. Try this feature on a physical iPhone."
            )
        }
    }


    // MARK: - Clean Phone Number

    private var cleanedPhoneNumber: String {

        emergencyContactPhone.filter {

            $0.isNumber ||
            $0 == "+"
        }
    }


    // MARK: - Open Message Composer

    private func openMessageComposer() {

        guard
            !cleanedPhoneNumber.isEmpty
        else {
            return
        }


        guard
            MFMessageComposeViewController
                .canSendText()
        else {

            showMessagingUnavailableAlert =
                true

            return
        }


        showMessageComposer =
            true
    }


    // MARK: - Call Trusted Contact

    private func callEmergencyContact() {

        guard
            !cleanedPhoneNumber.isEmpty
        else {
            return
        }


        guard
            let url =
                URL(
                    string:
                        "tel:\(cleanedPhoneNumber)"
                )
        else {
            return
        }


        UIApplication
            .shared
            .open(url)
    }


    // MARK: - Call Emergency Services

    private func callEmergencyServices() {

        guard
            let url =
                URL(
                    string:
                        "tel:112"
                )
        else {
            return
        }


        UIApplication
            .shared
            .open(url)
    }
}


// MARK: - Preview

#Preview {

    let sessionManager =
        JourneySessionManager()

    let trackingService =
        JourneyTrackingService(
            sessionManager:
                sessionManager
        )


    NavigationStack {

        EmergencyView()
    }
    .environmentObject(
        trackingService
    )
}
