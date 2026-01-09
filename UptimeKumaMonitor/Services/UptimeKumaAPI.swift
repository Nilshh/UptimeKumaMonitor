import Foundation
import Combine

class UptimeKumaAPI: ObservableObject {
    @Published var monitors: [Monitor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    @Published var connectionMode: ConnectionMode = .statusPage
    
    var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "uptimeKumaURL")
        }
    }
    
    var statusPageSlug: String {
        didSet {
            UserDefaults.standard.set(statusPageSlug, forKey: "uptimeKumaStatusPageSlug")
        }
    }
    
    var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: "uptimeKumaUsername")
        }
    }
    
    var password: String {
        didSet {
            UserDefaults.standard.set(password, forKey: "uptimeKumaPassword")
        }
    }
    
    private var socketService: UptimeKumaSocketService?
    private var refreshTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        baseURL: String = "",
        statusPageSlug: String = "",
        username: String = "",
        password: String = "",
        connectionMode: ConnectionMode = .statusPage
    ) {
        self.baseURL = baseURL
        self.statusPageSlug = statusPageSlug
        self.username = username
        self.password = password
        self.connectionMode = connectionMode
        loadFromUserDefaults()
    }
    
    private func loadFromUserDefaults() {
        if let savedURL = UserDefaults.standard.string(forKey: "uptimeKumaURL"), !savedURL.isEmpty {
            baseURL = savedURL
        }
        if let savedSlug = UserDefaults.standard.string(forKey: "uptimeKumaStatusPageSlug"), !savedSlug.isEmpty {
            statusPageSlug = savedSlug
        }
        if let savedUsername = UserDefaults.standard.string(forKey: "uptimeKumaUsername"), !savedUsername.isEmpty {
            username = savedUsername
        }
        if let savedPassword = UserDefaults.standard.string(forKey: "uptimeKumaPassword"), !savedPassword.isEmpty {
            password = savedPassword
        }
    }
    
    func login() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        switch connectionMode {
        case .statusPage:
            await fetchViaStatusPage()
        case .socketIO:
            connectViaSocketIO()
        }
    }
    
    private func fetchViaStatusPage() async {
        let normalizedURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(normalizedURL)/api/status-page/\(statusPageSlug)"
        
        print("📡 Fetching Status Page from:", urlString)
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid Status Page URL"
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 RAW STATUS PAGE JSON:\n\(jsonString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NSError(
                    domain: "HTTP",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Status Code: \(httpResponse.statusCode)"]
                )
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let statusPageResponse = try decoder.decode(StatusPageAPIResponse.self, from: data)
            print("✅ Decoded Status Page: \(statusPageResponse.config.title)")
            
            // Monitore aus allen publicGroupList extrahieren
            var allMonitors: [Monitor] = []
            for group in statusPageResponse.publicGroupList {
                print("  📦 Group: \(group.name) - \(group.monitorList.count) monitors")
                for spMonitor in group.monitorList {
                    allMonitors.append(spMonitor.toMonitor())
                }
            }
            
            print("✅ Total monitors extracted: \(allMonitors.count)")
            
            DispatchQueue.main.async {
                self.monitors = allMonitors.sorted { $0.name < $1.name }
                self.lastUpdateTime = Date()
                self.isLoading = false
                
                // Heartbeat-Daten nachladen für Live-Status
                Task {
                    await self.fetchHeartbeatData()
                }
                
                self.startAutoRefresh()
            }
            
        } catch {
            print("❌ Status Page Error:", error)
            DispatchQueue.main.async {
                self.errorMessage = "Failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchHeartbeatData() async {
        let normalizedURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(normalizedURL)/api/status-page/heartbeat/\(statusPageSlug)"
        
        print("💓 Fetching Heartbeat from:", urlString)
        
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ Heartbeat request failed")
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("💓 RAW HEARTBEAT JSON:\n\(jsonString)")
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Heartbeat Response hat ein Dictionary mit Monitor-IDs als Keys
            let heartbeatData = try decoder.decode([String: HeartbeatList].self, from: data)
            
            print("✅ Heartbeat data received for \(heartbeatData.count) monitors")
            
            // Update Monitore mit Heartbeat-Daten
            DispatchQueue.main.async {
                for (index, monitor) in self.monitors.enumerated() {
                    let monitorIdStr = String(monitor.id)
                    
                    if let heartbeats = heartbeatData[monitorIdStr]?.heartbeatList,
                       let latestHeartbeat = heartbeats.first {
                        
                        // Update Monitor mit Live-Daten
                        let updatedMonitor = Monitor(
                            id: monitor.id,
                            name: monitor.name,
                            description: monitor.description,
                            type: monitor.type,
                            url: monitor.url,
                            method: monitor.method,
                            body: monitor.body,
                            headers: monitor.headers,
                            uptime: heartbeatData[monitorIdStr]?.uptime ?? 0.0,
                            status: latestHeartbeat.status == 1 ? "up" : "down",
                            lastCheck: Int64(latestHeartbeat.time),
                            certificateExpiryDays: nil
                        )
                        
                        self.monitors[index] = updatedMonitor
                    }
                }
                
                print("✅ Monitors updated with live heartbeat data")
            }
            
        } catch {
            print("⚠️ Heartbeat fetch failed:", error)
        }
    }
    
    private func connectViaSocketIO() {
        socketService = UptimeKumaSocketService(
            baseURL: baseURL,
            username: username,
            password: password
        )
        
        socketService?.$monitors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] monitors in
                self?.monitors = monitors
                self?.lastUpdateTime = Date()
            }
            .store(in: &cancellables)
        
        socketService?.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isLoading = !connected
            }
            .store(in: &cancellables)
        
        socketService?.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
        
        socketService?.connect()
    }
    
    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        
        if connectionMode == .statusPage {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                Task {
                    await self?.fetchViaStatusPage()
                }
            }
        }
    }
    
    func disconnect() {
        refreshTimer?.invalidate()
        socketService?.disconnect()
        socketService = nil
        cancellables.removeAll()
    }
    
    deinit {
        disconnect()
    }
}

// MARK: - Heartbeat Models
struct HeartbeatList: Codable {
    let heartbeatList: [Heartbeat]
    let uptime: Double
    
    enum CodingKeys: String, CodingKey {
        case heartbeatList
        case uptime
    }
}

struct Heartbeat: Codable {
    let status: Int  // 1 = up, 0 = down
    let time: Int
    let msg: String?
    let ping: Double?
    
    enum CodingKeys: String, CodingKey {
        case status
        case time
        case msg
        case ping
    }
}
