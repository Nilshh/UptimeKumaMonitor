import Foundation
import Combine
import SocketIO

class UptimeKumaSocketService: NSObject, ObservableObject {
    @Published var monitors: [Monitor] = []
    @Published var isConnected = false
    @Published var errorMessage: String?

    private let manager: SocketManager
    private let socket: SocketIOClient

    var baseURL: String
    var username: String
    var password: String

    init(baseURL: String, username: String, password: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.username = username
        self.password = password

        let config: SocketIOClientConfiguration = [
            .log(true),
            .compress,
            .reconnects(true),
            .reconnectWait(3)
        ]

        self.manager = SocketManager(socketURL: URL(string: self.baseURL)!, config: config)
        self.socket = manager.defaultSocket

        super.init()
        setupSocketHandlers()
    }

    private func setupSocketHandlers() {
        // Global Logging aller Events
        socket.onAny { event in
            print("SOCKET EVENT:", event.event, event.items ?? [])
        }

        // Server fordert explizit Login an
        socket.on("loginRequired") { [weak self] _, _ in
            print("Server requires login – sending credentials")
            self?.login()
        }

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            print("Socket connected")
        }

        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            print("Socket disconnected")
            self?.isConnected = false
        }

        socket.on(clientEvent: .error) { [weak self] data, _ in
            print("Socket error:", data)
            self?.errorMessage = "Socket error"
        }

        // Handler für Monitor-Liste vom Server (Dictionary mit IDs als Keys)
        socket.on("monitorList") { [weak self] data, _ in
            print("Monitor list raw:", data)

            guard let raw = data.first as? [String: Any] else {
                print("MonitorList: unexpected payload type:", type(of: data.first as Any))
                return
            }

            // raw ist z.B. ["1": { ...monitor... }]
            let monitorDicts = raw.values.compactMap { $0 as? [String: Any] }
            print("MonitorList extracted monitors count:", monitorDicts.count)

            self?.parseMonitors(monitorDicts)
        }

        // Heartbeat-Updates für einzelne Monitore
        socket.on("heartbeat") { [weak self] data, _ in
            print("Heartbeat raw:", data)

            guard let update = data.first as? [String: Any] else {
                print("Heartbeat: unexpected payload")
                return
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: update, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Heartbeat JSON:\n\(jsonString)")
            }

            self?.updateMonitor(update)
        }
    }

    func connect() {
        socket.connect()
    }

    func disconnect() {
        socket.disconnect()
    }

    private func login() {
        let loginData: [String: Any] = [
            "username": username,
            "password": password,
            "token": ""
        ]
        print("Emit login with:", loginData)
        socket.emit("login", loginData)

        // Da es kein loginResult gibt, nach kurzer Zeit Monitore anfordern
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Assuming login ok – requesting monitor list")
            self.getMonitors()
        }
    }

    private func getMonitors() {
        print("Emit getMonitorList")
        socket.emit("getMonitorList")
    }

    // Alte, manuelle Parsing-Methode – jetzt aktiv verwendet
    private func parseMonitors(_ data: [[String: Any]]) {
        var parsedMonitors: [Monitor] = []

        for item in data {
            let monitor = Monitor(
                id: item["id"] as? Int ?? 0,
                name: item["name"] as? String ?? "Unknown",
                description: item["description"] as? String,
                type: item["type"] as? String ?? "http",
                url: item["url"] as? String,
                method: item["method"] as? String,
                body: item["body"] as? String,
                headers: item["headers"] as? String,
                uptime: item["uptime"] as? Double ?? 0,
                status: item["status"] as? String ?? "unknown",
                lastCheck: item["lastCheck"] as? Int64,
                certificateExpiryDays: item["certificateExpiryDays"] as? Int
            )
            parsedMonitors.append(monitor)
        }

        DispatchQueue.main.async {
            self.monitors = parsedMonitors.sorted { $0.name < $1.name }
            print("Parsed monitors count:", self.monitors.count)
        }
    }

    private func updateMonitor(_ data: [String: Any]) {
        guard let id = data["monitorID"] as? Int else {
            print("Heartbeat: monitorID missing")
            return
        }

        DispatchQueue.main.async {
            guard let index = self.monitors.firstIndex(where: { $0.id == id }) else {
                print("Heartbeat: monitor with id \(id) not found in current list")
                return
            }

            var current = self.monitors[index]

            if let uptime = data["uptime"] as? Double {
                current = Monitor(
                    id: current.id,
                    name: current.name,
                    description: current.description,
                    type: current.type,
                    url: current.url,
                    method: current.method,
                    body: current.body,
                    headers: current.headers,
                    uptime: uptime,
                    status: current.status,
                    lastCheck: current.lastCheck,
                    certificateExpiryDays: current.certificateExpiryDays
                )
            }

            if let status = data["status"] as? String {
                current = Monitor(
                    id: current.id,
                    name: current.name,
                    description: current.description,
                    type: current.type,
                    url: current.url,
                    method: current.method,
                    body: current.body,
                    headers: current.headers,
                    uptime: current.uptime,
                    status: status,
                    lastCheck: current.lastCheck,
                    certificateExpiryDays: current.certificateExpiryDays
                )
            }

            self.monitors[index] = current
        }
    }
}
