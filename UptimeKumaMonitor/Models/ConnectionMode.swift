import Foundation

enum ConnectionMode: String, CaseIterable, Identifiable, Codable {
    case statusPage = "Status Page"
    case socketIO = "Socket.io Login"

    var id: String { rawValue }
    var displayName: String { rawValue }
}
