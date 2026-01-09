import SwiftUI

struct MonitorCard: View {
    let monitor: Monitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let desc = monitor.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                StatusBadge(isUp: monitor.isUp)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uptime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(monitor.uptimePercentage)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Typ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(monitor.type.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let monitor = Monitor(
        id: 1,
        name: "API Service",
        description: "Production API",
        type: "http",
        url: "https://api.example.com",
        method: "GET",
        body: nil,
        headers: nil,
        uptime: 99.95,
        status: "up",
        lastCheck: Date(),
        certificateExpiryDays: nil
    )
    
    MonitorCard(monitor: monitor)
        .padding()
}
