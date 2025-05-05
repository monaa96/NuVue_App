import CoreLocation
import FirebaseFirestore
import Foundation
import SwiftUI

class FirestoreManager: ObservableObject {
    // Use static let shared = FirestoreManager() only if you NEED a singleton
    // If ContentView uses @StateObject private var firestoreManager = FirestoreManager(),
    // you might not need the static shared instance. Choose one approach.
    // static let shared = FirestoreManager() // Keep if used elsewhere

    private let db = Firestore.firestore()
    @Published var friends: [Friend] = [] // Holds ALL users in your setup
    private var listener: ListenerRegistration?

    // Ensure this is called only ONCE (e.g., from ContentView.onAppear)
    func startListening() {
        guard listener == nil else {
            // print("FirestoreManager: Listener already active.") // Optional log
            return
        }
        print("✅ FirestoreManager: Starting listener for 'users' collection...")

        listener = db.collection("users").addSnapshotListener { snapshot, error in
            if let error = error {
                print("🔥 Firestore Listener Error: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents else {
                print("Firestore Listener: Snapshot contains no documents.")
                DispatchQueue.main.async { self.friends = [] }
                return
            }
            // print("Firestore Listener: Received \(documents.count) documents.") // Can be noisy

            let mappedFriends = documents.compactMap { doc -> Friend? in
                let data = doc.data()
                let docID = doc.documentID
                // print("--> Mapping document ID: \(docID)")
                // print("    Raw Data: \(data)") // VERBOSE DEBUG LOG

                // --- Check field names and types carefully ---
                guard let username = data["username"] as? String, // Reads "username" field
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let r = data["r"] as? Double, // Expects Double
                      let g = data["g"] as? Double, // Expects Double
                      let b = data["b"] as? Double // Expects Double
                else {
                    print("    🔥 Mapping FAILED for \(docID). Check fields/types in Firestore data: \(data)") // Log data on failure
                    return nil
                }

                let mappedFriend = Friend(
                    id: docID, // Uses document ID (which is username here)
                    name: username, // Assigns Firestore "username" field to Friend's "name" property
                    latitude: latitude,
                    longitude: longitude,
                    r: r,
                    g: g,
                    b: b
                )
                // print("    ✅ Mapped Friend: \(mappedFriend)") // VERBOSE DEBUG LOG
                return mappedFriend
            }

            // print("Firestore Listener: Successfully mapped \(mappedFriends.count) friends.") // Can be noisy

            DispatchQueue.main.async {
                self.friends = mappedFriends
                // print("FirestoreManager: Updated @Published friends array.") // Optional log
            }
        }
    }

    func stopListening() {
        print("FirestoreManager: Stopping listener.")
        listener?.remove()
        listener = nil
    }

    // --- Save User (Initial Setup / Profile Update) ---
    // Saves ALL profile data, including the chosen color.
    func saveUser(username: String, location: CLLocationCoordinate2D, color: Color) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }
        print("✅ FirestoreManager: saveUser (Profile) called for '\(trimmedUsername)'")

        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil) else {
            // If getRed returns false (conversion failed)
            print("🔥 UIColor conversion FAILED for input color: \(color). User data NOT saved.")
            // EXIT the function - do not proceed to save incorrect data
            return // <-- Added return
        }
        print("--> UIColor Profile: R:\(red), G:\(green), B:\(blue)")

        let userData: [String: Any] = [
            "username": trimmedUsername, // Or "name" if your Friend struct uses that
            "latitude": location.latitude,
            "longitude": location.longitude,
            "r": Double(red),
            "g": Double(green),
            "b": Double(blue),
            "lastUpdated": Timestamp(date: Date()), // ✅ Add a timestamp
        ]
        print("--> Preparing to save FULL profile data: \(userData)")

        // Overwrite document with full profile data
        db.collection("users").document(trimmedUsername).setData(userData) { error in
            if let error = error { print("🔥 Error saving user profile '\(trimmedUsername)': \(error)") }
            else { print("✅ User profile '\(trimmedUsername)' saved.") }
        }
    }

    // Updates only dynamic fields like location and timestamp. DOES NOT save color.
    func updateLocation(username: String, location: CLLocationCoordinate2D) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }
        // print("✅ FirestoreManager: updateLocation called for '\(trimmedUsername)'") // Can be noisy

        let locationData: [String: Any] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
            "lastUpdated": Timestamp(date: Date()), // Update timestamp
            // DO NOT include r, g, b here
        ]
        // print("--> Preparing to update location data: \(locationData)") // Can be noisy

        // Use merge: true to ONLY update the specified fields
        db.collection("users").document(trimmedUsername).setData(locationData, merge: true) { error in
            if let error = error { print("🔥 Error updating location for '\(trimmedUsername)': \(error)") }
            // else { print("✅ Location for '\(trimmedUsername)' updated.") } // Can be noisy
        }
    }

    // fetchUser (ensure field names match saveUser and listener)
    func fetchUser(username: String, completion: @escaping (Friend?) -> Void) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            completion(nil)
            return
        }

        // Use username as document ID to fetch
        db.collection("users").document(trimmedUsername).getDocument { document, error in
            if let error = error {
                print("🔥 Error fetching user '\(trimmedUsername)': \(error)")
                completion(nil)
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                print("User document '\(trimmedUsername)' does not exist or has no data.")
                completion(nil)
                return
            }

            // Map data (ensure field names match listener)
            guard let name = data["username"] as? String, // Reads "username" field
                  let latitude = data["latitude"] as? Double,
                  let longitude = data["longitude"] as? Double,
                  let r = data["r"] as? Double,
                  let g = data["g"] as? Double,
                  let b = data["b"] as? Double
            else {
                print("🔥 fetchUser: Failed to map data for '\(trimmedUsername)'. Data: \(data)")
                completion(nil)
                return
            }

            let friend = Friend(
                id: document.documentID, // Uses document ID (which is username)
                name: name, // Uses Firestore "username" field for Friend's "name"
                latitude: latitude,
                longitude: longitude,
                r: r,
                g: g,
                b: b
            )
            // print("fetchUser: Successfully fetched and mapped '\(trimmedUsername)'")
            completion(friend)
        }
    }
}
