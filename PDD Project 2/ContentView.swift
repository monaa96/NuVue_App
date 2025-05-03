import CoreLocation
import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var bluetoothManager = BluetoothManager()
    
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedColor: Color = .blue // User's own color
    @State private var showBluetoothList = false
    @State private var showAddFriends = false
    @State private var showRemoveFriends = false
    @State private var showEditFriendColor = false

    // ✅ State for Virtual Location Mode
    @State private var isVirtualModeActive = false
    @State private var virtualUserLocation: CLLocationCoordinate2D? = nil
    @State private var virtualFriendLocations: [String: CLLocationCoordinate2D] = [:] // [FriendID: VirtualCoord]

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

    // ✅ Killington Coordinates (Approximate Center)
    let killingtonCenter = CLLocationCoordinate2D(latitude: 43.6661, longitude: -72.7930)

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
                    friendColorOverrides: friendColorOverrides, // Pass the @State value
                    // Pass virtual mode state and data
                    isVirtualModeActive: isVirtualModeActive,
                    virtualUserLocation: virtualUserLocation,
                    virtualFriendLocations: virtualFriendLocations
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
                    if isVirtualModeActive {
                        Button("🏔️ Back to Reality") {
                            deactivateVirtualMode()
                        }
                        .buttonStyle(ActionButtonStyle(backgroundColor: .gray))
                    } else {
                        Button("⛷️ To the Slopes!") {
                            activateVirtualMode()
                        }
                        .buttonStyle(ActionButtonStyle(backgroundColor: .cyan)) // Use a different color
                    }
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
        // ✅ NEW: Observe changes in Firestore friends data
        .onChange(of: firestoreManager.friends) { _, newFriendsData in
            // If virtual mode is active, recalculate positions based on new real data
            if isVirtualModeActive {
                print("ContentView: Friends data updated while in virtual mode. Recalculating virtual positions...")
                // Call a helper function to avoid duplicating logic
                recalculateVirtualFriendLocations(basedOn: newFriendsData)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in // Use modern signature
            print("App Scene Phase Changed: \(newPhase)")
            if newPhase == .active {
                // App became active (foreground) - ensure location updates are running
                print("--> App became active. Ensuring location updates are started.")
                locationManager.startUpdates() // Attempt to start/restart updates
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
            
            firestoreManager.startListening() // Ensure this is called appropriately
            locationManager.startUpdates()
        }
        .onDisappear {
            print("✅ ContentView: .onDisappear FIRED.")
        }
    }

    // --- Virtual Mode Functions ---

    private func activateVirtualMode() {
        print("Activating Virtual Mode: Centering on Killington")
        guard let currentUserRealLocation = locationManager.location else {
            print("Cannot activate virtual mode: User location unknown.")
            return
        }
        // 1. Set Virtual User Location
        virtualUserLocation = killingtonCenter
        // 2. Calculate initial virtual friend locations
        recalculateVirtualFriendLocations(basedOn: firestoreManager.friends) // Use helper
        // 3. Activate mode
        isVirtualModeActive = true
    }

    private func recalculateVirtualFriendLocations(basedOn currentFriends: [Friend]) {
        guard let currentUserRealLocation = locationManager.location else {
            print("Recalculate Virtual: Cannot update, missing user's real location.")
            // Maybe deactivate virtual mode if user location is lost?
            // deactivateVirtualMode()
            return
        }
        guard isVirtualModeActive, let virtualCenter = virtualUserLocation else {
            // Don't calculate if not in virtual mode or center is missing
            return
        }

        var calculatedFriendLocations: [String: CLLocationCoordinate2D] = [:]
        let followedSet = Set(followingIDs.filter { !$0.isEmpty })

        for friend in currentFriends { // Use the passed-in (latest) friend data
            guard let friendID = friend.id, followedSet.contains(friendID) else { continue }

            let friendRealLocation = CLLocationCoordinate2D(latitude: friend.latitude, longitude: friend.longitude)
            guard CLLocationCoordinate2DIsValid(friendRealLocation) else { continue } // Check validity

            let distance = calculateDistance(from: currentUserRealLocation, to: friendRealLocation)
            let bearing = calculateBearing(from: currentUserRealLocation, to: friendRealLocation)
            let virtualFriendCoord = calculateDestinationCoordinate(from: virtualCenter, distance: distance, bearing: bearing)

            calculatedFriendLocations[friendID] = virtualFriendCoord
            // Less verbose logging during recalculation:
            // print("-> Recalc Friend '\(friend.name)': Virtual Coord: \(virtualFriendCoord.latitude), \(virtualFriendCoord.longitude)")
        }

        // Update the state - this will trigger MapView redraw
        virtualFriendLocations = calculatedFriendLocations
        print("--> Virtual friend locations recalculated: \(virtualFriendLocations.count) friends.")
    }

    private func deactivateVirtualMode() {
        print("Deactivating Virtual Mode.")
        isVirtualModeActive = false
        virtualUserLocation = nil
        virtualFriendLocations = [:]
        // Optional: Animate map camera back to user's real location?
        // MapView could handle this.
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

    // --- Geolocation Helper Functions ---

    func calculateDistance(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return originLocation.distance(from: destinationLocation) // Distance in meters
    }

    func calculateBearing(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let lat1 = origin.latitude.toRadians()
        let lon1 = origin.longitude.toRadians()
        let lat2 = destination.latitude.toRadians()
        let lon2 = destination.longitude.toRadians()
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).toDegrees()
        return (bearing + 360).truncatingRemainder(dividingBy: 360) // Bearing 0-360°
    }

    func calculateDestinationCoordinate(from start: CLLocationCoordinate2D, distance: CLLocationDistance, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius: CLLocationDistance = 6_371_000 // Earth radius in meters (approx)
        let angularDistance = distance / earthRadius // Angular distance in radians

        let lat1 = start.latitude.toRadians()
        let lon1 = start.longitude.toRadians()
        let bearingRad = bearing.toRadians()

        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(latitude: lat2.toDegrees(), longitude: lon2.toDegrees())
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
