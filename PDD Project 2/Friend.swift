import CoreLocation
import Foundation

struct Friend: Identifiable, Equatable {
    var id: String? // Firestore document ID
    var name: String
    var latitude: Double
    var longitude: Double
    var r: Double
    var g: Double
    var b: Double

    static func == (lhs: Friend, rhs: Friend) -> Bool {
        // Two friends are considered equal if all their properties match.
        // Especially important for onChange to detect changes in location, name, or color.
        return lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.latitude == rhs.latitude &&
            lhs.longitude == rhs.longitude &&
            lhs.r == rhs.r &&
            lhs.g == rhs.g &&
            lhs.b == rhs.b
    }
}
