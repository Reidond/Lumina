//
//  LuminaApp.swift
//  Lumina
//
//  Created by Andrii Shafar on 03.06.2026.
//

import SwiftUI
import SwiftData
import LuminaKit

@main
struct LuminaApp: App {
    let modelContainer: ModelContainer
    @State private var appModel: AppModel

    init() {
        // Prefer the shared App Group + CloudKit store; fall back to a local store so the
        // app still launches on a device/simulator without iCloud configured.
        let container = (try? LuminaStore.container()) ?? (try! LuminaStore.container(inMemory: true))
        modelContainer = container

        let settings = SettingsStore()
        let downloads = DownloadManager(container: container)
        _appModel = State(initialValue: AppModel(settings: settings, downloads: downloads))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(appModel)
                .onOpenURL { url in handleIncoming(url) }
        }
        .modelContainer(modelContainer)

        #if os(macOS)
        MenuBarExtra("Lumina", systemImage: "arrow.down.circle.fill") {
            MenuBarContentView()
                .environment(appModel)
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    /// Handle `lumina://download?url=<encoded>` from the Share Extension / widget deep links.
    @MainActor
    private func handleIncoming(_ url: URL) {
        guard url.scheme == "lumina" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch url.host {
        case "download":
            if let target = components?.queryItems?.first(where: { $0.name == "url" })?.value {
                appModel.ingest(urlString: target)
            }
        case "history":
            appModel.section = .history
        default:
            break
        }
    }
}
