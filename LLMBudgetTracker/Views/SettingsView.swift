import SwiftUI

struct SettingsView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @State private var proxyURL: String = ""
    @State private var newAPIKey: String = ""
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var autoStart = AutoStartService.isEnabled
    @State private var autoStartError: String?
    @State private var versionTapCount = 0
    @State private var devModeUnlocked = UserDefaults.standard.bool(forKey: "devMode.unlocked")
    @State private var showDevModeSheet = false

    private let refreshOptions = [5, 15, 30, 60, 120]
    private let chartDaysOptions = [7, 14, 21, 28]

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            connectionSection
            generalSection
            displaySection(vm: $vm)
            refreshSection(vm: $vm)
            if devModeUnlocked {
                advancedSection
            }
            versionFooter
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, idealWidth: 500, maxWidth: 500)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            proxyURL = viewModel.endpointURL
            autoStart = AutoStartService.isEnabled
        }
        .sheet(isPresented: $showDevModeSheet) {
            DevModeView()
                .environment(viewModel)
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section {
            TextField("URL", text: $proxyURL, prompt: Text("https://your-litellm-proxy.com"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: proxyURL) { _, _ in
                    connectionStatus = .idle
                }

            if !proxyURL.isEmpty && !proxyURL.hasPrefix("http://") && !proxyURL.hasPrefix("https://") {
                Text("Enter a valid Proxy URL.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            SecureField("API key", text: $newAPIKey, prompt: Text("Paste your API key"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: newAPIKey) { _, _ in
                    connectionStatus = .idle
                }

            HStack(spacing: 8) {
                Button("Test Connection") {
                    performConnectionTest()
                }
                .disabled(isTesting || !isFormFilled)

                Button("Save") {
                    saveConnection()
                }
                .disabled(isTesting || !canSave)
                .buttonStyle(.borderedProminent)

                Spacer()
            }

            connectionStatusView
        } header: {
            Text("Connection")
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch connectionStatus {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("Testing connection...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .result(let message, let success):
            Label(message, systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(success ? .green : .red)
        }
    }

    // MARK: - Display Section

    @ViewBuilder
    private func displaySection(vm: Bindable<BudgetViewModel>) -> some View {
        Section {
            Picker("Menu Bar Display", selection: vm.displayMode) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Picker("Charts time range", selection: vm.chartDays) {
                ForEach(chartDaysOptions, id: \.self) { days in
                    Text("Last \(days) days").tag(days)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Display")
        }
    }

    // MARK: - Refresh Section

    @ViewBuilder
    private func refreshSection(vm: Bindable<BudgetViewModel>) -> some View {
        Section {
            Picker("Auto-refresh interval", selection: vm.updateIntervalMinutes) {
                ForEach(refreshOptions, id: \.self) { minutes in
                    Text("\(minutes) minutes").tag(minutes)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Refresh")
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            Toggle("Launch at Login", isOn: $autoStart)
                .onChange(of: autoStart) { _, enabled in
                    do {
                        try AutoStartService.setEnabled(enabled)
                        autoStartError = nil
                    } catch {
                        autoStartError = error.localizedDescription
                        autoStart = !enabled
                    }
                }
            if let err = autoStartError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("General")
        } footer: {
            Text("When enabled, LLM Budget Tracker starts automatically so your budget is always visible in the menu bar.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Section {
            Button {
                showDevModeSheet = true
            } label: {
                HStack {
                    Text("Developer Mode")
                    Spacer()
                    if viewModel.devMode.isEnabled {
                        Text("ON")
                            .font(.caption).bold()
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Advanced")
        }
    }

    // MARK: - Version Footer

    private var versionFooter: some View {
        Section {
            EmptyView()
        } footer: {
            HStack {
                Spacer()
                Text("LLM Budget Tracker v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
                    .font(.caption2)
                    .foregroundStyle(devModeUnlocked ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.5))
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 7 {
                            versionTapCount = 0
                            devModeUnlocked.toggle()
                            UserDefaults.standard.set(devModeUnlocked, forKey: "devMode.unlocked")
                            if !devModeUnlocked, viewModel.devMode.isEnabled {
                                viewModel.devMode.isEnabled = false
                                Task { await viewModel.refresh() }
                            }
                        }
                    }
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private var isFormFilled: Bool {
        !proxyURL.isEmpty && !newAPIKey.isEmpty
    }

    private var isProxyURLValid: Bool {
        proxyURL.hasPrefix("http://") || proxyURL.hasPrefix("https://")
    }

    private var canSave: Bool {
        !proxyURL.isEmpty && !newAPIKey.isEmpty && isProxyURLValid
    }

    private var isTesting: Bool {
        if case .testing = connectionStatus { return true }
        return false
    }

    private func performConnectionTest() {
        guard isProxyURLValid else {
            connectionStatus = .result("Invalid URL", false)
            return
        }
        connectionStatus = .testing
        Task {
            let result = await viewModel.testConnection(url: proxyURL, apiKey: newAPIKey)
            connectionStatus = .result(result.message, result.isSuccess)
        }
    }

    private func saveConnection() {
        guard !proxyURL.isEmpty, !newAPIKey.isEmpty, isProxyURLValid else { return }
        viewModel.endpointURL = proxyURL
        do {
            try KeychainService.save(newAPIKey)
            newAPIKey = ""
            connectionStatus = .result("Settings saved", true)
            Task {
                try? await Task.sleep(for: .seconds(3))
                if case .result("Settings saved", _) = connectionStatus {
                    connectionStatus = .idle
                }
                await viewModel.refresh()
            }
        } catch {
            connectionStatus = .result(error.localizedDescription, false)
        }
    }
}

// MARK: - Supporting Types

private enum ConnectionStatus {
    case idle
    case testing
    case result(String, Bool)
}
