import SwiftUI

struct ContentView: View {
    @StateObject private var apiClient = UptimeKumaAPI()
    @State private var showSettings = false
    @State private var isConnected = false
    
    var body: some View {
        NavigationView {
            Group {
                if apiClient.monitors.isEmpty && !apiClient.isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Keine Monitore geladen")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Bitte Verbindung in den Einstellungen konfigurieren")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Einstellungen öffnen") {
                            showSettings = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(apiClient.monitors) { monitor in
                        MonitorRowView(monitor: monitor)
                    }
                    .refreshable {
                        await apiClient.login()
                    }
                }
            }
            .navigationTitle("Uptime Kuma")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if apiClient.isLoading {
                        ProgressView()
                    } else if let lastUpdate = apiClient.lastUpdateTime {
                        Text(lastUpdate, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    apiClient: apiClient,
                    isConnected: $isConnected,
                    showSettings: $showSettings
                )
            }
        }
    }
}

// MARK: - Monitor Row View
struct MonitorRowView: View {
    let monitor: Monitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Name + Status
            HStack {
                Text(monitor.name)
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    
                    // FEHLER BEHOBEN: statusDisplayText → statusText
                    Text(monitor.statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
            }
            
            // URL (falls vorhanden)
            if let url = monitor.url {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Verfügbarkeit
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // FEHLER BEHOBEN: uptimeDisplay → uptimePercentage
                Text(monitor.uptimePercentage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar für Uptime
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Hintergrund
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Fortschritt
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * CGFloat(monitor.uptime / 100.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        if monitor.isMaintenance {
            return .orange
        }
        return monitor.isUp ? .green : .red
    }
}

#Preview {
    ContentView()
}
