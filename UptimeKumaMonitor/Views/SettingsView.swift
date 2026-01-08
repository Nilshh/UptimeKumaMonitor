import SwiftUI

struct SettingsView: View {
    @ObservedObject var apiClient: UptimeKumaAPI
    @Binding var isConnected: Bool
    @Binding var showSettings: Bool
    
    @State private var baseURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Uptime Kuma Server")) {
                    TextField("Server URL", text: $baseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .autocapitalization(.none)
                        } else {
                            SecureField("Password", text: $password)
                        }
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section {
                    if apiClient.isLoading {
                        HStack {
                            ProgressView()
                            Text("Connecting...")
                        }
                    } else {
                        Button(action: loginAction) {
                            Text("Connect")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                        .disabled(baseURL.isEmpty || username.isEmpty || password.isEmpty)
                        .listRowBackground(Color.blue)
                    }
                }
                
                if let error = apiClient.errorMessage {
                    Section(header: Text("Error")) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isConnected {
                        Button("Done") {
                            showSettings = false
                        }
                    }
                }
            }
            .onAppear {
                baseURL = apiClient.baseURL
                username = apiClient.username
                password = apiClient.password
            }
        }
    }
    
    private func loginAction() {
        apiClient.baseURL = baseURL
        apiClient.username = username
        apiClient.password = password
        
        Task {
            await apiClient.login()
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            if !apiClient.monitors.isEmpty {
                DispatchQueue.main.async {
                    isConnected = true
                    showSettings = false
                }
            }
        }
    }
}

#Preview {
    SettingsView(
        apiClient: UptimeKumaAPI(),
        isConnected: .constant(false),
        showSettings: .constant(true)
    )
}
