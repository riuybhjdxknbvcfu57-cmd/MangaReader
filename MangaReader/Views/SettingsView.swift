import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = UserDefaultsManager.shared
    @State private var torboxApiKey: String = ""
    @State private var mangadexApiKey: String = ""
    @State private var showSaveAlert = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Keys")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Torbox API Key")
                            .font(.headline)
                        SecureField("Enter Torbox API Key", text: $torboxApiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("Get your API key from https://api.torbox.app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MangaDex API Key")
                            .font(.headline)
                        SecureField("Enter MangaDex API Key (optional)", text: $mangadexApiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("Optional: For advanced MangaDex features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Save API Keys") {
                        saveApiKeys()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Section(header: Text("Reading Preferences")) {
                    Picker("Reading Mode", selection: $settings.readingMode) {
                        Text("Vertical Scroll").tag(ReadingMode.vertical)
                        Text("Horizontal Flip").tag(ReadingMode.horizontal)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("Auto Download Chapters", isOn: $settings.autoDownload)
                    
                    Picker("Download Quality", selection: $settings.downloadQuality) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                }
                
                Section(header: Text("Account")) {
                    Button("Test Torbox Connection") {
                        testTorboxConnection()
                    }
                    .buttonStyle(.bordered)
                    
                    NavigationLink("Manage Torbox Files") {
                        TorrentManagementView()
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("MangaDex API", destination: URL(string: "https://api.mangadex.org")!)
                    Link("Torbox API", destination: URL(string: "https://api.torbox.app")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadApiKeys()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func loadApiKeys() {
        do {
            torboxApiKey = try KeychainManager.shared.get(forKey: "torbox_api_key")
            mangadexApiKey = try KeychainManager.shared.get(forKey: "mangadex_api_key")
            
            TorboxService.shared.setApiKey(torboxApiKey)
        } catch {
        }
    }
    
    private func saveApiKeys() {
        do {
            if !torboxApiKey.isEmpty {
                try KeychainManager.shared.save(torboxApiKey, forKey: "torbox_api_key")
                TorboxService.shared.setApiKey(torboxApiKey)
            }
            
            if !mangadexApiKey.isEmpty {
                try KeychainManager.shared.save(mangadexApiKey, forKey: "mangadex_api_key")
            }
            
            alertMessage = "API keys saved successfully!"
            showAlert = true
        } catch {
            alertMessage = "Failed to save API keys: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func testTorboxConnection() {
        Task {
            do {
                let _ = try await TorboxService.shared.getUserProfile()
                
                await MainActor.run {
                    alertMessage = "Torbox connection successful!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Torbox connection failed: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

struct TorrentManagementView: View {
    @State private var torrents: [Torrent] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading torrents...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowInsets(EdgeInsets())
            } else if torrents.isEmpty {
                Text("No torrents found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowInsets(EdgeInsets())
            } else {
                ForEach(torrents) { torrent in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(torrent.name)
                            .font(.headline)
                        Text("Size: \(formatBytes(torrent.size))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Progress: \(Int(torrent.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(torrent.progress >= 1.0 ? .green : .orange)
                        Text("Status: \(torrent.status)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Torbox Torrents")
        .onAppear {
            loadTorrents()
        }
        .refreshable {
            loadTorrents()
        }
        .alert("Error", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("OK") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadTorrents() {
        isLoading = true
        Task {
            do {
                torrents = try await TorboxService.shared.getTorrents()
            } catch {
                errorMessage = "Failed to load torrents: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
