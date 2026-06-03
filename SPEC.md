# Lumina SPEC

## Overview
Native SwiftUI frontend for iOS 18+ and macOS 15+. Pure Apple-ecosystem client for Cobalt media downloader API (imputnet/cobalt). Paste any supported link → fetch and save media without ads/trackers. Supports YouTube, Instagram, TikTok, X/Twitter, Vimeo, Reddit, SoundCloud, VK. Self-hosted or public instance. No webviews.

## App Name
**Lumina** – premium, native Apple naming.

## Key Requirements
- Universal SwiftUI app (shared code 90%+)
- URL input via text field, paste, or Share Sheet
- Real-time download progress with Estimated-Content-Length
- Save to Photos (video/image) or Files app
- Configurable Cobalt instance URL + API key
- Offline history (Core Data)
- iCloud sync for history/settings

## Supported Cobalt Features
- POST `/` JSON body: `url` (required) + options (`videoQuality`, `audioFormat`, `audioBitrate`, `downloadMode`, `filenameStyle`, `youtubeVideoCodec`, etc.)
- Response handling: `tunnel`/`redirect` (stream via GET `/tunnel`), `picker` (multi-item selection), `local-processing` (merge/mute/audio), `error`
- Headers: `Authorization: Api-Key ...`, rate-limit support
- Streaming with progress + filename from response

## User Flows
1. Open → paste/share link → select options → download
2. Preview thumbnail (where available)
3. Background downloads (iOS)
4. macOS: menu bar + drag-drop
5. Settings: instance URL, default quality, clear history

## Tech Details
- Swift 6, SwiftUI, Observation
- URLSession + async/await
- AVPlayer for video preview
- FileManager + UTType for saving
- Core Data for history
- WidgetKit for recent downloads
- No external packages

## UI/UX
- Minimal, system-native: NavigationStack, sheets, SF Symbols
- Dark/Light + Dynamic Island support
- macOS: sidebar + toolbar

## Non-Functional
- Privacy: no analytics, no telemetry
- Performance: <2s initial response
- Error handling: user-friendly messages for API errors/rate limits
- Localization: English + system

## MVP Scope (v1.0)
- Core download flow
- History
- Settings
- iOS + macOS targets

## Roadmap
- Apple Watch
- Batch downloads
- Custom filename templates
- In-app Cobalt instance status

Full native, production-ready spec.
