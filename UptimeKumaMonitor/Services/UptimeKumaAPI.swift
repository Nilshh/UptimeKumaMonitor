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
            
            var allMonitors: [Monitor] = []
            for group in statusPageResponse.publicGroupList {
                print("  📦 Group: \(group.name) - \(group.monitorList.count) monitors")
                for spMonitor in group.monitorList {
                    let monitor = spMonitor.toMonitor()
                    print("    → Monitor: \(monitor.name), maintenance: \(spMonitor.maintenance ?? false), status: \(monitor.status)")
                    allMonitors.append(monitor)
                }
            }
            
            print("✅ Total monitors extracted: \(allMonitors.count)")
            
            DispatchQueue.main.async {
                self.monitors = allMonitors.sorted { $0.name < $1.name }
                self.lastUpdateTime = Date()
                self.isLoading = false
                
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
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid heartbeat URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Heartbeat request failed")
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let heartbeatResponse = try decoder.decode(HeartbeatResponse.self, from: data)
            print("✅ Heartbeat data received")
            
            // WICHTIG: Neues Array erstellen statt direkt zu mutieren
            var updatedMonitors = self.monitors
            
            for (index, monitor) in updatedMonitors.enumerated() {
                let monitorIdStr = String(monitor.id)
                
                // Wartungsmodus beibehalten, wenn bereits gesetzt
                let isInMaintenance = monitor.isMaintenance
                
                // Heartbeats holen
                if let heartbeats = heartbeatResponse.heartbeatList[monitorIdStr],
                   let latestHeartbeat = heartbeats.first {
                    
                    // Uptime aus uptimeList holen
                    var uptime = 0.0
                    for (key, value) in heartbeatResponse.uptimeList {
                        if key.starts(with: "\(monitorIdStr)_") {
                            uptime = value * 100.0
                            break
                        }
                    }
                    
                    // Status bestimmen - Wartungsmodus hat Priorität
                    let newStatus: String
                    if isInMaintenance {
                        newStatus = "maintenance"
                    } else {
                        newStatus = latestHeartbeat.status == 1 ? "up" : "down"
                    }
                    
                    print("  ✅ Monitor \(monitor.id) (\(monitor.name)): status=\(newStatus), uptime=\(String(format: "%.2f", uptime))%, isMaintenance=\(isInMaintenance)")
                    
                    let updatedMonitor = Monitor(
                        id: monitor.id,
                        name: monitor.name,
                        description: monitor.description,
                        type: monitor.type,
                        url: monitor.url,
                        method: monitor.method,
                        body: monitor.body,
                        headers: monitor.headers,
                        uptime: uptime,
                        status: newStatus,
                        lastCheck: nil,
                        certificateExpiryDays: nil
                    )
                    
                    updatedMonitors[index] = updatedMonitor
                }
            }
            
            // Komplettes Array neu zuweisen -> triggert SwiftUI Update
            DispatchQueue.main.async {
                self.monitors = updatedMonitors
                print("✅ Heartbeat update complete - UI should refresh now")
            }
            
        } catch {
            print("❌ Heartbeat error:", error)
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
struct HeartbeatResponse: Codable {
    let heartbeatList: [String: [Heartbeat]]
    let uptimeList: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case heartbeatList
        case uptimeList
    }
}

struct Heartbeat: Codable {
    let status: Int // 1 = up, 0 = down
    let time: String // Format: "2026-01-09 07:12:26.500"
    let msg: String? // Optional
}
