//
//  LocationBroadcaster.swift
//  PDD Project 2
//
//  Created by Anon on 5/1/25.
//

import CoreLocation
import Foundation
import SwiftUI

class LocationBroadcaster {
    static let shared = LocationBroadcaster()

    private var lastBroadcastTime: Date?
    private let broadcastInterval: TimeInterval = 2

    func broadcastIfNeeded(username: String, location: CLLocationCoordinate2D, firestoreManager: FirestoreManager) {
        let now = Date()
        // --- Throttling Logic ---
        // Check if lastBroadcastTime exists AND if not enough time has passed
        if let last = lastBroadcastTime, now.timeIntervalSince(last) < broadcastInterval {
            // print("LocationBroadcaster: Throttled broadcast for \(username).") // Optional log
            return // Exit if throttled
        }
        // If we reach here, it's either the first time (last == nil) OR enough time has passed.
        // --- End Throttling Logic ---

        guard !username.isEmpty, CLLocationCoordinate2DIsValid(location) else {
            print("LocationBroadcaster: Invalid username or location for broadcast.")
            return
        }

        lastBroadcastTime = now
        // print("LocationBroadcaster: Broadcasting location for \(username)") // Can be noisy

        // ✅ Call the new updateLocation function
        firestoreManager.updateLocation(username: username, location: location)
    }
}
