//
//  SettingsView.swift
//  Lumina
//

import SwiftUI
import LuminaKit

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var apiKey: String = ""
    @State private var testResult: TestResult?
    @State private var testing = false

    var body: some View {
        @Bindable var settings = app.settings
        Form {
            Section {
                TextField("URL", text: $settings.instanceURLString, prompt: Text(verbatim: "https://your-instance"))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                SecureField("API key", text: $apiKey, prompt: Text("optional"))
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        Text("Test connection")
                        if testing { Spacer(); ProgressView() }
                    }
                }
                .disabled(!settings.isConfigured || testing)
                if let testResult {
                    Label(testResult.message, systemImage: testResult.ok ? "checkmark.circle" : "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(testResult.ok ? .green : .red)
                }
            } header: {
                Text("Cobalt Instance")
            } footer: {
                Text("Use a self-hosted instance or one that accepts an API key. The public api.cobalt.tools blocks third-party apps.")
            }

            Section {
                Button {
                    app.showSetupGuide()
                } label: {
                    Label("Open setup guide", systemImage: "sparkles")
                }
            }

            Section("Saving") {
                Picker("Save to", selection: $settings.saveDestination) {
                    ForEach(SaveDestination.allCases) { destination in
                        Text(destination.label).tag(destination)
                    }
                }
            }

            Section("Defaults") {
                NavigationLink {
                    DownloadOptionsForm(options: $settings.defaultOptions)
                        .navigationTitle("Default Options")
                } label: {
                    Label("Default download options", systemImage: "slider.horizontal.3")
                }
            }

            Section("About") {
                LabeledContent("Privacy", value: "No analytics or tracking")
                LabeledContent("History sync", value: "iCloud")
                LabeledContent("Version", value: appVersion)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear { apiKey = app.settings.apiKey() ?? "" }
        .onChange(of: apiKey) { _, newValue in
            app.settings.setAPIKey(newValue.isEmpty ? nil : newValue)
        }
    }

    private func testConnection() async {
        testing = true
        let result = await app.testConnection()
        testResult = TestResult(ok: result.ok, message: result.message)
        testing = false
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private struct TestResult {
        let ok: Bool
        let message: String
    }
}
