import SwiftUI
import CoreLocation

struct UsernameSetupView: View {
    @State private var username: String = ""
    @State private var selectedColor: Color = .blue
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var firestoreManager: FirestoreManager
    
    @AppStorage("username") private var savedUsername: String = ""
    @AppStorage("followingIDs") private var followingIDsString: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter a username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            ColorPicker("Pick your color", selection: $selectedColor)
                .padding(.horizontal)
            
            Button("Save") {
                saveUsername()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
            .disabled(username.isEmpty)
        }
    }
    
    private func saveUsername() {
        savedUsername = username
        
        // Save into Firestore
        if let location = locationManager.location {
            firestoreManager.saveUser(
                username: username,
                location: location,
                color: selectedColor
            )
        }
        
        dismiss()
    }
}

