//
//  RootView.swift
//  Lumina
//
//  Adaptive shell: a sidebar split view on macOS / iPad (regular width) and a tab bar on
//  iPhone (compact width).
//

import SwiftUI
import LuminaKit

struct RootView: View {
    @Environment(AppModel.self) private var app
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        platformBody
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first(where: { ($0.scheme ?? "").hasPrefix("http") }) else { return false }
                app.ingest(urlString: url.absoluteString)
                return true
            }
    }

    @ViewBuilder private var platformBody: some View {
        #if os(macOS)
        splitView
        #else
        if sizeClass == .regular {
            splitView
        } else {
            tabView
        }
        #endif
    }

    private var splitView: some View {
        @Bindable var app = app
        let selection = Binding<AppModel.Section?>(
            get: { app.section },
            set: { app.section = $0 ?? .download })
        return NavigationSplitView {
            List(selection: selection) {
                ForEach(AppModel.Section.allCases) { section in
                    Label(section.title, systemImage: section.symbol).tag(section)
                }
            }
            .navigationTitle("Lumina")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            #endif
        } detail: {
            NavigationStack {
                content(for: app.section)
            }
        }
    }

    #if os(iOS)
    private var tabView: some View {
        @Bindable var app = app
        return TabView(selection: $app.section) {
            ForEach(AppModel.Section.allCases) { section in
                NavigationStack {
                    content(for: section)
                }
                .tabItem { Label(section.title, systemImage: section.symbol) }
                .tag(section)
            }
        }
    }
    #endif

    @ViewBuilder
    private func content(for section: AppModel.Section) -> some View {
        switch section {
        case .download: DownloadView()
        case .history: HistoryListView()
        case .settings: SettingsView()
        }
    }
}
