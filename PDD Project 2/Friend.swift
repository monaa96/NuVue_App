import Foundation
import CoreLocation

struct Friend: Identifiable {
    var id: String?  // Firestore document ID
    var name: String
    var latitude: Double
    var longitude: Double
    var r: Double
    var g: Double
    var b: Double
}

