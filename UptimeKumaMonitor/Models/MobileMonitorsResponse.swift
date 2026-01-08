import Foundation

struct MobileMonitorsResponse: Codable {
    let ok: Bool
    let monitors: [Monitor]?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case monitors
        case msg
    }
}
