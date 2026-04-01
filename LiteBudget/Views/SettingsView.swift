import SwiftUI

struct SettingsView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @State private var newSecret = ""
    @State private var secretSaveState: SecretSaveState = .idle
    @State private var autoStart = AutoStartService.isEnabled
    @State private var autoStartError: String?
    @State private var versionTapCount = 0
    @State private var devModeUnlocked = UserDefaults.standard.bool(forKey: "devMode.unlocked")
    @State private var showDevModeSheet = false

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            connectionSection(vm: $vm)
            displaySection(vm: $vm)
            systemSection
            if devModeUnlocked {
                devModeSection
            }
            versionFooter
        }
        .formStyle(.grouped)
        .frame(width: 400, height: devModeUnlocked ? 560 : 480)
        .sheet(isPresented: $showDevModeSheet) {
            DevModeView()
                .environment(viewModel)
        }
    }

    @ViewBuilder
    private func connectionSection(vm: Bindable<BudgetViewModel>) -> some View {
        Section {
            TextField("https://your-litellm-proxy.com", text: vm.endpointURL)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .firstTextBaseline) {
                SecureField("Paste new API key (write-only)", text: $newSecret)
                    .textFieldStyle(.roundedBorder)
                Button("Save") { saveSecret() }
                    .disabled(newSecret.isEmpty || secretSaveState == .saving)
            }

            secretFeedback
        } header: {
            Text("Connection")
        }
    }

    @ViewBuilder
    private var secretFeedback: some View {
        switch secretSaveState {
        case .idle: EmptyView()
        case .saving: ProgressView().scaleEffect(0.7)
        case .saved:
            Label("API key saved securely to Keychain", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .error(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(.caption).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func displaySection(vm: Bindable<BudgetViewModel>) -> some View {
        Section {
            Picker("Menu Bar Label", selection: vm.displayMode) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Refresh Every")
                Spacer()
                TextField("", value: vm.updateIntervalMinutes, format: .number)
                    .frame(width: 55)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                Text("minutes")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Display")
        }
    }

    private var systemSection: some View {
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
            Text("System")
        }
    }

    private var devModeSection: some View {
        Section {
            Button {
                showDevModeSheet = true
            } label: {
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundStyle(.orange)
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

    private var versionFooter: some View {
        Section {
            EmptyView()
        } footer: {
            HStack {
                Spacer()
                Text("LiteBudget v1.0")
                    .font(.caption2)
                    .foregroundStyle(devModeUnlocked ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.5))
                    .onTapGesture {
                        guard !devModeUnlocked else { return }
                        versionTapCount += 1
                        if versionTapCount >= 7 {
                            devModeUnlocked = true
                            UserDefaults.standard.set(true, forKey: "devMode.unlocked")
                        }
                    }
                Spacer()
            }
        }
    }

    private func saveSecret() {
        secretSaveState = .saving
        do {
            try KeychainService.save(newSecret)
            newSecret = ""
            secretSaveState = .saved
            Task {
                try? await Task.sleep(for: .seconds(3))
                secretSaveState = .idle
            }
        } catch {
            secretSaveState = .error(error.localizedDescription)
        }
    }
}

private enum SecretSaveState: Equatable {
    case idle, saving, saved, error(String)
}
