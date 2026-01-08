import Foundation
import Combine

struct StatusPageResponse: Codable {
    let ok: Bool
    let monitors: [Monitor]?
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

    // MARK: - Status Page Mode

    private func fetchViaStatusPage() async {
        let normalizedURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(normalizedURL)/api/status-page/\(statusPageSlug)"

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

            let decoded = try JSONDecoder().decode(StatusPageResponse.self, from: data)

            DispatchQueue.main.async {
                self.monitors = (decoded.monitors ?? []).sorted { $0.name < $1.name }
                self.lastUpdateTime = Date()
                self.isLoading = false
                self.startAutoRefresh()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Socket.io Mode

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
                if !monitors.isEmpty {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)

        socketService?.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
                self?.isLoading = false
            }
            .store(in: &cancellables)

        socketService?.connect()
    }

    // MARK: - Auto-Refresh

    func startAutoRefresh(interval: TimeInterval = 60) {
        stopAutoRefresh()
        if connectionMode == .statusPage {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task {
                    await self?.fetchViaStatusPage()
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func disconnect() {
        socketService?.disconnect()
        stopAutoRefresh()
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        baseURL = UserDefaults.standard.string(forKey: "uptimeKumaURL") ?? ""
        statusPageSlug = UserDefaults.standard.string(forKey: "uptimeKumaStatusPageSlug") ?? ""
        username = UserDefaults.standard.string(forKey: "uptimeKumaUsername") ?? ""
        password = UserDefaults.standard.string(forKey: "uptimeKumaPassword") ?? ""
        if let modeRaw = UserDefaults.standard.string(forKey: "uptimeKumaConnectionMode"),
           let mode = ConnectionMode(rawValue: modeRaw) {
            connectionMode = mode
        }
    }

    deinit {
        disconnect()
    }
}
