import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager
   
    // formatter for readable time
    let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
   
    // timer that fires every second
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    @State private var weather = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("ESP32 BLE Sender")
                .font(.largeTitle).bold()
                .padding(.top)

            Text(ble.statusText)
                .foregroundColor(.blue)

            // Weather text field & button (manual)
            TextField("Weather", text: $weather)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button("Send Weather") {
                ble.send("WEATHER:\(weather)")
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 20)

            Text("Time is sent automatically every second.")
                .font(.footnote)
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
        .onReceive(timer) { _ in
            if ble.isConnected {
                let currentTime = formatter.string(from: Date())
                ble.send("TIME:\(currentTime)")
            }
        }
    }
}
