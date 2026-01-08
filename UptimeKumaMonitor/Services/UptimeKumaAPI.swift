import Foundation
import Combine

struct StatusPageResponse: Codable {
    let ok: Bool
    let monitors: [Monitor]?
    
    enum CodingKeys: String, CodingKey {
        case ok
        case monitors
    }
}

enum ConnectionMode: String, Codable, CaseIterable, Identifiable {
    case statusPage = ".statusPage"
    case socketIO = ".socketIO"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .statusPage: return "Status Page (öffentlich)"
        case .socketIO: return "Socket.IO (mit Login)"
        }
    }
}

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
        // Normalize URL und erstelle korrekten Status Page Endpoint
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
            
            // Debug: Raw JSON ausgeben
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
            
            // Versuche direkt als Monitor-Array zu dekodieren (manche Status Pages liefern das so)
            do {
                let monitors = try decoder.decode([Monitor].self, from: data)
                print("✅ Decoded \(monitors.count) monitors directly as array")
                
                DispatchQueue.main.async {
                    self.monitors = monitors.sorted { $0.name < $1.name }
                    self.lastUpdateTime = Date()
                    self.isLoading = false
                    self.startAutoRefresh()
                }
                return
            } catch {
                print("⚠️ Not a direct array, trying StatusPageResponse wrapper")
            }
            
            // Fallback: Response mit Wrapper
            let decoded = try decoder.decode(StatusPageResponse.self, from: data)
            print("✅ Decoded StatusPageResponse: ok=\(decoded.ok), monitors=\(decoded.monitors?.count ?? 0)")
            
            DispatchQueue.main.async {
                self.monitors = (decoded.monitors ?? []).sorted { $0.name < $1.name }
                self.lastUpdateTime = Date()
                self.isLoading = false
                self.startAutoRefresh()
            }
            
        } catch {
            print("❌ Decode Error:", error)
            DispatchQueue.main.async {
                self.errorMessage = "Failed: \(error.localizedDescription)"
                self.isLoading = false
            }
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
