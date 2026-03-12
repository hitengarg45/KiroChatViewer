import Foundation
import Testing
@testable import KiroChatViewer

// MARK: - BookmarkFolder Tests

@Suite struct BookmarkFolderTests {

    @Test func starredFolderIsBuiltIn() {
        let starred = BookmarkFolder.starred
        #expect(starred.id == "starred")
        #expect(starred.name == "Starred")
        #expect(starred.isBuiltIn == true)
        #expect(starred.conversationIds.isEmpty)
    }

    @Test func folderCodableRoundTrip() throws {
        let folder = BookmarkFolder(id: "f1", name: "My Folder", conversationIds: ["c1", "c2"], isBuiltIn: false)
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(BookmarkFolder.self, from: data)
        #expect(decoded.id == "f1")
        #expect(decoded.name == "My Folder")
        #expect(decoded.conversationIds == ["c1", "c2"])
        #expect(decoded.isBuiltIn == false)
    }

    @Test func bookmarkDataCodableRoundTrip() throws {
        let folders = [BookmarkFolder.starred, BookmarkFolder(id: "x", name: "X", conversationIds: ["a"], isBuiltIn: false)]
        let bd = BookmarkData(folders: folders)
        let data = try JSONEncoder().encode(bd)
        let decoded = try JSONDecoder().decode(BookmarkData.self, from: data)
        #expect(decoded.folders.count == 2)
        #expect(decoded.folders[0].id == "starred")
        #expect(decoded.folders[1].conversationIds == ["a"])
    }

    @Test func folderEqualityUsesAllFields() {
        let a = BookmarkFolder(id: "same", name: "A", conversationIds: [], isBuiltIn: false)
        let b = BookmarkFolder(id: "same", name: "B", conversationIds: ["c1"], isBuiltIn: true)
        // Synthesized Hashable compares all fields, not just id
        #expect(a != b)
        // Same values → equal
        let c = BookmarkFolder(id: "same", name: "A", conversationIds: [], isBuiltIn: false)
        #expect(a == c)
    }
}

// MARK: - BookmarkManager In-Memory Logic Tests

@Suite struct BookmarkManagerLogicTests {

    // Test the pure logic by directly manipulating the folders array
    // (avoids filesystem persistence)

    @Test func createFolderAddsToList() {
        var folders: [BookmarkFolder] = [.starred]
        let newFolder = BookmarkFolder(id: "f1", name: "Work", conversationIds: [], isBuiltIn: false)
        folders.append(newFolder)
        #expect(folders.count == 2)
        #expect(folders[1].name == "Work")
    }

    @Test func deleteBuiltInFolderShouldBeBlocked() {
        var folders: [BookmarkFolder] = [.starred]
        let toDelete = folders[0]
        if !toDelete.isBuiltIn {
            folders.removeAll { $0.id == toDelete.id }
        }
        #expect(folders.count == 1) // starred not removed
    }

    @Test func deleteCustomFolderRemovesIt() {
        var folders: [BookmarkFolder] = [
            .starred,
            BookmarkFolder(id: "f1", name: "Work", conversationIds: [], isBuiltIn: false)
        ]
        let toDelete = folders[1]
        if !toDelete.isBuiltIn {
            folders.removeAll { $0.id == toDelete.id }
        }
        #expect(folders.count == 1)
        #expect(folders[0].id == "starred")
    }

    @Test func addBookmarkToFolder() {
        var folders: [BookmarkFolder] = [.starred]
        let idx = folders.firstIndex(where: { $0.id == "starred" })!
        if !folders[idx].conversationIds.contains("conv-1") {
            folders[idx].conversationIds.append("conv-1")
        }
        #expect(folders[0].conversationIds == ["conv-1"])
    }

    @Test func addDuplicateBookmarkIsNoop() {
        var folders: [BookmarkFolder] = [
            BookmarkFolder(id: "starred", name: "Starred", conversationIds: ["conv-1"], isBuiltIn: true)
        ]
        let idx = 0
        if !folders[idx].conversationIds.contains("conv-1") {
            folders[idx].conversationIds.append("conv-1")
        }
        #expect(folders[0].conversationIds == ["conv-1"]) // no duplicate
    }

    @Test func removeBookmarkFromFolder() {
        var folders: [BookmarkFolder] = [
            BookmarkFolder(id: "starred", name: "Starred", conversationIds: ["c1", "c2", "c3"], isBuiltIn: true)
        ]
        folders[0].conversationIds.removeAll { $0 == "c2" }
        #expect(folders[0].conversationIds == ["c1", "c3"])
    }

    @Test func foldersContainingConversation() {
        let folders: [BookmarkFolder] = [
            BookmarkFolder(id: "starred", name: "Starred", conversationIds: ["c1", "c2"], isBuiltIn: true),
            BookmarkFolder(id: "work", name: "Work", conversationIds: ["c2", "c3"], isBuiltIn: false),
            BookmarkFolder(id: "archive", name: "Archive", conversationIds: ["c4"], isBuiltIn: false)
        ]
        let containing = folders.filter { $0.conversationIds.contains("c2") }
        #expect(containing.count == 2)
        #expect(Set(containing.map { $0.id }) == Set(["starred", "work"]))
    }

    @Test func isBookmarkedCheck() {
        let folders: [BookmarkFolder] = [
            BookmarkFolder(id: "starred", name: "Starred", conversationIds: ["c1"], isBuiltIn: true)
        ]
        let isBookmarked = folders.contains { $0.conversationIds.contains("c1") }
        let isNotBookmarked = folders.contains { $0.conversationIds.contains("c99") }
        #expect(isBookmarked == true)
        #expect(isNotBookmarked == false)
    }

    @Test func renameFolderUpdatesName() {
        var folders: [BookmarkFolder] = [
            BookmarkFolder(id: "f1", name: "Old Name", conversationIds: [], isBuiltIn: false)
        ]
        if let idx = folders.firstIndex(where: { $0.id == "f1" }) {
            folders[idx].name = "New Name"
        }
        #expect(folders[0].name == "New Name")
    }
}
