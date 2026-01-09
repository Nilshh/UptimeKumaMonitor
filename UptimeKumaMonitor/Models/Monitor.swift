import Foundation

struct Monitor: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String?
    let type: String
    let url: String?
    let method: String?
    let body: String?
    let headers: String?
    let uptime: Double
    let status: String
    let lastCheck: Int64?
    let certificateExpiryDays: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, type, url, method, body, headers, uptime, status
        case lastCheck = "last_check"
        case certificateExpiryDays = "cert_expiry_days"
    }
    
    var isUp: Bool {
        status.lowercased() == "up"
    }
    
    var isMaintenance: Bool {
        status.lowercased() == "maintenance"
    }
    
    var statusColor: String {
        isUp ? "green" : "red"
    }
    
    // Lokalisierter Status-Text
    var statusDisplayText: String {
        if isMaintenance {
            return "Wartung"
        }
        return isUp ? "Online" : "Offline"
    }
    
    // Farbe basierend auf Status
    var displayColor: String {
        if isMaintenance {
            return "orange"
        }
        return isUp ? "green" : "red"
    }
    
    var uptimePercentage: String {
        String(format: "%.2f%%", uptime)
    }
    
    // Verfügbarkeit mit Label
    var uptimeDisplay: String {
        "Verfügbarkeit (24h): \(uptimePercentage)"
    }
    
    var lastCheckDate: Date? {
        guard let lastCheck = lastCheck else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(lastCheck) / 1000)
    }
}
