import SwiftUI

struct MonitorDetailView: View {
    let monitor: Monitor
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            Section(header: Text("Status")) {
                HStack {
                    Text("Status")
                    Spacer()
                    StatusBadge(isUp: monitor.isUp)
                }
                
                HStack {
                    Text("Uptime")
                    Spacer()
                    Text(monitor.uptimePercentage)
                        .fontWeight(.semibold)
                }
            }
            
            Section(header: Text("Details")) {
                if let url = monitor.url {
                    HStack {
                        Text("URL")
                        Spacer()
                        Link(url, destination: URL(string: url) ?? URL(fileURLWithPath: ""))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                
                HStack {
                    Text("Typ")
                    Spacer()
                    Text(monitor.type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if let method = monitor.method {
                    HStack {
                        Text("HTTP-Methode")
                        Spacer()
                        Text(method)
                            .font(.caption)
                            .fontMonaco()
                    }
                }
                
                if let desc = monitor.description, !desc.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Beschreibung")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(desc)
                            .font(.body)
                    }
                }
            }
            
            // FEHLER 1 BEHOBEN: lastCheckDate → lastCheck
            if let lastCheck = monitor.lastCheck {
                Section(header: Text("Letzte Prüfung")) {
                    HStack {
                        Text("Zeitstempel")
                        Spacer()
                        Text(lastCheck.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(monitor.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    // FEHLER 2 & 3 BEHOBEN: Int64 → Date()
    let sampleMonitor = Monitor(
        id: 1,
        name: "API Service",
        description: "Main API endpoint",
        type: "http",
        url: "https://api.example.com/health",
        method: "GET",
        body: nil,
        headers: nil,
        uptime: 99.95,
        status: "up",
        lastCheck: Date(),
        certificateExpiryDays: 45
    )
    
    NavigationView {
        MonitorDetailView(monitor: sampleMonitor)
    }
}

extension View {
    func fontMonaco() -> some View {
        self.font(.system(.caption, design: .monospaced))
    }
}
