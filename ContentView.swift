import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager
    
    // MARK: - Time formatters
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"   // example: 3:26:35 PM
        return f
    }()
    
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"        // example: Sunday
        return f
    }()
    
    // MARK: - Timers
    private let timeTimer =
    Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    private let weatherTimer =
    Timer.publish(every: 600.0, on: .main, in: .common).autoconnect() // 10 min
    
    // MARK: - UI State
    @State private var currentTime: String = "--:--:--"
    @State private var searchText: String = "Pomona"
    @State private var currentCity: String = "Pomona"
    @State private var tempText: String = "-- F"
    @State private var conditionText: String = "--"
    @State private var hiLoText: String = "H --°  L --°"
    
    // Suggestions dropdown
    @State private var suggestions: [GeoCity] = []
    
    // OpenWeather key
    private let apiKey = "00ce8e9704991fb2c3b2f6bcde173521"
    
    var body: some View {
        ZStack {
            dynamicBackground(condition: conditionText)
                .ignoresSafeArea()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .blur(radius: 80)
                    .offset(x: -120, y: -260)
                
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .blur(radius: 90)
                    .offset(x: 140, y: 260)
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    headerSection
                    searchSection
                    weatherSection
                    timeSection
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
        }
        .foregroundColor(.white)
        .onAppear {
            updateTimeAndMaybeSend()
            fetchWeather(forQuery: currentCity)
        }
        .onReceive(timeTimer) { _ in
            updateTimeAndMaybeSend()
        }
        .onReceive(weatherTimer) { _ in
            fetchWeather(forQuery: currentCity)
        }
    }
}

// MARK: - Sections

private extension ContentView {
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("ARIS")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .kerning(4)
                
                Circle()
                    .fill(ble.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(radius: 4)
            }
            
            Text("Augmented Reality Integrated System")
                .font(.footnote.weight(.medium))
                .opacity(0.9)
            
            HStack(spacing: 8) {
                Image(systemName: ble.isConnected ? "antenna.radiowaves.left.and.right" : "bolt.slash")
                    .font(.caption)
                
                Text(ble.statusText)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .opacity(0.9)
                    
                    TextField("Search city (e.g. Pomona, US)", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .onChange(of: searchText) { newValue in
                            fetchSuggestions(for: newValue)
                        }
                        .font(.subheadline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                Button {
                    fetchWeather(forQuery: searchText)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.callout)
                        Text("Go")
                            .font(.callout.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.accentColor.opacity(0.95))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
                }
            }
            
            if !suggestions.isEmpty && searchText.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestions) { city in
                        Button {
                            let display = city.displayName
                            let query = city.queryString
                            searchText = display
                            currentCity = display
                            suggestions = []
                            fetchWeather(forQuery: query)
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.footnote)
                                Text(city.displayName)
                                    .font(.footnote)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if city.id != suggestions.last?.id {
                            Divider().overlay(Color.white.opacity(0.18))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 8)
            }
        }
    }
    
    var weatherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentCity)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text(conditionText)
                        .font(.subheadline)
                        .opacity(0.9)
                    
                    Text(tempText)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .padding(.top, 6)
                }
                
                Spacer()
                
                AnimatedWeatherIcon(condition: conditionText)
            }
            
            Divider().overlay(Color.white.opacity(0.12))
            
            HStack(spacing: 10) {
                Text(hiLoText)
                    .font(.footnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                
                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 22, x: 0, y: 16)
    }
    
    var timeSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "clock.badge.arrow.2.circlepath")
                        .font(.callout)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Time")
                        .font(.subheadline.weight(.semibold))
                    Text("Local device clock")
                        .font(.caption2)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            
            Text(currentTime)
                .font(.title3.monospacedDigit().weight(.medium))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 10)
    }
}

// MARK: - Time + BLE send

extension ContentView {
    private func updateTimeAndMaybeSend() {
        let now = Date()
        let formattedTime = timeFormatter.string(from: now)
        let weekday = dayFormatter.string(from: now)
        
        currentTime = formattedTime
        
        if ble.isConnected {
            // Send TIME with weekday: TIME:3:26:35 PM|Sunday
            ble.send("TIME:\(formattedTime)|\(weekday)")
        }
    }
}

// MARK: - Suggestions

extension ContentView {
    private func fetchSuggestions(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        
        let encoded =
        trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        
        let urlString =
        "https://api.openweathermap.org/geo/1.0/direct?q=\(encoded)&limit=5&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Geo error: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode([GeoCity].self, from: data)
                DispatchQueue.main.async {
                    self.suggestions = decoded
                }
            } catch {
                print("Geo decode failed: \(error)")
            }
        }.resume()
    }
}

// MARK: - Weather fetch + BLE send

extension ContentView {
    private func fetchWeather(forQuery query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let encoded =
        trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        
        let urlString =
        "https://api.openweathermap.org/data/2.5/weather?q=\(encoded)&units=imperial&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Weather error: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode(WeatherResponse.self, from: data)
                
                DispatchQueue.main.async {
                    currentCity = decoded.name
                    
                    let t  = Int(round(decoded.main.temp))
                    let hi = Int(round(decoded.main.tempMax))
                    let lo = Int(round(decoded.main.tempMin))
                    let cond = decoded.weather.first?.main ?? "--"
                    
                    tempText      = "\(t) F"
                    conditionText = cond
                    hiLoText      = "H \(hi)°  L \(lo)°"
                    
                    if ble.isConnected {
                        // Send WEATHER in a structured way:
                        // WEATHER:Pomona|72|H80|L45|Clouds
                        ble.send("WEATHER:\(currentCity)|\(t)|H\(hi)|L\(lo)|\(cond)")
                    }
                }
            } catch {
                print("Weather decode failed: \(error)")
            }
        }.resume()
    }
}

// MARK: - Background

extension ContentView {
    private func dynamicBackground(condition: String) -> LinearGradient {
        let c = condition.lowercased()
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 21 || hour <= 4
        
        if c.contains("snow") {
            return LinearGradient(
                colors: [Color(hue: 0.62, saturation: 0.15, brightness: 0.98),
                         Color(hue: 0.62, saturation: 0.3,  brightness: 0.75)],
                startPoint: .top, endPoint: .bottom
            )
        }
        
        if c.contains("rain") || c.contains("drizzle") || c.contains("storm") {
            return LinearGradient(
                colors: [Color(hue: 0.60, saturation: 0.25, brightness: 0.7),
                         Color(hue: 0.60, saturation: 0.6,  brightness: 0.4)],
                startPoint: .top, endPoint: .bottom
            )
        }
        
        if c.contains("mist") || c.contains("fog") || c.contains("haze") {
            return LinearGradient(
                colors: [Color(hue: 0.60, saturation: 0.05, brightness: 0.9),
                         Color(hue: 0.60, saturation: 0.15, brightness: 0.65)],
                startPoint: .top, endPoint: .bottom
            )
        }
        
        if c.contains("cloud") || c.contains("overcast") {
            if isNight {
                return LinearGradient(
                    colors: [Color(hue: 0.65, saturation: 0.4, brightness: 0.25),
                             Color.black],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                return LinearGradient(
                    colors: [Color(hue: 0.60, saturation: 0.2, brightness: 0.92),
                             Color(hue: 0.60, saturation: 0.35, brightness: 0.75)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        
        if c.contains("clear") || c == "--" {
            if isNight {
                return LinearGradient(
                    colors: [Color(hue: 0.67, saturation: 0.8, brightness: 0.35),
                             Color.black],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                return LinearGradient(
                    colors: [Color(hue: 0.03, saturation: 0.75, brightness: 0.96),
                             Color(hue: 0.58, saturation: 0.55, brightness: 0.96),
                             Color(hue: 0.58, saturation: 0.45, brightness: 0.86)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        
        return LinearGradient(
            colors: [Color(hue: 0.58, saturation: 0.55, brightness: 0.98),
                     Color(hue: 0.56, saturation: 0.40, brightness: 0.88)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Animated Weather Icon

struct AnimatedWeatherIcon: View {
    let condition: String
    @State private var animate = false
    
    private var kind: IconKind {
        let c = condition.lowercased()
        if c.contains("rain") || c.contains("drizzle") || c.contains("storm") { return .rain }
        if c.contains("snow") { return .snow }
        if c.contains("cloud") || c.contains("overcast") { return .clouds }
        return .sun
    }
    
    enum IconKind { case sun, clouds, rain, snow }
    
    var body: some View {
        ZStack {
            switch kind {
            case .sun:
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.yellow)
                    .rotationEffect(.degrees(animate ? 8 : -8))
                    .shadow(color: .yellow.opacity(0.6), radius: 10)
            case .clouds:
                ZStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 34))
                        .offset(x: animate ? 4 : -4, y: 0)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 26))
                        .offset(x: animate ? -6 : 6, y: 10)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
            case .rain:
                ZStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                    ForEach(0..<3) { i in
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.blue.opacity(0.9))
                            .offset(x: CGFloat(-10 + i * 10), y: animate ? 12 : 0)
                            .opacity(animate ? 0.3 + 0.2 * Double(i) : 0.95)
                    }
                }
            case .snow:
                ZStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                    ForEach(0..<4) { i in
                        Image(systemName: "snowflake")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .offset(x: CGFloat(-12 + i * 8), y: animate ? 10 : -2)
                            .opacity(animate ? 0.3 + 0.15 * Double(i) : 0.95)
                    }
                }
            }
        }
        .frame(width: 64, height: 64)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Models

struct GeoCity: Codable, Identifiable {
    let id = UUID()
    let name: String
    let state: String?
    let country: String
    
    private enum CodingKeys: String, CodingKey { case name, state, country }
    
    var displayName: String {
        var parts: [String] = [name]
        if let s = state, !s.isEmpty { parts.append(s) }
        parts.append(country)
        return parts.joined(separator: ", ")
    }
    
    var queryString: String {
        var parts: [String] = [name]
        if let s = state, !s.isEmpty { parts.append(s) }
        parts.append(country)
        return parts.joined(separator: ",")
    }
}

struct WeatherResponse: Codable {
    struct Main: Codable {
        let temp: Double
        let tempMin: Double
        let tempMax: Double
        enum CodingKeys: String, CodingKey {
            case temp
            case tempMin = "temp_min"
            case tempMax = "temp_max"
        }
    }
    
    struct WeatherItem: Codable {
        let main: String?
        let description: String?
    }
    
    let name: String
    let main: Main
    let weather: [WeatherItem]
}
