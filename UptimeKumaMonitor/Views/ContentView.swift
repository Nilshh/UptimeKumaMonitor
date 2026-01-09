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
                        Text("Keine Monitore geladen")
                            .font(.headline)
                        
                        Button("Einstellungen öffnen") {
                            showSettings = true
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    List(apiClient.monitors) { monitor in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(monitor.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Circle()
                                    .fill(monitor.isUp ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)
                            }
                            
                            if let url = monitor.url {
                                Text(url)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text("Uptime: \(monitor.uptimePercentage)")
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text(monitor.status.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(monitor.isUp ? .green : .red)
                            }
                        }
                        .padding(.vertical, 8)
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

#Preview {
    ContentView()
}
