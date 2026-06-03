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
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(modelContainer)
    }
}
