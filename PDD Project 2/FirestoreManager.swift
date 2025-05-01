import Foundation
import FirebaseFirestore
import CoreLocation
import SwiftUI

class FirestoreManager: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var friends: [Friend] = []
    
    private var listener: ListenerRegistration?
    
    func startListening() {
        listener = db.collection("users").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self.friends = documents.compactMap { doc -> Friend? in
                let data = doc.data()
                guard let username = data["username"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let r = data["r"] as? Double,
                      let g = data["g"] as? Double,
                      let b = data["b"] as? Double else {
                    return nil
                }
                return Friend(
                    id: doc.documentID,
                    name: username,       // ✅ THIS IS CORRECT
                    latitude: latitude,
                    longitude: longitude,
                    r: r,
                    g: g,
                    b: b
                )

            }
        }
    }
    
    func saveUser(username: String, location: CLLocationCoordinate2D, color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        db.collection("users").document(username).setData([
            "username": username,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "r": Double(red),
            "g": Double(green),
            "b": Double(blue)
        ]) { error in
            if let error = error {
                print("Error saving user: \(error)")
            } else {
                print("✅ Username successfully saved")
            }
        }
    }
    
    func fetchUser(username: String, completion: @escaping (Friend?) -> Void) {
        db.collection("users").document(username).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                let friend = Friend(
                    id: document.documentID,
                    name: data["username"] as? String ?? "",  // <-- ✅ Fixed here
                    latitude: data["latitude"] as? Double ?? 0,
                    longitude: data["longitude"] as? Double ?? 0,
                    r: data["r"] as? Double ?? 0,
                    g: data["g"] as? Double ?? 0,
                    b: data["b"] as? Double ?? 0
                )
                completion(friend)
            } else {
                completion(nil)
            }
        }
    }
}

