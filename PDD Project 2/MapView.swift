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

    // ✅ Add Virtual Mode Properties
    let isVirtualModeActive: Bool
    let virtualUserLocation: CLLocationCoordinate2D?
    let virtualFriendLocations: [String: CLLocationCoordinate2D]

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

    // --- Current Display Locations ---
    // ✅ Helper to get the location to actually display
    private var displayedUserLocation: CLLocationCoordinate2D? {
        isVirtualModeActive ? virtualUserLocation : locationManager.location
    }

    private func displayedFriendLocation(for friend: Friend) -> CLLocationCoordinate2D? {
        guard let friendID = friend.id else { return nil }
        if isVirtualModeActive {
            return virtualFriendLocations[friendID] // Return virtual if active
        } else {
            // Return real location if valid
            let realCoord = CLLocationCoordinate2D(latitude: friend.latitude, longitude: friend.longitude)
            return CLLocationCoordinate2DIsValid(realCoord) ? realCoord : nil
        }
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
    @MapContentBuilder
    private var userMapAnnotation: some MapContent {
        // ✅ Use the displayedUserLocation helper
        if let location = displayedUserLocation {
            Annotation("You", coordinate: location, anchor: .bottom) {
                userAnnotationLabel
            }
        }
    }

    // Friend Annotations - Returns ForEach<..., Annotation<...>> (which is MapContent)
    @MapContentBuilder
    private func friendMapAnnotations() -> some MapContent {
        ForEach(friendsToDisplay) { friend in
            // ✅ Use the displayedFriendLocation helper
            if let location = displayedFriendLocation(for: friend) {
                Annotation(friend.name, coordinate: location, anchor: .center) {
                    friendAnnotationLabel(for: friend)
                }
            } else {
                // Friend might be missing ID or location is invalid/not calculated
                // print("Skipping friend annotation for \(friend.name) (Invalid/Missing Location)")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Map(position: $cameraPosition) {
            userMapAnnotation
            friendMapAnnotations()
        }
        .mapStyle(.hybrid)
        // ✅ onChange for location updates should ONLY broadcast REAL location
        .onChange(of: locationManager.location) { _, newLocation in // Observe REAL location
            guard let realLocation = newLocation, CLLocationCoordinate2DIsValid(realLocation) else { return }

            // Center map ONLY if NOT in virtual mode and not already centered
            if !isVirtualModeActive && !hasCenteredOnUser {
                cameraPosition = .region(MKCoordinateRegion(center: realLocation, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                hasCenteredOnUser = true
            }

            // Broadcast REAL location regardless of virtual mode
            guard !username.isEmpty else { return }
            LocationBroadcaster.shared.broadcastIfNeeded(
                username: username,
                location: realLocation, // Always broadcast REAL location
                firestoreManager: firestoreManager
            )
        }
        // ✅ Add onChange to react to virtual mode changes (optional camera move)
        .onChange(of: isVirtualModeActive) { _, newIsVirtual in
            if newIsVirtual, let targetCenter = virtualUserLocation {
                print("MapView: Virtual Mode Activated - Moving camera to Killington")
                // Animate camera to the virtual location center (Killington)
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: targetCenter,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // Adjust zoom
                    ))
                }
                hasCenteredOnUser = false // Allow re-centering when returning to reality
            } else if !newIsVirtual, let realUserLocation = locationManager.location {
                print("MapView: Virtual Mode Deactivated - Moving camera back to user")
                // Animate back to user's real location
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: realUserLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
                hasCenteredOnUser = false // Reset centering flag
            }
        }
        .onAppear {
            print("MapView appeared.")
            // Initial camera centering (prioritize virtual if active on appear)
            let initialCenter = displayedUserLocation ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // Default SF
            if !hasCenteredOnUser || (isVirtualModeActive && cameraPosition.region?.center != virtualUserLocation) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: initialCenter,
                    span: MKCoordinateSpan(latitudeDelta: isVirtualModeActive ? 0.05 : 0.02, longitudeDelta: isVirtualModeActive ? 0.05 : 0.02)
                ))
                // Only set hasCenteredOnUser if we centered on the *real* user
                if !isVirtualModeActive && locationManager.location != nil {
                    hasCenteredOnUser = true
                }
            }
            // Initial broadcast if needed (use REAL location)
            if let realLocation = locationManager.location, !username.isEmpty {
                LocationBroadcaster.shared.broadcastIfNeeded(username: username, location: realLocation, firestoreManager: firestoreManager)
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
