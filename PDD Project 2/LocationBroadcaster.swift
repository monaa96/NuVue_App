//
//  LocationBroadcaster.swift
//  PDD Project 2
//
//  Created by Anon on 5/1/25.
//

import Foundation
import CoreLocation
import SwiftUI

class LocationBroadcaster {
    static let shared = LocationBroadcaster()

    private var lastBroadcastTime: Date?

    func broadcastIfNeeded(username: String, location: CLLocationCoordinate2D, color: Color, firestoreManager: FirestoreManager) {
        let now = Date()
        if let last = lastBroadcastTime, now.timeIntervalSince(last) < 3 {
            return  // Skip if less than 3 seconds since last update
        }
        lastBroadcastTime = now

        firestoreManager.saveUser(username: username, location: location, color: color)
        print("📡 Background broadcast: \(location.latitude), \(location.longitude)")
    }
}
