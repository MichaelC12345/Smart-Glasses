import SwiftUI

@main
struct MyApp: App {
    @StateObject var ble = BLEManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
        }
    }
}
