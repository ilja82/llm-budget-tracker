import SwiftUI

struct SettingsView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @State private var proxyURL: String = ""
    @State private var newAPIKey: String = ""
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var autoStart = AutoStartService.isEnabled
    @State private var autoStartError: String?
    @State private var versionTapCount = 0
    @State private var devModeUnlocked = UserDefaults.standard.bool(forKey: StorageKeys.DevMode.unlocked)
    @State private var showDevModeSheet = false
    @State private var apiKeyConfigured = false

    private let refreshOptions = [5, 15, 30, 60, 120]
    private let diagnosticsEnabledForBuild: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            connectionSection
            startupSection
            usageDataSection
            displaySection(vm: $vm)
            refreshSection(vm: $vm)
            if diagnosticsEnabledForBuild && devModeUnlocked {
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
            apiKeyConfigured = viewModel.devMode.isEnabled ? false : KeychainService.isConfigured
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

            if let validationMessage = proxyURLValidationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            SecureField(
                "API key",
                text: $newAPIKey,
                prompt: Text(apiKeyConfigured ? "Enter new key to replace existing" : "Paste your API key")
            )
                .textFieldStyle(.roundedBorder)
                .onChange(of: newAPIKey) { _, _ in
                    connectionStatus = .idle
                }

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Your API key is securely stored in the macOS Keychain."
                                + " You may be prompted to enter your macOS login password when saving it."
                                + " To avoid being prompted again, select 'Always Allow' on the password input screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 8) {
                Spacer()
                Button("Test Connection") {
                    performConnectionTest()
                }
                .disabled(isTesting || !isFormFilled)

                Button("Save") {
                    saveConnection()
                }
                .disabled(isTesting || !canSave)
                .buttonStyle(.borderedProminent)
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
                ProgressView().controlSize(.small)
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

    // MARK: - Startup Section

    private var startupSection: some View {
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
            Text("Starts LLM Budget Tracker automatically so your budget is always visible in the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let err = autoStartError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Startup")
        }
    }

    // MARK: - Usage Data Section

    private var usageDataSection: some View {
        Section {
            Toggle("Show Daily Activity", isOn: Binding(
                get: { viewModel.dailyActivityEnabled },
                set: { enabled in
                    Task { await viewModel.setDailyActivityEnabled(enabled) }
                }
            ))
            Text("Adds daily charts and activity details to the popup.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Usage Data")
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
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                Text("LLM Budget Tracker v\(version)")
                    .font(.caption2)
                    .foregroundStyle(
                        diagnosticsEnabledForBuild && devModeUnlocked
                            ? Color.orange.opacity(0.6)
                            : Color.secondary.opacity(0.5)
                    )
                    .onTapGesture {
                        guard diagnosticsEnabledForBuild else { return }
                        versionTapCount += 1
                        if versionTapCount >= 7 {
                            versionTapCount = 0
                            devModeUnlocked.toggle()
                            UserDefaults.standard.set(devModeUnlocked, forKey: StorageKeys.DevMode.unlocked)
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
        (try? EndpointSecurity.normalizedBaseURLString(from: proxyURL)) != nil
    }

    private var proxyURLValidationMessage: String? {
        guard !proxyURL.isEmpty else { return nil }
        do {
            _ = try EndpointSecurity.normalizedBaseURLString(from: proxyURL)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var canSave: Bool {
        !proxyURL.isEmpty && !newAPIKey.isEmpty && isProxyURLValid
    }

    private var isTesting: Bool {
        if case .testing = connectionStatus { return true }
        return false
    }

    private func performConnectionTest() {
        guard let normalizedURL = try? EndpointSecurity.normalizedBaseURLString(from: proxyURL) else {
            connectionStatus = .result(proxyURLErrorMessage, false)
            return
        }
        connectionStatus = .testing
        Task {
            let result = await viewModel.testConnection(url: normalizedURL, apiKey: newAPIKey)
            connectionStatus = .result(result.message, result.isSuccess)
        }
    }

    private func saveConnection() {
        guard !proxyURL.isEmpty,
              !newAPIKey.isEmpty,
              let normalizedURL = try? EndpointSecurity.normalizedBaseURLString(from: proxyURL) else { return }
        do {
            try KeychainService.save(newAPIKey)
            viewModel.endpointURL = normalizedURL
            proxyURL = normalizedURL
            viewModel.clearDailyActivityData()
            newAPIKey = ""
            apiKeyConfigured = true
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

    private var proxyURLErrorMessage: String {
        proxyURLValidationMessage ?? "Enter a valid LiteLLM proxy URL."
    }
}

// MARK: - Supporting Types

private enum ConnectionStatus {
    case idle
    case testing
    case result(String, Bool)
}
