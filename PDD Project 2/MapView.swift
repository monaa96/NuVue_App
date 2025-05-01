import SwiftUI
import MapKit
import Foundation
import CoreLocation

struct MapView: View {
    // MARK: - Properties

    @ObservedObject var locationManager: LocationManager
    @ObservedObject var firestoreManager: FirestoreManager // Use this instance
    @Binding var selectedColor: Color                    // Use this color
    var followingIDs: [String]
    var friendColorOverrides: [String: Color]

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var hasCenteredOnUser = false
    // @State private var broadcaster = LocationBroadcaster() // REMOVED - Use LocationBroadcaster.shared

    @AppStorage("username") private var username: String = ""

    // MARK: - Computed Properties for View Structure

    private var friendsToDisplay: [Friend] {
        firestoreManager.friends.filter { followingIDs.contains($0.id ?? "") }
    }

    @ViewBuilder
    private var userAnnotationContent: some View {
        VStack(spacing: 2) {
            Text("You")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(5)

            Circle()
                .fill(selectedColor) // Uses the binding
                .frame(width: 25, height: 25)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
    }

    @ViewBuilder
    private func friendAnnotationContent(for friend: Friend) -> some View {
        let friendID = friend.id ?? ""
        let color = friendColorOverrides[friendID] ?? Color(red: friend.r, green: friend.g, blue: friend.b)

        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
    }

    // MARK: - Body

    var body: some View {
        Map(position: $cameraPosition) {
            // User location
            if let userLocation = locationManager.location {
                Annotation("You", coordinate: userLocation) {
                    userAnnotationContent
                }
            }

            // Friends
            ForEach(friendsToDisplay, id: \.id) { friend in
                let coordinate = CLLocationCoordinate2D(latitude: friend.latitude, longitude: friend.longitude)
                if CLLocationCoordinate2DIsValid(coordinate) {
                    Annotation(friend.name, coordinate: coordinate) {
                        friendAnnotationContent(for: friend)
                    }
                }
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard let validLocation = newLocation, CLLocationCoordinate2DIsValid(validLocation) else { return }

            // 1. Center map if needed
            if !hasCenteredOnUser {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: validLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
                hasCenteredOnUser = true
            }

            // 2. Trigger broadcast using the correct data from this view
            guard !username.isEmpty else { return }
            LocationBroadcaster.shared.broadcastIfNeeded(
                username: username,
                location: validLocation,
                color: selectedColor,          // Use the binding value
                firestoreManager: firestoreManager // Use the observed object instance
            )
        }
        .onAppear {
            // No broadcaster start needed - just ensure location updates start
            // (LocationManager init already starts updates)
             print("MapView appeared. Waiting for location updates.")

             // Optional: If the initial location is already available, center and broadcast immediately
             if let initialLocation = locationManager.location, CLLocationCoordinate2DIsValid(initialLocation), !username.isEmpty {
                 if !hasCenteredOnUser {
                     cameraPosition = .region(
                         MKCoordinateRegion(
                             center: initialLocation,
                             span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                         )
                     )
                     hasCenteredOnUser = true
                 }
                 LocationBroadcaster.shared.broadcastIfNeeded(
                     username: username,
                     location: initialLocation,
                     color: selectedColor,
                     firestoreManager: firestoreManager
                 )
             }
        }
        .onDisappear {
            // No broadcaster stop needed - location updates stop if manager is deallocated
            // Or you could add a stopUpdatingLocation method to LocationManager if needed elsewhere
            print("MapView disappeared.")
        }
    }
}

// MARK: - CLLocationCoordinate2D Equatable (Keep)
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
