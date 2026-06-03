//
//  LuminaWidgetsBundle.swift
//  LuminaWidgets
//
//  Hosts Lumina's Live Activity. (A home-screen widget would also live here, but the
//  Recent-Downloads widget needs an App Group to read history and is intentionally omitted.)
//

import WidgetKit
import SwiftUI

@main
struct LuminaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivity()
    }
}
