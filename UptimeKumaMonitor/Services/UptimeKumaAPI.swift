import Foundation
import Combine

class UptimeKumaAPI: ObservableObject {
    @Published var monitors: [Monitor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    
    var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "uptimeKumaURL")
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
    
    private var refreshTimer: Timer?
    
    init(baseURL: String = "", username: String = "", password: String = "") {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        loadFromUserDefaults()
    }
    
    // MARK: - API Methods
    
    func login() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/api/entry/login") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL format"
                self.isLoading = false
            }
            return
        }
        
        let credentials = "\(username):\(password)"
        guard let credentialData = credentials.data(using: .utf8)?.base64EncodedString() else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to encode credentials"
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(credentialData)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginPayload: [String: String] = [
            "username": username,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONEncoder().encode(loginPayload)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to encode login data"
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                await fetchMonitors()
                startAutoRefresh()
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Authentication failed (Status: \(httpResponse.statusCode))"
                    self.isLoading = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Login error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func fetchMonitors() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/api/monitor") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
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
                throw NSError(domain: "HTTP", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Status Code: \(httpResponse.statusCode)"])
            }
            
            let response_dict = try JSONDecoder().decode([String: Monitor].self, from: data)
            
            DispatchQueue.main.async {
                self.monitors = Array(response_dict.values).sorted { $0.name < $1.name }
                self.lastUpdateTime = Date()
                self.isLoading = false
                self.saveToUserDefaults()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to fetch monitors: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func getMonitorStatus(id: Int) -> Double? {
        monitors.first(where: { $0.id == id })?.uptime
    }
    
    func startAutoRefresh(interval: TimeInterval = 60) {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchMonitors()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Persistence
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(monitors) {
            UserDefaults.standard.set(encoded, forKey: "cachedMonitors")
        }
    }
    
    private func loadFromUserDefaults() {
        baseURL = UserDefaults.standard.string(forKey: "uptimeKumaURL") ?? ""
        username = UserDefaults.standard.string(forKey: "uptimeKumaUsername") ?? ""
        password = UserDefaults.standard.string(forKey: "uptimeKumaPassword") ?? ""
        
        if let cachedData = UserDefaults.standard.data(forKey: "cachedMonitors"),
           let cached = try? JSONDecoder().decode([Monitor].self, from: cachedData) {
            monitors = cached
        }
    }
    
    deinit {
        stopAutoRefresh()
    }
}
