import Foundation
import SwiftData
import Testing
@testable import LuminaKit

@Suite("Persistence / SwiftData schema")
struct PersistenceTests {
    @Test func inMemoryContainerBuildsAndPersists() throws {
        let container = try LuminaStore.container(inMemory: true)
        let context = ModelContext(container)

        let record = DownloadRecord(
            sourceURLString: "https://y.test/v",
            service: "youtube",
            filename: "v.mp4",
            relativePath: "abc/v.mp4",
            mediaKind: .video,
            status: .completed,
            fileSize: 1024)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DownloadRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.mediaKind == .video)
        #expect(fetched.first?.status == .completed)
        #expect(fetched.first?.relativePath == "abc/v.mp4")
    }

    @Test func cascadeDeleteRemovesChildFiles() throws {
        let container = try LuminaStore.container(inMemory: true)
        let context = ModelContext(container)

        let record = DownloadRecord(filename: "album")
        let f1 = DownloadItemFile(filename: "1.jpg", mediaKind: .image)
        let f2 = DownloadItemFile(filename: "2.jpg", mediaKind: .image)
        record.files = [f1, f2]
        context.insert(record)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<DownloadItemFile>()).count == 2)

        context.delete(record)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<DownloadRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DownloadItemFile>()).isEmpty)
    }

    @Test func mediaKindClassification() {
        #expect(MediaKind.from(mime: "video/mp4", filename: nil) == .video)
        #expect(MediaKind.from(mime: "image/gif", filename: nil) == .gif)
        #expect(MediaKind.from(mime: nil, filename: "song.opus") == .audio)
        #expect(MediaKind.from(mime: nil, filename: "pic.heic") == .image)
        #expect(MediaKind.from(mime: nil, filename: "mystery.xyz") == .unknown)
    }

    @Test func instanceHostKeyNormalizes() {
        #expect(URL(string: "https://Cobalt.Example.com/")!.instanceHostKey == "cobalt.example.com")
        #expect(URL(string: "http://localhost:9000")!.instanceHostKey == "localhost:9000")
    }
}
