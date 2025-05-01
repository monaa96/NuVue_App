import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var bluetoothManager = BluetoothManager()

    @State private var selectedColor: Color = .blue
    @State private var showBluetoothList = false
    @State private var showAddFriends = false
    @State private var showRemoveFriends = false
    @State private var showEditFriendColor = false

    @AppStorage("followingIDs") private var followingIDsString: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("friendColorOverrides") private var friendColorOverridesData: Data = Data()

    @State private var friendColorOverrides: [String: Color] = [:]

    private var followingIDs: [String] {
        get { followingIDsString.split(separator: ",").map { String($0) } }
        set { followingIDsString = newValue.joined(separator: ",") }
    }

    var body: some View {
        VStack {
            if username.isEmpty {
                UsernameSetupView(locationManager: locationManager, firestoreManager: firestoreManager)
            } else {
                MapView(
                    locationManager: locationManager,
                    firestoreManager: firestoreManager,
                    selectedColor: $selectedColor,
                    followingIDs: followingIDs,
                    friendColorOverrides: friendColorOverrides
                )

                Spacer()

                VStack(spacing: 10) {
                    HStack {
                        Button("Connect Bluetooth") {
                            showBluetoothList = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        Button("Add Friends") {
                            showAddFriends = true
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    Button("Remove Friends") {
                        showRemoveFriends = true
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Button("🎨 Edit Friend Colors") {
                        showEditFriendColor = true
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Button("➕ Add Fake Friends") {
                        addFakeFriends()
                    }
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showBluetoothList) {
            BluetoothDeviceListView(bluetoothManager: bluetoothManager)
        }
        .sheet(isPresented: $showAddFriends) {
            AddFriendView(firestoreManager: firestoreManager, followingIDsString: $followingIDsString)
        }
        .sheet(isPresented: $showRemoveFriends) {
            RemoveFriendView(followingIDsString: $followingIDsString)
        }
        .sheet(isPresented: $showEditFriendColor) {
            FriendColorListView(
                followingIDs: followingIDs,
                friendColorOverrides: $friendColorOverrides
            )
        }
        .onChange(of: bluetoothManager.connectedPeripheral) { newPeripheral in
            if newPeripheral != nil {
                print("🔵 Bluetooth device connected — starting auto-send...")
                bluetoothManager.startAutoSending(
                    locationManager: locationManager,
                    firestoreManager: firestoreManager,
                    followingIDs: followingIDs
                )
            } else {
                print("🔴 Bluetooth device disconnected — stopping auto-send...")
                bluetoothManager.stopAutoSending()
            }
        }
        .onAppear {
            loadFriendColorOverrides()
        }
    }

    private func addFakeFriends() {
        let fakeFriends = [
            ("FakeUser1", 42.3601, -71.0589),
            ("FakeUser2", 41.8240, -71.4128)
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

    private func loadFriendColorOverrides() {
        if let decoded = try? JSONDecoder().decode([String: CodableColor].self, from: friendColorOverridesData) {
            friendColorOverrides = decoded.mapValues { $0.color }
        }
    }

    private func saveFriendColorOverrides() {
        let encoded = try? JSONEncoder().encode(friendColorOverrides.mapValues { CodableColor(color: $0) })
        friendColorOverridesData = encoded ?? Data()
    }
}

extension Color {
    static func random() -> Color {
        Color(
            red: Double.random(in: 0.2...1.0),
            green: Double.random(in: 0.2...1.0),
            blue: Double.random(in: 0.2...1.0)
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
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

