import CoreBluetooth
import CoreLocation
import SwiftUI

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    @Published var peripherals: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?

    private var sendTimer: Timer?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Bluetooth Scanning and Connection

    func startScanning() {
        peripherals = []
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        centralManager.stopScan()
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            print("❌ Bluetooth is not available")
        }
    }

    func centralManager(_: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData _: [String: Any], rssi _: NSNumber) {
        if !peripherals.contains(peripheral) {
            peripherals.append(peripheral)
        }
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to peripheral: \(peripheral.name ?? "Unnamed")")
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error _: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
                print("✅ Found writable characteristic: \(characteristic.uuid)")
            }
        }
    }

    // MARK: - Sending Data

    func sendFriendData(locationManager: LocationManager, firestoreManager: FirestoreManager, followingIDs: [String], colorOverrides: [String: Color], distanceThreshold: Double = 50000000.0) {
        print("📤 [sendFriendData] called")

        guard let userLocation = locationManager.location else {
            print("❌ User location not available.")
            return
        }

        print("📍 User location: \(userLocation.latitude), \(userLocation.longitude)")
        print("👥 Total friends in Firestore: \(firestoreManager.friends.count)")
        print("🟢 Following \(followingIDs.count) friends: \(followingIDs)")

        let firestoreIDs = firestoreManager.friends.map { $0.id ?? "nil" }
        print("🟣 Firestore friend IDs: \(firestoreIDs)")

        let friendsToSend = firestoreManager.friends.filter { friend in
            guard let id = friend.id else {
                print("⚠️ Friend with nil ID skipped")
                return false
            }

            if followingIDs.contains(id) {
                print("✅ Will send data for friend: \(id)")
                return true
            } else {
                print("❌ Skipping friend (not in followingIDs): \(id)")
                return false
            }
        }

        print("📦 Sending \(friendsToSend.count) friends' data")

        for friend in friendsToSend {
            guard let friendID = friend.id else { continue } // Need friend ID

            let friendCoord = CLLocationCoordinate2D(latitude: friend.latitude, longitude: friend.longitude)
            let bearing = calculateBearing(from: userLocation, to: friendCoord)

            let userLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let friendLocation = CLLocation(latitude: friendCoord.latitude, longitude: friendCoord.longitude)
            let distance = userLocation.distance(from: friendLocation)

            if distance > distanceThreshold {
                print("🚫 Skipping friend — too far")
                continue
            }

            let displayColor: Color
            if let override = colorOverrides[friendID] { // Check for override
                displayColor = override
            } else { // Use default from friend object
                displayColor = Color(red: friend.r, green: friend.g, blue: friend.b)
            }

            // Convert the final displayColor to RGB Ints
            let uiColor = UIColor(displayColor)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil) // Use CGFloat

            // // Calculate distance in meters
            // let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            // let friendCLLocation = CLLocation(latitude: friendCoord.latitude, longitude: friendCoord.longitude)
            // let distance = userCLLocation.distance(from: friendCLLocation) // Distance in meters

            // Log distance for verification
            print("📏 Distance to \(friend.id ?? "unknown") : \(distance) meters")

            let id = Int(friend.id?.hashValue ?? 0) & 0xFFFF
            let r = Int(red * 255) // Use local variables
            let g = Int(green * 255)
            let b = Int(blue * 255)
            let bearingInt = Int(bearing)
            let distanceInt = Int(distance) // Convert distance to an integer (meters)

            // Include distance in the data packet
            let packet = "\(id),\(r),\(g),\(b),\(bearingInt),\(distanceInt)\n"
            print("📡 Packet: \(packet)")
            sendRawData(packet) // ✅ Make sure send is inside the loop
        }
    }

    func sendRawData(_ text: String) {
        print("📡 [Sending over Bluetooth]: \(text)")

        if let peripheral = connectedPeripheral,
           let characteristic = writeCharacteristic,
           let data = text.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            print("✅ Data sent")
        } else {
            print("❌ Missing peripheral or write characteristic — cannot send")
        }
    }

    func startAutoSending(locationManager: LocationManager, firestoreManager: FirestoreManager, followingIDs: [String], colorOverrides: [String: Color]) {
        sendTimer?.invalidate()

        print("⏰ Timer started for auto-sending")

        sendTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            print("⏰ Timer fired — attempting to send")
            self?.sendFriendData(
                locationManager: locationManager,
                firestoreManager: firestoreManager,
                followingIDs: followingIDs,
                colorOverrides: colorOverrides
            )
        }
    }

    func stopAutoSending() {
        sendTimer?.invalidate()
        sendTimer = nil
        print("🛑 Auto-sending stopped")
    }
}

// MARK: - Bearing Calculation Helpers

func calculateBearing(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
    let lat1 = origin.latitude.toRadians()
    let lon1 = origin.longitude.toRadians()
    let lat2 = destination.latitude.toRadians()
    let lon2 = destination.longitude.toRadians()

    let dLon = lon2 - lon1

    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = atan2(y, x).toDegrees()
    return (bearing + 360).truncatingRemainder(dividingBy: 360)
}

extension Double {
    func toRadians() -> Double { self * .pi / 180 }
    func toDegrees() -> Double { self * 180 / .pi }
}
