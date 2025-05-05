import SwiftUI
import UIKit // Using UIKit for UIColor conversion

// Extension to convert Color to Data and back using UIColor archiving for UserDefaults persistence
extension Color {
    // Convert SwiftUI Color to Data
    func toData() -> Data? {
        let uiColor = UIColor(self)
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false)
        } catch {
            print("Error archiving UIColor: \(error)")
            return nil
        }
    }

    // Create SwiftUI Color from Data
    static func fromData(_ data: Data) -> Color? {
        do {
            guard let uiColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
                print("Error unarchiving UIColor: Failed to decode object.")
                return nil
            }
            return Color(uiColor)
        } catch {
            print("Error unarchiving UIColor: \(error)")
            return nil
        }
    }
}

// --- NO LONGER NEEDED with direct dictionary archiving ---
// // Extension to make Dictionary<String, Data> easier to work with for overrides
// extension Dictionary where Key == String, Value == Data { ... }
// // Extension to make Dictionary<String, Color> easier to work with for overrides
// extension Dictionary where Key == String, Value == Color { ... }
// ---

// Helper functions for archiving/unarchiving the entire dictionary
func encodeColorDictionary(_ dictionary: [String: Color]) -> Data? {
    print("ColorArchiving: Encoding dictionary with \(dictionary.count) items...") // ✅ Log start
    // Convert [String: Color] to [String: Data] first
    var dataDictionary: [String: Data] = [:]
    for (key, color) in dictionary {
        if let colorData = color.toData() {
            dataDictionary[key] = colorData
        } else {
            print("Warning: Could not encode color for key '\(key)' when encoding dictionary.")
            // Decide if you want to skip this key or fail the whole encoding
        }
    }

    // Archive the [String: Data] dictionary
    do {
        return try NSKeyedArchiver.archivedData(withRootObject: dataDictionary, requiringSecureCoding: false)
    } catch {
        print("Error archiving color dictionary: \(error)")
        return nil
    }
}

func decodeColorDictionary(from data: Data) -> [String: Color]? {
    print("ColorArchiving: Decoding dictionary from \(data.count) bytes...") // ✅ Log start
    // Unarchive the [String: Data] dictionary
    guard let dataDictionary = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)) as? [String: Data] else {
        // Handle case where data is empty or invalid format gracefully
        if data.isEmpty {
            return [:] // Return empty dict if data was empty
        }
        print("Error unarchiving color dictionary: Could not decode top level object or cast to [String: Data].")
        return nil
    }

    // Convert [String: Data] back to [String: Color]
    var colorDictionary: [String: Color] = [:]
    for (key, colorData) in dataDictionary {
        if let color = Color.fromData(colorData) {
            colorDictionary[key] = color
        } else {
            print("Warning: Could not decode color data for key '\(key)' when decoding dictionary.")
            // Decide if you want to skip this key or return nil for the whole dict
        }
    }
    return colorDictionary
}
