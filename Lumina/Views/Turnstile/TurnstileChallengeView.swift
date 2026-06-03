//
//  TurnstileChallengeView.swift
//  Lumina
//
//  The single place Lumina renders web content: a confined WKWebView that hosts only the
//  Cloudflare Turnstile widget for a public instance, capturing the solved token.
//

import SwiftUI
import WebKit

struct TurnstileChallengeView: View {
    let context: TurnstileContext
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Complete the Cloudflare challenge to verify with this instance.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                TurnstileWebView(sitekey: context.sitekey, baseURL: baseURL) { token in
                    Task { await app.completeTurnstile(token: token) }
                }
            }
            .navigationTitle("Verify you’re human")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.cancelTurnstile() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    /// The Turnstile sitekey for the official instance is registered to the frontend domain,
    /// so render the challenge with that origin; self-hosted instances use their own origin.
    private var baseURL: URL {
        if context.instanceURL.host() == "api.cobalt.tools" {
            return URL(string: "https://cobalt.tools")!
        }
        let scheme = context.instanceURL.scheme ?? "https"
        let host = context.instanceURL.host() ?? "localhost"
        return URL(string: "\(scheme)://\(host)") ?? context.instanceURL
    }
}

#if os(macOS)
private typealias PlatformViewRepresentable = NSViewRepresentable
#else
private typealias PlatformViewRepresentable = UIViewRepresentable
#endif

struct TurnstileWebView: PlatformViewRepresentable {
    let sitekey: String
    let baseURL: URL
    let onToken: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken) }

    private func makeWebView(_ coordinator: Coordinator) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: "turnstile")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        #if os(iOS)
        webView.scrollView.isScrollEnabled = false
        #endif
        webView.loadHTMLString(Self.html(sitekey: sitekey), baseURL: baseURL)
        return webView
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView { makeWebView(context.coordinator) }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "turnstile")
    }
    #else
    func makeUIView(context: Context) -> WKWebView { makeWebView(context.coordinator) }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "turnstile")
    }
    #endif

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let onToken: (String) -> Void
        init(onToken: @escaping (String) -> Void) { self.onToken = onToken }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "turnstile", let token = message.body as? String, !token.isEmpty else { return }
            onToken(token)
        }
    }

    private static func html(sitekey: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
        <style>
          html, body { height: 100%; margin: 0; }
          body { display: flex; align-items: center; justify-content: center;
                 font-family: -apple-system, system-ui; background: transparent; }
        </style>
        </head><body>
        <div class="cf-turnstile" data-sitekey="\(sitekey)" data-callback="onSolve" data-theme="auto"></div>
        <script>function onSolve(token){ window.webkit.messageHandlers.turnstile.postMessage(token); }</script>
        </body></html>
        """
    }
}
