import SwiftUI

struct DevModeView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLog: APIRequestLog?
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var dev = viewModel.devMode
        VStack(spacing: 0) {
            devModeHeader
            Divider()
            Form {
                enableSection(dev: $dev)
                valuesSection(dev: $dev)
                requestLogSection
                extractedFieldsSection
                resetSection
            }
            .formStyle(.grouped)
            .confirmationDialog(
                "Reset to Initial State?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    viewModel.resetToInitialState()
                    dismiss()
                }
            } message: {
                Text("This will erase all settings, the API key, and request logs. The app will return to its initial unconfigured state.")
            }
        }
        .frame(minWidth: 480, idealWidth: 480, maxWidth: 480)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(item: $selectedLog) { log in
            RequestDetailView(log: log)
        }
    }

    // MARK: - Header

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

    // MARK: - Test Data

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
            Toggle("Budget limit", isOn: dev.hasMaxBudget)
                .onChange(of: dev.wrappedValue.hasMaxBudget) { _, _ in
                    Task { await viewModel.refresh() }
                }
            HStack {
                Text("Max Budget")
                    .foregroundStyle(dev.wrappedValue.hasMaxBudget ? .primary : .secondary)
                Spacer()
                TextField("0.00", value: dev.maxBudget, format: .currency(code: "USD"))
                    .frame(width: 100)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .disabled(!dev.wrappedValue.hasMaxBudget)
            }
            Toggle("Budget reset", isOn: dev.hasReset)
                .onChange(of: dev.wrappedValue.hasReset) { _, _ in
                    Task { await viewModel.refresh() }
                }
            HStack {
                Text("Days Remaining")
                    .foregroundStyle(dev.wrappedValue.hasReset ? .primary : .secondary)
                Spacer()
                TextField("0", value: dev.daysRemaining, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .disabled(!dev.wrappedValue.hasReset)
                Text("days")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Budget Period")
                    .foregroundStyle(dev.wrappedValue.hasReset ? .primary : .secondary)
                Spacer()
                TextField("0", value: dev.totalDays, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .disabled(!dev.wrappedValue.hasReset)
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

    // MARK: - Reset

    private var resetSection: some View {
        Section("Danger Zone") {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Reset to Initial State")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Request Log

    @ViewBuilder
    private var requestLogSection: some View {
        let logs = viewModel.requestLogger.logs
        Section {
            if logs.isEmpty {
                Text("No requests in the last 24 hours.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(logs) { log in
                            Button {
                                selectedLog = log
                            } label: {
                                RequestRowView(log: log)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            if log.id != logs.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        } header: {
            HStack {
                Text("Requests & Responses (last 24h)")
                Spacer()
                if !logs.isEmpty {
                    Button("Clear") {
                        viewModel.requestLogger.clear()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Extracted Fields

    @ViewBuilder
    private var extractedFieldsSection: some View {
        let recentFields = viewModel.requestLogger.logs
            .filter { !$0.extractedFields.isEmpty }
            .prefix(2)
            .flatMap { log in log.extractedFields.map { (log.endpoint, $0) } }

        if !recentFields.isEmpty {
            Section("Extracted Fields (latest responses)") {
                ScrollView(.vertical) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        GridRow {
                            Text("Endpoint").font(.caption).foregroundStyle(.secondary).bold()
                            Text("Field").font(.caption).foregroundStyle(.secondary).bold()
                            Text("Value").font(.caption).foregroundStyle(.secondary).bold()
                        }
                        Divider()
                        ForEach(Array(recentFields.enumerated()), id: \.offset) { _, pair in
                            let (endpoint, field) = pair
                            GridRow {
                                Text(endpoint)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(field.name)
                                    .font(.caption)
                                    .monospaced()
                                Text(field.value)
                                    .font(.caption)
                                    .monospaced()
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 200)
            }
        }
    }
}

// MARK: - Request Row

private struct RequestRowView: View {
    let log: APIRequestLog

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.endpoint)
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(.primary)
                    if let code = log.statusCode {
                        Text("HTTP \(code)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(log.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let err = log.errorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        if log.errorMessage != nil { return .red }
        if let code = log.statusCode, (200..<300).contains(code) { return .green }
        return .orange
    }
}

// MARK: - Request Detail

private struct RequestDetailView: View {
    let log: APIRequestLog
    @Environment(\.dismiss) private var dismiss
    @State private var copiedResponse = false
    @State private var copiedRequest = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.endpoint)
                        .font(.headline)
                        .monospaced()
                    HStack(spacing: 8) {
                        if let code = log.statusCode {
                            Text("HTTP \(code)")
                                .foregroundStyle(statusColor)
                        }
                        Text(log.timestamp.formatted(date: .abbreviated, time: .standard))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: Request
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Request")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .bold()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                Text(log.requestMethod ?? "GET")
                                    .font(.caption)
                                    .monospaced()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(log.requestURL)
                                    .font(.caption)
                                    .monospaced()
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let params = log.requestQueryParams, !params.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Query Parameters")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    ForEach(params.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                        HStack(spacing: 4) {
                                            Text(key)
                                                .font(.caption2)
                                                .monospaced()
                                                .foregroundStyle(.secondary)
                                            Text("=")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Text(value)
                                                .font(.caption2)
                                                .monospaced()
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                            }

                            if let headers = log.requestHeaders, !headers.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Headers")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                        HStack(spacing: 4) {
                                            Text(key)
                                                .font(.caption2)
                                                .monospaced()
                                                .foregroundStyle(.secondary)
                                            Text(":")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Text(value)
                                                .font(.caption2)
                                                .monospaced()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // MARK: Error
                    if let err = log.errorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .bold()
                            Text(err)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // MARK: Response Body
                    if !log.responseBody.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Response Body")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .bold()
                                Spacer()
                                Button(copiedResponse ? "Copied!" : "Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(log.responseBody, forType: .string)
                                    copiedResponse = true
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        copiedResponse = false
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                            Text(log.responseBody)
                                .font(.caption2)
                                .monospaced()
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(nsColor: .textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 500, idealWidth: 560, minHeight: 400, idealHeight: 500)
    }

    private var statusColor: Color {
        guard let code = log.statusCode else { return .secondary }
        if (200..<300).contains(code) { return .green }
        if code >= 400 { return .red }
        return .orange
    }
}