//
//  MenuBarContentView.swift
//  Lumina
//
//  macOS menu-bar quick-download popover. Direct (tunnel/redirect) links download right
//  away; links that need a picker or Turnstile open in the main window.
//

#if os(macOS)
import SwiftUI
import LuminaKit

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 10) {
            Text("Lumina")
                .font(.headline)

            HStack {
                TextField("Paste a link", text: $app.urlText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await app.fetch() } }
                Button {
                    Task { await app.fetch() }
                } label: {
                    if app.isFetching { ProgressView().controlSize(.small) } else { Text("Fetch") }
                }
                .disabled(app.urlText.trimmingCharacters(in: .whitespaces).isEmpty || app.isFetching)
            }

            if !app.downloads.activeList.isEmpty {
                Divider()
                ForEach(app.downloads.activeList) { progress in
                    DownloadProgressRow(progress: progress) {
                        app.downloads.cancel(recordID: progress.id)
                    }
                }
            }

            Divider()
            HStack {
                Button("Open Lumina") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .font(.callout)
        }
        .padding(12)
        .frame(width: 340)
    }
}
#endif
