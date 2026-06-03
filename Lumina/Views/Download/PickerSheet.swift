//
//  PickerSheet.swift
//  Lumina
//
//  Multi-item selection for a Cobalt `picker` response.
//

import SwiftUI
import LuminaKit

struct PickerSheet: View {
    let context: PickerContext
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<URL> = []
    @State private var includeAudio = true

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(context.items) { item in
                        PickerItemCell(item: item, selected: selection.contains(item.url))
                            .onTapGesture { toggle(item.url) }
                    }
                }
                .padding()
            }
            .navigationTitle("Select media")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download (\(selection.count))") {
                        let chosen = context.items.filter { selection.contains($0.url) }
                        Task { await app.confirmPicker(chosen, audio: includeAudio && context.audio != nil, context: context) }
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if context.audio != nil {
                    Toggle("Also download audio track", isOn: $includeAudio)
                        .padding()
                        .background(.bar)
                }
            }
        }
        .onAppear { if selection.isEmpty { selection = Set(context.items.map(\.url)) } }
    }

    private func toggle(_ url: URL) {
        if selection.contains(url) { selection.remove(url) } else { selection.insert(url) }
    }
}

struct PickerItemCell: View {
    let item: PickerItem
    let selected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: thumbnailURL) { phase in
                if case let .success(image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
            }
            .frame(width: 104, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3))

            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? Color.accentColor : .white)
                .background(Circle().fill(.black.opacity(0.25)))
                .padding(6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(selected ? Text("Selected") : Text("Not selected"))
    }

    private var accessibilityLabel: String {
        switch item.type {
        case .photo: String(localized: "Photo")
        case .video: String(localized: "Video")
        case .gif: String(localized: "GIF")
        }
    }

    private var thumbnailURL: URL? {
        item.thumb ?? (item.type == .photo ? item.url : nil)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .overlay(Image(systemName: symbol).font(.title).foregroundStyle(.secondary))
    }

    private var symbol: String {
        switch item.type {
        case .photo: "photo"
        case .video: "play.rectangle"
        case .gif: "rectangle.stack.badge.play"
        }
    }
}
