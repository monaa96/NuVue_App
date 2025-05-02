import CoreLocation
import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var bluetoothManager = BluetoothManager()

    @State private var selectedColor: Color = .blue // User's own color
    @State private var showBluetoothList = false
    @State private var showAddFriends = false
    @State private var showRemoveFriends = false
    @State private var showEditFriendColor = false

    @AppStorage("followingIDs") private var followingIDsString: String = ""
    @AppStorage("username") private var username: String = ""

    // ✅ Use @AppStorage to store the *encoded Data* of the dictionary
    @AppStorage("friendColorOverridesDataBlob_v2") private var friendOverridesData: Data = .init() // Use new key if format changed

    // ✅ State variable holding the *decoded, usable* dictionary in memory
    @State private var friendColorOverrides: [String: Color] = [:]

    // Computed property to easily access following IDs as an array
    private var followingIDs: [String] {
        followingIDsString.split(separator: ",").map { String($0) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            if username.isEmpty {
                UsernameSetupView(locationManager: locationManager, firestoreManager: firestoreManager)
            } else {
                MapView(
                    locationManager: locationManager,
                    firestoreManager: firestoreManager,
                    selectedColor: $selectedColor,
                    followingIDs: followingIDs,
                    friendColorOverrides: friendColorOverrides // Pass the @State value
                )
                .ignoresSafeArea(edges: .top)

                // Buttons section (using ActionButtonStyle defined below)
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Connect Bluetooth") { showBluetoothList = true }
                            .buttonStyle(ActionButtonStyle(backgroundColor: .blue))
                        Button("Add Friends") { showAddFriends = true }
                            .buttonStyle(ActionButtonStyle(backgroundColor: .green))
                    }
                    HStack(spacing: 10) {
                        Button("Remove Friends") { showRemoveFriends = true }
                            .buttonStyle(ActionButtonStyle(backgroundColor: .red))
                        Button("🎨 Edit Colors") { showEditFriendColor = true }
                            .buttonStyle(ActionButtonStyle(backgroundColor: .orange))
                    }
                    #if DEBUG
                        Button("➕ Add Fake Friends") { addFakeFriends() }
                            .buttonStyle(ActionButtonStyle(backgroundColor: .purple))
                    #endif
                }
                .padding()
                .background(.thinMaterial)
            }
        }
        // --- Sheets ---
        .sheet(isPresented: $showBluetoothList) { BluetoothDeviceListView(bluetoothManager: bluetoothManager) }
        .sheet(isPresented: $showAddFriends) { AddFriendView(firestoreManager: firestoreManager, followingIDsString: $followingIDsString) }
        .sheet(isPresented: $showRemoveFriends) { RemoveFriendView(followingIDsString: $followingIDsString) }
        .sheet(isPresented: $showEditFriendColor) {
            // ✅ Pass the BINDING to the @State variable
            FriendColorListView(
                followingIDs: followingIDs,
                friendColorOverrides: $friendColorOverrides,
                firestoreManager: firestoreManager // Pass the manager
            )
        }
        // --- onChange Handlers ---
        .onChange(of: bluetoothManager.connectedPeripheral) { newPeripheral in
            if newPeripheral != nil {
                print("🔵 Bluetooth device connected — starting auto-send...")
                bluetoothManager.startAutoSending(
                    locationManager: locationManager,
                    firestoreManager: firestoreManager,
                    followingIDs: followingIDs,
                    colorOverrides: friendColorOverrides
                )
            } else {
                print("🔴 Bluetooth device disconnected — stopping auto-send...")
                bluetoothManager.stopAutoSending()
            }
        }
        // ✅ Add onChange to save overrides when the @State dictionary changes
        .onChange(of: friendColorOverrides) { _, newValue in
            print("✅ ContentView: .onChange(of: friendColorOverrides) FIRED.")
            print("--> New dictionary value count: \(newValue.count)")
            print("--> Saving dictionary: \(newValue)") // Log dictionary content

            // Encode and save
            guard let encodedData = encodeColorDictionary(newValue) else {
                print("🔥 ContentView: FAILED to encode overrides dictionary. Data NOT saved.")
                // Clear potentially corrupt data?
                // friendOverridesData = Data()
                return
            }

            // Only update AppStorage if data actually changed to avoid loops if encoding is stable
            if encodedData != friendOverridesData {
                friendOverridesData = encodedData
                print("ContentView: Successfully encoded and SAVED overrides data (\(encodedData.count) bytes) to @AppStorage.")
            } else {
                print("ContentView: Encoded data is the same as stored data. No save needed.")
            }
        }
        // --- Lifecycle ---
        .onAppear {
            print("✅ ContentView: .onAppear FIRED.")
            // Load initial data from @AppStorage
            print("--> Loading raw data (\(friendOverridesData.count) bytes) from @AppStorage key 'friendColorOverridesDataBlob_v2'")
            if let decodedOverrides = decodeColorDictionary(from: friendOverridesData) {
                // ✅ IMPORTANT: Assign only if different to avoid unnecessary onChange trigger
                if decodedOverrides != friendColorOverrides {
                    friendColorOverrides = decodedOverrides
                    print("ContentView: Successfully decoded and assigned \(friendColorOverrides.count) overrides.")
                    print("--> Loaded dictionary: \(friendColorOverrides)")
                } else {
                    print("ContentView: Decoded data matches current state. No assignment needed.")
                }
            } else {
                print("⚠️ ContentView: Failed to decode overrides or data empty. Resetting to empty dictionary.")
                // Only reset if current state isn't already empty
                if !friendColorOverrides.isEmpty {
                    friendColorOverrides = [:]
                }
                // Optionally clear invalid stored data
                if !friendOverridesData.isEmpty {
                    // friendOverridesData = Data()
                }
            }

            // Start other services
            locationManager.startUpdates()
            firestoreManager.startListening() // Ensure this is called appropriately
        }
        .onDisappear {
            locationManager.stopUpdates()
        }
    }

    private func addFakeFriends() {
        let fakeFriends = [
            ("FakeUser1", 42.3601, -71.0589),
            ("FakeUser2", 41.8240, -71.4128),
        ]

        var currentIDs = followingIDsString.split(separator: ",").map { String($0) }

        for (username, lat, lon) in fakeFriends {
            let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let color = Color.random()
            firestoreManager.saveUser(username: username, location: location, color: color)

            if !currentIDs.contains(username) {
                currentIDs.append(username)
            }
        }

        followingIDsString = currentIDs.joined(separator: ",")
        print("✅ Fake friends added and now following: \(followingIDsString)")
    }
}

// Helper Button Style for consistency
struct ActionButtonStyle: ButtonStyle {
    var backgroundColor: Color = .blue
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10) // Adjust padding as needed
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity) // Make buttons fill available width in HStack
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0) // Subtle press effect
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension Color {
    static func random() -> Color {
        Color(
            red: Double.random(in: 0.2 ... 1.0),
            green: Double.random(in: 0.2 ... 1.0),
            blue: Double.random(in: 0.2 ... 1.0)
        )
    }
}

struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
