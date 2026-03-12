import Foundation
import Testing
@testable import KiroChatViewer

// MARK: - TitleEntry Tests

@Suite struct TitleEntryTests {

    @Test func codableRoundTrip() throws {
        let entry = TitleEntry(title: "My Chat", source: "manual", generatedAt: Date(timeIntervalSince1970: 1700000000))
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TitleEntry.self, from: data)
        #expect(decoded.title == "My Chat")
        #expect(decoded.source == "manual")
        #expect(decoded.generatedAt != nil)
    }

    @Test func codableWithNilDate() throws {
        let entry = TitleEntry(title: "Auto Title", source: "auto", generatedAt: nil)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TitleEntry.self, from: data)
        #expect(decoded.title == "Auto Title")
        #expect(decoded.source == "auto")
        #expect(decoded.generatedAt == nil)
    }

    @Test func dictionaryCodableRoundTrip() throws {
        let titles: [String: TitleEntry] = [
            "conv-1": TitleEntry(title: "First", source: "manual", generatedAt: nil),
            "conv-2": TitleEntry(title: "Second", source: "auto", generatedAt: Date())
        ]
        let data = try JSONEncoder().encode(titles)
        let decoded = try JSONDecoder().decode([String: TitleEntry].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded["conv-1"]?.title == "First")
        #expect(decoded["conv-2"]?.source == "auto")
    }

    @Test func legacyStringFormatMigration() throws {
        // Old format was [String: String], test that it can be decoded and migrated
        let oldFormat: [String: String] = ["conv-1": "Old Title", "conv-2": "Another"]
        let data = try JSONEncoder().encode(oldFormat)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        let migrated = decoded.mapValues { TitleEntry(title: $0, source: "manual", generatedAt: nil) }
        #expect(migrated["conv-1"]?.title == "Old Title")
        #expect(migrated["conv-1"]?.source == "manual")
    }
}

// MARK: - TitleManager Pin Logic Tests

@Suite struct TitlePinLogicTests {

    @Test func togglePinAddsAndRemoves() {
        var pinned: Set<String> = []
        // Pin
        pinned.insert("conv-1")
        #expect(pinned.contains("conv-1"))
        // Unpin
        pinned.remove("conv-1")
        #expect(!pinned.contains("conv-1"))
    }

    @Test func togglePinIdempotent() {
        var pinned: Set<String> = ["conv-1"]
        pinned.insert("conv-1") // already there
        #expect(pinned.count == 1)
    }

    @Test func pinnedSetCodableRoundTrip() throws {
        let pinned: Set<String> = ["conv-1", "conv-2", "conv-3"]
        let data = try JSONEncoder().encode(pinned)
        let decoded = try JSONDecoder().decode(Set<String>.self, from: data)
        #expect(decoded == pinned)
    }

    @Test func emptyPinnedSetRoundTrip() throws {
        let pinned: Set<String> = []
        let data = try JSONEncoder().encode(pinned)
        let decoded = try JSONDecoder().decode(Set<String>.self, from: data)
        #expect(decoded.isEmpty)
    }
}

// MARK: - Title Access Logic Tests

@Suite struct TitleAccessLogicTests {

    @Test func getTitleReturnsNilWhenMissing() {
        let titles: [String: TitleEntry] = [:]
        #expect(titles["conv-1"]?.title == nil)
    }

    @Test func getTitleReturnsValueWhenPresent() {
        let titles: [String: TitleEntry] = [
            "conv-1": TitleEntry(title: "Hello", source: "manual", generatedAt: nil)
        ]
        #expect(titles["conv-1"]?.title == "Hello")
    }

    @Test func setTitleOverwritesPrevious() {
        var titles: [String: TitleEntry] = [
            "conv-1": TitleEntry(title: "Old", source: "auto", generatedAt: nil)
        ]
        titles["conv-1"] = TitleEntry(title: "New", source: "manual", generatedAt: Date())
        #expect(titles["conv-1"]?.title == "New")
        #expect(titles["conv-1"]?.source == "manual")
    }

    @Test func hasTitleCheck() {
        let titles: [String: TitleEntry] = [
            "conv-1": TitleEntry(title: "X", source: "auto", generatedAt: nil)
        ]
        #expect(titles["conv-1"] != nil)
        #expect(titles["conv-2"] == nil)
    }
}
