import SwiftUI

struct DevModeView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var dev = viewModel.devMode
        VStack(spacing: 0) {
            devModeHeader
            Divider()
            Form {
                enableSection(dev: $dev)
                valuesSection(dev: $dev)
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 380, idealWidth: 380, maxWidth: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var devModeHeader: some View {
        HStack {
            Image(systemName: "hammer.fill")
                .foregroundStyle(.orange)
            Text("Developer Mode")
                .font(.headline)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func enableSection(dev: Bindable<DevModeSettings>) -> some View {
        Section {
            Toggle("Override with Test Data", isOn: dev.isEnabled)
                .onChange(of: dev.wrappedValue.isEnabled) { _, _ in
                    Task { await viewModel.refresh() }
                }
        } footer: {
            Text("Bypasses all API calls and injects the values below. Disable to return to live data.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func valuesSection(dev: Bindable<DevModeSettings>) -> some View {
        Section("Test Values") {
            HStack {
                Text("Spend")
                Spacer()
                TextField("0.00", value: dev.spend, format: .currency(code: "USD"))
                    .frame(width: 100)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Max Budget")
                Spacer()
                TextField("0.00", value: dev.maxBudget, format: .currency(code: "USD"))
                    .frame(width: 100)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Days Remaining")
                Spacer()
                TextField("0", value: dev.daysRemaining, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                Text("days")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Budget Period")
                Spacer()
                TextField("0", value: dev.totalDays, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                Text("days total")
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack {
                    Spacer()
                    Text("Apply Test Values")
                    Spacer()
                }
            }
            .disabled(!viewModel.devMode.isEnabled)
        }
    }
}
