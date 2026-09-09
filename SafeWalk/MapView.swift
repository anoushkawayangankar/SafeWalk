import SwiftUI
import MapKit

struct MapView: View {

    let userCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let route: MKRoute?

    @State private var position: MapCameraPosition = .automatic

    var body: some View {

        Map(position: $position) {

            Marker(
                "You",
                coordinate: userCoordinate
            )

            Marker(
                "Destination",
                coordinate: destinationCoordinate
            )

            if let route = route {

                MapPolyline(route.polyline)
                    .stroke(
                        .blue,
                        lineWidth: 6
                    )
            }
        }
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
        .onAppear {
            position = .automatic
        }
    }
}

#Preview {

    MapView(
        userCoordinate: CLLocationCoordinate2D(
            latitude: 12.9716,
            longitude: 77.5946
        ),
        destinationCoordinate: CLLocationCoordinate2D(
            latitude: 12.9507,
            longitude: 77.5848
        ),
        route: nil
    )
}
