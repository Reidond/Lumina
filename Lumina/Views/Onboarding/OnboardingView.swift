//
//  OnboardingView.swift
//  Lumina
//
//  First-run setup guide: explains that Lumina needs a Cobalt instance, offers the
//  self-host route (the only one that reliably works for a third-party app), and lets the
//  user enter + test their instance before continuing.
//

import SwiftUI
import LuminaKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var apiKey = ""
    @State private var testing = false
    @State private var result: TestResult?

    private let dockerCommand =
        #"docker run -d --name cobalt -p 9000:9000 -e API_URL="http://localhost:9000/" ghcr.io/imputnet/cobalt"#

    var body: some View {
        @Bindable var settings = app.settings
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    explanation
                    selfHostSection
                    instanceSection
                    officialNote
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Set Up Lumina")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { app.finishOnboarding() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Get Started") { app.finishOnboarding() }
                        .disabled(!settings.isConfigured)
                }
            }
        }
        .interactiveDismissDisabled()
        .onAppear { apiKey = app.settings.apiKey() ?? "" }
        .onChange(of: apiKey) { _, newValue in app.settings.setAPIKey(newValue.isEmpty ? nil : newValue) }
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 600)
        #endif
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Welcome to Lumina")
                .font(.largeTitle.bold())
            Text("Download video and audio from YouTube, X, TikTok, Instagram and more.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var explanation: some View {
        Label {
            Text("Lumina downloads through a **Cobalt** instance — the open-source engine that does the work. Point Lumina at one to get started.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.callout)
    }

    private var selfHostSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Option 1 — Self-host (recommended)")
                .font(.headline)
            Text("Run your own instance with Docker, then use its address below. No challenges, full features.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                Text(dockerCommand)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Button {
                    copyToClipboard(dockerCommand)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help("Copy command")
            }
            Text("Then enter http://localhost:9000/ (or your server's address) below.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var instanceSection: some View {
        @Bindable var settings = app.settings
        return VStack(alignment: .leading, spacing: 12) {
            Text("Your instance")
                .font(.headline)
            TextField("URL", text: $settings.instanceURLString, prompt: Text(verbatim: "http://localhost:9000/"))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            SecureField("API key", text: $apiKey, prompt: Text("optional"))
                .textFieldStyle(.roundedBorder)
            HStack {
                Button {
                    Task { await runTest() }
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Test connection")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!settings.isConfigured || testing)

                if let result {
                    Label(result.message, systemImage: result.ok ? "checkmark.circle" : "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(result.ok ? .green : .red)
                }
            }
        }
    }

    private var officialNote: some View {
        Label {
            Text("Heads-up: the public **api.cobalt.tools** blocks third-party apps, so it won't work here.")
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func runTest() async {
        testing = true
        let r = await app.testConnection()
        result = TestResult(ok: r.ok, message: r.message)
        testing = false
    }

    private func copyToClipboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    private struct TestResult {
        let ok: Bool
        let message: String
    }
}
