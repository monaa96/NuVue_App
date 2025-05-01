import SwiftUI

struct BluetoothSendView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var firestoreManager: FirestoreManager
    
    @AppStorage("followingIDs") private var followingIDsString: String = ""
    
    @State private var selectedColor: Color = .blue
    
    private var followingIDs: [String] {
        followingIDsString.split(separator: ",").map { String($0) }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Bluetooth Send View")
                .font(.largeTitle)
                .padding()

            ColorPicker("Select a Color", selection: $selectedColor)
                .padding()

            Button(action: {
                bluetoothManager.startAutoSending(
                    locationManager: locationManager,
                    firestoreManager: firestoreManager,
                    followingIDs: followingIDs
                )
            }) {
                Text("Start Sending Data")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                bluetoothManager.stopAutoSending()
            }) {
                Text("Stop Sending Data")
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

