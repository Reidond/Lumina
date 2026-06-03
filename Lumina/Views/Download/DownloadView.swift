//
//  DownloadView.swift
//  Lumina
//

import SwiftUI
import LuminaKit

struct DownloadView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Form {
            Section {
                urlField
                actionButtons
            } header: {
                Text("Link")
            } footer: {
                if !app.settings.isConfigured {
                    Label("Set a Cobalt instance in Settings to begin.", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            if !app.downloads.activeList.isEmpty {
                Section("Active") {
                    ForEach(app.downloads.activeList) { progress in
                        DownloadProgressRow(progress: progress) {
                            app.downloads.cancel(recordID: progress.id)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Download")
        .sheet(isPresented: $app.showingOptions) {
            DownloadOptionsSheet(options: $app.options)
        }
        .sheet(item: $app.pickerContext) { context in
            PickerSheet(context: context)
        }
        .sheet(item: $app.turnstileContext) { context in
            TurnstileChallengeView(context: context)
        }
        .alert(
            "Couldn’t fetch",
            isPresented: Binding(get: { app.alert != nil }, set: { if !$0 { app.alert = nil } }),
            presenting: app.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { context in
            Text(context.error.errorDescription ?? String(localized: "Something went wrong."))
        }
    }

    private var urlField: some View {
        @Bindable var app = app
        return HStack {
            TextField("Paste a link", text: $app.urlText, axis: .vertical)
                .lineLimit(1...3)
                .textContentType(.URL)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .onSubmit { Task { await app.fetch() } }
            if !app.urlText.isEmpty {
                Button {
                    app.urlText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            PasteLinkButton { link in app.urlText = link }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.tint)
        }
    }

    private var actionButtons: some View {
        @Bindable var app = app
        return HStack {
            Button {
                app.showingOptions = true
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                Task { await app.fetch() }
            } label: {
                if app.isFetching {
                    ProgressView()
                } else {
                    Label("Fetch", systemImage: "arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(app.urlText.trimmingCharacters(in: .whitespaces).isEmpty || app.isFetching)
        }
    }
}
