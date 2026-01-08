import Foundation

struct StatusPage: Identifiable, Codable {
    let id: Int
    let slug: String
    let title: String
    let description: String?
    let footer: String?
    let showTags: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, slug, title, description, footer
        case showTags = "show_tags"
    }
}
