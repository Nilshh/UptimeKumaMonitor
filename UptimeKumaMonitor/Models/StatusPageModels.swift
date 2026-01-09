import Foundation

// Status Page API Response Structure
struct StatusPageAPIResponse: Codable {
    let config: StatusPageConfig
    let incident: StatusPageIncident?
    let publicGroupList: [PublicGroup]
    let maintenanceList: [Maintenance]
}

struct StatusPageConfig: Codable {
    let slug: String
    let title: String
    let description: String?
    let icon: String?
    let autoRefreshInterval: Int?
    let theme: String?
    let published: Bool?
    let showTags: Bool?
    let customCSS: String?
    let footerText: String?
    let showPoweredBy: Bool?
    let googleAnalyticsId: String?
    let showCertificateExpiry: Bool?
}

struct StatusPageIncident: Codable {
    let id: Int?
    let title: String?
    let content: String?
}

struct PublicGroup: Codable {
    let id: Int
    let name: String
    let weight: Int
    let monitorList: [StatusPageMonitor]
}

struct StatusPageMonitor: Codable {
    let id: Int
    let name: String
    let sendUrl: Int?
    let type: String?
    let url: String?
    let maintenance: Bool?
    let description: String?
    
    // Konvertierung zu unserem Monitor-Model
    func toMonitor() -> Monitor {
        Monitor(
            id: id,
            name: name,
            description: description,
            type: type ?? "http",
            url: url,
            method: nil,
            body: nil,
            headers: nil,
            uptime: 0.0,
            status: "unknown",
            lastCheck: nil,
            certificateExpiryDays: nil
        )
    }
}

struct Maintenance: Codable {
    let id: Int?
    let title: String?
}
