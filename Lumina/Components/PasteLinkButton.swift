//
//  PasteLinkButton.swift
//  Lumina
//
//  An always-enabled paste button that pulls a link off the clipboard as a URL or plain
//  text. (SwiftUI's PasteButton greys out unless the clipboard item matches an exact type,
//  which misses links copied as text.)
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PasteLinkButton: View {
    var onPaste: (String) -> Void

    var body: some View {
        Button {
            if let link = Self.clipboardLink() { onPaste(link) }
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        .help("Paste a link from the clipboard")
    }

    static func clipboardLink() -> String? {
        #if canImport(UIKit)
        if UIPasteboard.general.hasURLs, let url = UIPasteboard.general.url {
            return url.absoluteString
        }
        return UIPasteboard.general.string?.trimmedNonEmpty
        #elseif canImport(AppKit)
        return NSPasteboard.general.string(forType: .string)?.trimmedNonEmpty
        #else
        return nil
        #endif
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
