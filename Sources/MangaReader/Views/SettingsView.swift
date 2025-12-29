import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = UserDefaultsManager.shared
    @State private var torboxApiKey: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        apiKeysSection
                        readingPreferencesSection
                        accountSection
                        aboutSection
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            loadApiKeys()
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var apiKeysSection: some View {
        SettingsSection(title: "API Keys", icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Torbox API Key")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                SecureField("Enter API Key", text: $torboxApiKey)
                    .textFieldStyle(DarkTextFieldStyle())
                
                Text("Get your API key from torbox.app")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: saveApiKeys) {
                    Text("Save API Key")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var readingPreferencesSection: some View {
        SettingsSection(title: "Reading", icon: "book.fill") {
            VStack(spacing: 16) {
                HStack {
                    Text("Reading Mode")
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $settings.readingMode) {
                        Text("Vertical").tag(ReadingMode.vertical)
                        Text("Horizontal").tag(ReadingMode.horizontal)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 180)
                }
                
                Toggle("Auto Download Chapters", isOn: $settings.autoDownload)
                    .foregroundColor(.white)
                    .tint(.blue)
                
                HStack {
                    Text("Download Quality")
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $settings.downloadQuality) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .tint(.blue)
                }
            }
        }
    }
    
    private var accountSection: some View {
        SettingsSection(title: "Account", icon: "person.fill") {
            VStack(spacing: 12) {
                Button(action: testTorboxConnection) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Test Torbox Connection")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(12)
                }
                
                NavigationLink(destination: TorrentManagementView()) {
                    HStack {
                        Image(systemName: "externaldrive")
                        Text("Manage Torbox Files")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle.fill") {
            VStack(spacing: 12) {
                HStack {
                    Text("Version")
                        .foregroundColor(.white)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                Link(destination: URL(string: "https://api.mangadex.org")!) {
                    HStack {
                        Text("MangaDex API")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.gray)
                    }
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                Link(destination: URL(string: "https://torbox.app")!) {
                    HStack {
                        Text("Torbox")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private func loadApiKeys() {
        do {
            torboxApiKey = try KeychainManager.shared.get(forKey: "torbox_api_key")
            TorboxService.shared.setApiKey(torboxApiKey)
        } catch {}
    }
    
    private func saveApiKeys() {
        do {
            if !torboxApiKey.isEmpty {
                try KeychainManager.shared.save(torboxApiKey, forKey: "torbox_api_key")
                TorboxService.shared.setApiKey(torboxApiKey)
            }
            alertMessage = "API key saved successfully!"
            showAlert = true
        } catch {
            alertMessage = "Failed to save API key: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func testTorboxConnection() {
        Task {
            do {
                _ = try await TorboxService.shared.getUserProfile()
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

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            content
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
    }
}

struct TorrentManagementView: View {
    @State private var torrents: [Torrent] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if torrents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No torrents found")
                        .foregroundColor(.gray)
                }
            } else {
                List(torrents) { torrent in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(torrent.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text(formatBytes(torrent.size))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("\(Int(torrent.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(torrent.progress >= 1.0 ? .green : .orange)
                        }
                        
                        ProgressView(value: torrent.progress)
                            .tint(torrent.progress >= 1.0 ? .green : .blue)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Torbox Torrents")
        .task {
            await loadTorrents()
        }
        .refreshable {
            await loadTorrents()
        }
    }
    
    private func loadTorrents() async {
        isLoading = true
        do {
            torrents = try await TorboxService.shared.getTorrents()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
