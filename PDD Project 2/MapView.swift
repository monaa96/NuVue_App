import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct MapView: View {
    // MARK: - Properties

    @ObservedObject var locationManager: LocationManager
    @ObservedObject var firestoreManager: FirestoreManager // Use this instance
    @Binding var selectedColor: Color // Use this color
    var followingIDs: [String]
    var friendColorOverrides: [String: Color]

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: 37.7749, longitude: -122.4194
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var hasCenteredOnUser = false
    // @State private var broadcaster = LocationBroadcaster() // REMOVED - Use LocationBroadcaster.shared

    @AppStorage("username") private var username: String = ""

    // MARK: - Computed Properties for View Structure

    private var friendsToDisplay: [Friend] {
        let followingSet = Set(followingIDs.filter { !$0.isEmpty })
        return firestoreManager.friends.filter { friend in
            guard let id = friend.id else { return false }
            return followingSet.contains(id)
        }
    }

    // Helper to get friend's display color (override > default)
    private var friendsDict: [String: Friend] {
        Dictionary(
            uniqueKeysWithValues: firestoreManager.friends.compactMap {
                friend in
                guard let id = friend.id else { return nil }
                return (id, friend)
            })
    }

    private func friendDisplayColor(for friendID: String) -> Color {
        if let overrideColor = friendColorOverrides[friendID] {
            return overrideColor // Use override
        }
        if let friend = friendsDict[friendID] {
            return Color(red: friend.r, green: friend.g, blue: friend.b) // Use default
        }
        return .gray // Fallback
    }

    // --- Annotation View Builders (Content INSIDE Annotation) ---
    // This builds the VIEW content *for* the user annotation
    @ViewBuilder
    private var userAnnotationLabel: some View {
        VStack(spacing: 2) {
            Text("You")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                .offset(y: -2)

            HaloAnnotationView(
                color: selectedColor,
                dotSize: 22,
                borderLineWidth: 2
            )
        }
    }

    // This builds the VIEW content *for* a friend annotation
    @ViewBuilder
    private func friendAnnotationLabel(for friend: Friend) -> some View {
        let displayColor = friendDisplayColor(for: friend.id ?? "")
        HaloAnnotationView(
            color: displayColor,
            dotSize: 18,
            borderLineWidth: 1.5
        )
    }

    // --- Map Content Builders (Return MapContent) ---

    // User Annotation - Returns Annotation directly (which is MapContent)
    // Optional Annotation is also valid MapContent
    @MapContentBuilder // Use specific builder if returning multiple/conditional MapContent
    private var userMapAnnotation: some MapContent { // ✅ Return some MapContent
        if let userLocation = locationManager.location {
            Annotation("You", coordinate: userLocation, anchor: .bottom) {
                userAnnotationLabel // Use the ViewBuilder helper for the label
            }
        }
        // Implicitly returns EmptyMapContent if condition is false
    }

    // Friend Annotations - Returns ForEach<..., Annotation<...>> (which is MapContent)
    @MapContentBuilder // Use specific builder
    private func friendMapAnnotations() -> some MapContent { // ✅ Return some MapContent
        ForEach(friendsToDisplay) { friend in // ForEach producing Annotations is MapContent
            let coordinate = CLLocationCoordinate2D(
                latitude: friend.latitude, longitude: friend.longitude
            )

            // Check coordinate validity AND if friend.id exists for color lookup
            if CLLocationCoordinate2DIsValid(coordinate), friend.id != nil {
                Annotation(friend.name, coordinate: coordinate, anchor: .center) {
                    friendAnnotationLabel(for: friend) // Use the ViewBuilder helper for the label
                }
            } else {
                // Optionally log invalid friend data
                // print("Skipping friend annotation due to invalid coord or missing ID: \(friend.name)")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Map(position: $cameraPosition) {
            userMapAnnotation
            friendMapAnnotations()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard let validLocation = newLocation,
                  CLLocationCoordinate2DIsValid(validLocation)
            else { return }

            // 1. Center map if needed
            if !hasCenteredOnUser {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: validLocation,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.02, longitudeDelta: 0.02
                        )
                    )
                )
                hasCenteredOnUser = true
            }

            // 2. Trigger broadcast using the correct data from this view
            guard !username.isEmpty else { return }
            LocationBroadcaster.shared.broadcastIfNeeded(
                username: username,
                location: validLocation, // Use the binding value
                firestoreManager: firestoreManager // Use the observed object instance
            )
        }
        .onAppear {
            // No broadcaster start needed - just ensure location updates start
            // (LocationManager init already starts updates)
            print("MapView appeared. Waiting for location updates.")

            // Center/Broadcast if location already available
            if let initialLocation = locationManager.location,
               CLLocationCoordinate2DIsValid(initialLocation),
               !hasCenteredOnUser, !username.isEmpty
            {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: initialLocation,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.02, longitudeDelta: 0.02
                        )
                    ))
                hasCenteredOnUser = true
                LocationBroadcaster.shared.broadcastIfNeeded(
                    username: username, location: initialLocation,
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
    public static func == (
        lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D
    ) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
