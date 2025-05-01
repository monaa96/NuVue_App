import SwiftUI
import CoreBluetooth

struct BluetoothDeviceListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        NavigationView {
            List {
                ForEach(bluetoothManager.peripherals, id: \.identifier) { peripheral in
                    VStack(alignment: .leading) {
                        Text(peripheral.name ?? "Unnamed Device")
                            .font(.headline)
                        Text(peripheral.identifier.uuidString)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .onTapGesture {
                        bluetoothManager.connect(to: peripheral)
                    }
                }
            }
            .navigationTitle("Nearby Devices")
        }
        .onAppear {
            bluetoothManager.startScanning()
        }
        .onDisappear {
            bluetoothManager.stopScanning()
        }
    }
}

