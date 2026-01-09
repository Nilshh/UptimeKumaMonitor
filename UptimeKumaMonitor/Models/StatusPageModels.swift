import Foundation

// MARK: - Status Page API Response
struct StatusPageAPIResponse: Codable {
    let config: StatusPageConfig
    let publicGroupList: [PublicGroup]
}

struct StatusPageConfig: Codable {
    let id: Int?  // ✅ Optional gemacht
    let slug: String
    let title: String
    let description: String?
    let icon: String?
    let theme: String?
    let published: Bool?
    let showTags: Bool?
    let domainNameList: [String]?
    let customCSS: String?
    let footerText: String?
    let showPoweredBy: Bool?
    let googleAnalyticsId: String?
    let showCertificateExpiry: Bool?
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
    let description: String?
    let type: String
    let url: String?
    let maintenance: Bool? // Dieses Feld ist wichtig!
    
    func toMonitor() -> Monitor {
        // ✅ FIX: Wenn maintenance true ist, setzen wir isMaintenance auf true
        let isInMaintenance = maintenance ?? false
        
        // ✅ FIX: Status sollte IMMER "unknown" sein, wird später durch Heartbeat aktualisiert
        // Nur im Wartungsmodus setzen wir direkt "maintenance"
        let monitorStatus = isInMaintenance ? "maintenance" : "unknown"
        
        // 🔍 DEBUG: Zum Testen hinzufügen
        print(" 🔍 DEBUG toMonitor: name=\(name), maintenance=\(maintenance ?? false), isMaintenance=\(isInMaintenance), status=\(monitorStatus)")
        
        return Monitor(
            id: id,
            name: name,
            description: description,
            type: type,
            url: url,
            uptime: 0.0,
            status: monitorStatus,
            isMaintenance: isInMaintenance
        )
    }
}
