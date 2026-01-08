import SwiftUI

struct SettingsView: View {
    @ObservedObject var apiClient: UptimeKumaAPI
    @Binding var isConnected: Bool
    @Binding var showSettings: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Verbindungsmodus")) {
                    Picker("Modus", selection: $apiClient.connectionMode) {
                        ForEach(ConnectionMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Server")) {
                    TextField("Base URL", text: $apiClient.baseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                if apiClient.connectionMode == .statusPage {
                    Section(header: Text("Status Page")) {
                        TextField("Status Page Slug", text: $apiClient.statusPageSlug)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Text("z.B. 'demo' oder 'status'")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    Section(header: Text("Authentifizierung")) {
                        TextField("Benutzername", text: $apiClient.username)
                            .autocapitalization(.none)
                        SecureField("Passwort", text: $apiClient.password)
                    }
                }

                if let error = apiClient.errorMessage {
                    Section(header: Text("Fehler")) {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verbinden") {
                        Task {
                            await apiClient.login()
                            isConnected = apiClient.errorMessage == nil
                            if isConnected {
                                showSettings = false
                            }
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        showSettings = false
                    }
                }
            }
        }
    }
}
