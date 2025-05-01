import SwiftUI
import MapKit
import Foundation

struct MapView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var selectedColor: Color
    var followingIDs: [String]
    var friendColorOverrides: [String: Color]

    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)  // Start zoomed in, but will update to user
        )
    )

    @State private var hasCenteredOnUser = false  // ✅ New flag to center only once

    @AppStorage("username") private var username: String = ""

    var body: some View {
        Map(position: $cameraPosition) {
            // 👩 Your own location
            if let userLocation = locationManager.location {
                Annotation("You", coordinate: userLocation) {
                    VStack(spacing: 2) {
                        Text("You")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(5)

                        Circle()
                            .fill(selectedColor)
                            .frame(width: 25, height: 25)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
            }

            // 👫 Friends
            ForEach(firestoreManager.friends.filter { followingIDs.contains($0.id ?? "") }, id: \ .id) { friend in
                Annotation(friend.name, coordinate: CLLocationCoordinate2D(latitude: friend.latitude, longitude: friend.longitude)) {
                    Circle()
                        .fill(friendColorOverrides[friend.id ?? ""] ?? Color(red: friend.r, green: friend.g, blue: friend.b))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
            }
        }
        .onChange(of: locationManager.location) { newLocation in
            if !hasCenteredOnUser, let newLocation = newLocation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: newLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
                hasCenteredOnUser = true
            }
        }
    }
}

// ✅ Correct extension to allow comparisons
import CoreLocation

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
