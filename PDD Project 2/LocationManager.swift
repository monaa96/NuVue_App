import CoreLocation
import Foundation
import SwiftUI // Keep SwiftUI import if Color is used elsewhere, otherwise remove

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    // Track authorization status internally
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined // Initialize

    // You might want a shared instance if multiple parts of your app need the same manager
    // static let shared = LocationManager()

    override init() {
        super.init()
        print("LocationManager: Initializing.")
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest // Or less aggressive if needed
        manager.allowsBackgroundLocationUpdates = true // Ensure Info.plist capability is set
        manager.pausesLocationUpdatesAutomatically = false
        
        self.authorizationStatus = manager.authorizationStatus
        print("LocationManager: Initial status is \(self.authorizationStatus)")
        
        manager.requestAlwaysAuthorization() // Or requestWhenInUseAuthorization
        // Consider calling startUpdatingLocation() only when needed, e.g., from onAppear
        // manager.startUpdatingLocation() // Moved call to a separate method
        
        // Request authorization if not determined yet
        if self.authorizationStatus == .notDetermined {
            print("LocationManager: Requesting Always authorization...")
             manager.requestAlwaysAuthorization() // Request "Always" (user can choose "While Using")
        }
    }

    func startUpdates() {
        print("LocationManager: Attempting to start updates...")
        // Check current authorization status first
        let currentStatus = manager.authorizationStatus
        print("--> Current Status: \(currentStatus)")

        if currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways {
             print("--> Authorization sufficient. Calling startUpdatingLocation().")
             // Only start the hardware if permission is granted
             manager.startUpdatingLocation()
        } else {
             print("--> Not authorized (\(currentStatus)). Cannot start updates.")
             // Optional: If not determined, request again (though init usually handles first time)
             if currentStatus == .notDetermined {
                  print("--> Requesting Always authorization again...")
                  manager.requestAlwaysAuthorization()
             }
             // Optional: Handle denied/restricted state (e.g., prompt user)
        }
    }

    func stopUpdates() {
        print("LocationManager: Stopping location updates.")
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Update the published status
        DispatchQueue.main.async {
             self.authorizationStatus = manager.authorizationStatus
             print("✅ LocationManager: Authorization status changed to: \(self.authorizationStatus)")

             // Re-evaluate if updates should be started based on the NEW status
             print("--> Re-evaluating startUpdates due to authorization change.")
             self.startUpdates() // Call startUpdates to handle the new status
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let coord = latest.coordinate
        DispatchQueue.main.async {
            if CLLocationCoordinate2DIsValid(coord) {
                self.location = coord
            }
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Failed to get location - \(error.localizedDescription)")
        // Optionally update UI or published properties to indicate error state
    }
}

extension CLAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
}
