import Foundation

struct Monitor: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let description: String?
    let type: String
    let url: String?
    let method: String?
    let body: String?
    let headers: String?
    var uptime: Double
    var status: String
    let lastCheck: Date?
    let certificateExpiryDays: Int?
    var isMaintenance: Bool = false  // Neu hinzugefügt
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, type, url, method, body, headers
        case uptime, status, lastCheck, certificateExpiryDays, isMaintenance
    }
    
    var statusColor: String {
        if isMaintenance {
            return "maintenance"
        }
        
        switch status.lowercased() {
        case "up":
            return "up"
        case "down":
            return "down"
        case "maintenance":
            return "maintenance"
        default:
            return "unknown"
        }
    }
    
    var statusText: String {
        if isMaintenance {
            return "Wartung"
        }
        
        switch status.lowercased() {
        case "up":
            return "Online"
        case "down":
            return "Offline"
        case "maintenance":
            return "Wartung"
        default:
            return "Unbekannt"
        }
    }
    
    init(id: Int, name: String, description: String? = nil, type: String, url: String? = nil,
         method: String? = nil, body: String? = nil, headers: String? = nil,
         uptime: Double = 0.0, status: String = "unknown", lastCheck: Date? = nil,
         certificateExpiryDays: Int? = nil, isMaintenance: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.url = url
        self.method = method
        self.body = body
        self.headers = headers
        self.uptime = uptime
        self.status = status
        self.lastCheck = lastCheck
        self.certificateExpiryDays = certificateExpiryDays
        self.isMaintenance = isMaintenance
    }
}

enum ConnectionMode: String, Codable {
    case statusPage = "Status Page"
    case socketIO = "Socket.IO"
}
