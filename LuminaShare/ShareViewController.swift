//
//  ShareViewController.swift
//  LuminaShare
//
//  Captures a shared link and hands it to the main app via the `lumina://` URL scheme.
//  No App Group needed (the link travels in the URL), so this works on a free team.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadSharedURL()
    }

    private func loadSharedURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            complete(); return
        }

        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] value, _ in
                if let url = value as? URL {
                    self?.handOff(url.absoluteString)
                } else if let data = value as? Data, let s = String(data: data, encoding: .utf8) {
                    self?.handOff(s)
                } else {
                    self?.complete()
                }
            }
        } else if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] value, _ in
                if let text = value as? String, let url = Self.firstURL(in: text) {
                    self?.handOff(url)
                } else {
                    self?.complete()
                }
            }
        } else {
            complete()
        }
    }

    private static func firstURL(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.url?.absoluteString
    }

    private func handOff(_ urlString: String) {
        var components = URLComponents()
        components.scheme = "lumina"
        components.host = "download"
        components.queryItems = [URLQueryItem(name: "url", value: urlString)]

        DispatchQueue.main.async { [weak self] in
            if let url = components.url { self?.open(url) }
            self?.complete()
        }
    }

    /// Open a URL from an app extension by walking the responder chain to an object that
    /// responds to `openURL:` (the documented APIs are unavailable inside extensions).
    private func open(_ url: URL) {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }

    private func complete() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
