import Foundation
import CoreBluetooth

let bleServiceUUID = CBUUID(string: "1234")
let bleCharacteristicUUID = CBUUID(string: "5678")

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var statusText = "Disconnected"

    var centralManager: CBCentralManager!
    var espPeripheral: CBPeripheral?
    var txCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            statusText = "Scanning for ESP32..."
            centralManager.scanForPeripherals(withServices: [bleServiceUUID], options: nil)
        } else {
            statusText = "Bluetooth unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {

        espPeripheral = peripheral
        espPeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
        statusText = "Connecting..."
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusText = "Connected"
        isConnected = true
        peripheral.discoverServices([bleServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([bleCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == bleCharacteristicUUID {
                txCharacteristic = characteristic
                statusText = "Ready"
            }
        }
    }

    func send(_ message: String) {
        guard let characteristic = txCharacteristic else { return }
        let data = message.data(using: .utf8)!
        espPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }
}
