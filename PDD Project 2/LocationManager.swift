import Foundation
import CoreLocation
import SwiftUI // Keep SwiftUI import if Color is used elsewhere, otherwise remove

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?

    // You might want a shared instance if multiple parts of your app need the same manager
    // static let shared = LocationManager()

    override init() {
        super.init()
        print("LocationManager: Initializing.")
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest // Or less aggressive if needed
        manager.allowsBackgroundLocationUpdates = true // Ensure Info.plist capability is set
        manager.pausesLocationUpdatesAutomatically = false
        manager.requestAlwaysAuthorization() // Or requestWhenInUseAuthorization
        // Consider calling startUpdatingLocation() only when needed, e.g., from onAppear
        // manager.startUpdatingLocation() // Moved call to a separate method
    }

    func startUpdates() {
        print("LocationManager: Starting location updates.")
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        print("LocationManager: Stopping location updates.")
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                print("LocationManager: Authorization granted.")
                startUpdates() // Start updates once authorized
            case .notDetermined:
                print("LocationManager: Authorization not determined.")
                manager.requestAlwaysAuthorization() // Or requestWhenInUseAuthorization
            case .restricted, .denied:
                print("LocationManager: Authorization restricted or denied.")
                // Handle denial - show alert, guide user to settings?
            @unknown default:
                print("LocationManager: Unknown authorization status.")
        }
    }


    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let coord = latest.coordinate

        // Only update published property if the location actually changed significantly (optional optimization)
        // let minDistance: CLLocationDistance = 10 // meters
        // if self.location == nil || CLLocation(latitude: self.location!.latitude, longitude: self.location!.longitude).distance(from: latest) > minDistance {
            DispatchQueue.main.async {
                 // Check validity just in case
                 if CLLocationCoordinate2DIsValid(coord) {
                    self.location = coord
                    // print("LocationManager: Updated location to \(coord.latitude), \(coord.longitude)")
                 } else {
                    print("LocationManager: Received invalid location.")
                 }
            }
        // }

        // --- REMOVED BROADCASTING LOGIC FROM HERE ---
        // The MapView's .onChange(of: locationManager.location) will handle broadcasting
        // ---
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Failed to get location - \(error.localizedDescription)")
        // Optionally update UI or published properties to indicate error state
    }
}
