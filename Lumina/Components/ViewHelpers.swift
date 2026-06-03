//
//  ViewHelpers.swift
//  Lumina
//

import SwiftUI

extension View {
    /// Makes the view draggable as a file when `url` is present (used for drag-out on macOS).
    @ViewBuilder
    func draggableFile(_ url: URL?) -> some View {
        if let url {
            self.draggable(url)
        } else {
            self
        }
    }
}
