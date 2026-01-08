import SwiftUI

struct ContentView: View {
    @StateObject private var apiClient = UptimeKumaAPI()
    @State private var showSettings = false
    @State private var isConnected = false
    
    var body: some View {
        ZStack {
            if isConnected && !apiClient.monitors.isEmpty {
                NavigationView {
                    List {
                        Section(header: Text("Monitors")) {
                            ForEach(apiClient.monitors) { monitor in
                                NavigationLink(destination: MonitorDetailView(monitor: monitor)) {
                                    MonitorCard(monitor: monitor)
                                }
                            }
                        }
                        
                        if let lastUpdate = apiClient.lastUpdateTime {
                            Section(header: Text("Status")) {
                                HStack {
                                    Text("Last updated:")
                                    Spacer()
                                    Text(lastUpdate.formatted(date: .omitted, time: .standard))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Uptime Kuma")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack(spacing: 16) {
                                Button(action: {
                                    Task {
                                        await apiClient.fetchMonitors()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                }
                                
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gear")
                                }
                            }
                        }
                    }
                }
            } else {
                SettingsView(
                    apiClient: apiClient,
                    isConnected: $isConnected,
                    showSettings: $showSettings
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                apiClient: apiClient,
                isConnected: $isConnected,
                showSettings: $showSettings
            )
        }
        .onChange(of: apiClient.monitors) { monitors in
            NotificationManager.shared.checkAndNotifyStatusChanges(monitors: monitors)
        }
    }
}

#Preview {
    ContentView()
}
