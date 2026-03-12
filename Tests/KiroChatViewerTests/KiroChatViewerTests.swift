import Foundation
import Testing
@testable import KiroChatViewer

// MARK: - Conversation Tests

@Suite struct ConversationTests {

    @Test func emptyHistoryProducesUntitledTitle() {
        let conv = makeConversation(history: [])
        #expect(conv.title == "Untitled")
        #expect(conv.messageCount == 0)
        #expect(conv.messages.isEmpty)
    }

    @Test func titleExtractedFromFirstPrompt() {
        let turn = makeSimpleTurn(prompt: "Fix the login bug", response: "Sure, let me look.")
        let conv = makeConversation(history: [turn])
        #expect(conv.title == "Fix the login bug")
    }

    @Test func titleTruncatedAt60Characters() {
        let longPrompt = String(repeating: "a", count: 120)
        let turn = makeSimpleTurn(prompt: longPrompt, response: "ok")
        let conv = makeConversation(history: [turn])
        #expect(conv.title.count == 60)
    }

    @Test func messageCountExcludesToolResults() {
        let turn = makeToolTurn(
            prompt: "list files",
            toolResultContent: "file1.txt\nfile2.txt",
            response: "Here are the files."
        )
        let conv = makeConversation(history: [turn])
        // prompt + toolUse + response = 3 (toolResult excluded)
        #expect(conv.messageCount == 3)
    }

    @Test func messagesParseAllRoles() {
        let turn = makeToolTurn(prompt: "run ls", response: "Done.")
        let conv = makeConversation(history: [turn])
        let msgs = conv.messages
        #expect(msgs.count == 3)
        #expect(msgs[0].role == .user)
        #expect(msgs[1].role == .tool)
        #expect(msgs[2].role == .assistant)
    }

    @Test func toolResultsAttachedToCorrectCalls() {
        let turn = makeToolTurn(
            prompt: "check",
            toolId: "t-42",
            toolName: "grep",
            toolResultContent: "match found",
            response: "Found it."
        )
        let conv = makeConversation(history: [turn])
        let toolMsg = conv.messages.first { $0.role == .tool }!
        #expect(toolMsg.toolCalls.count == 1)
        #expect(toolMsg.toolCalls[0].id == "t-42")
        #expect(toolMsg.toolCalls[0].name == "grep")
        #expect(toolMsg.toolCalls[0].result?.content == "match found")
        #expect(toolMsg.toolCalls[0].result?.status == "Success")
    }

    @Test func equalityBasedOnId() {
        let a = makeConversation(id: "same-id", history: [])
        let b = makeConversation(id: "same-id", history: [makeSimpleTurn(prompt: "hi", response: "hey")])
        #expect(a == b)
    }

    @Test func differentIdsNotEqual() {
        let a = makeConversation(id: "id-1", history: [])
        let b = makeConversation(id: "id-2", history: [])
        #expect(a != b)
    }
}

// MARK: - MessageWrapper Tests

@Suite struct MessageWrapperTests {

    @Test func promptWrapperDecodes() {
        let w = makePromptWrapper("hello world")
        #expect(w != nil)
        #expect(w?.prompt == "hello world")
        #expect(w?.responseText == nil)
        #expect(w?.toolUse == nil)
    }

    @Test func responseWrapperDecodes() {
        let w = makeResponseWrapper("here is the answer")
        #expect(w != nil)
        #expect(w?.responseText == "here is the answer")
        #expect(w?.prompt == nil)
    }

    @Test func toolUseWrapperDecodes() {
        let w = makeToolUseWrapper(
            content: "Let me check.",
            toolUses: [(id: "t1", name: "fs_read", args: ["path": "/tmp"])]
        )
        #expect(w != nil)
        #expect(w?.toolUse?.toolCalls.count == 1)
        #expect(w?.toolUse?.toolCalls[0].name == "fs_read")
        #expect(w?.toolUse?.content == "Let me check.")
    }

    @Test func toolResultsWrapperDecodes() {
        let w = makeToolResultsWrapper(results: [
            (toolUseId: "t1", status: "Success", content: "output")
        ])
        #expect(w != nil)
        #expect(w?.toolUseResults?.count == 1)
        #expect(w?.toolUseResults?[0].toolUseId == "t1")
        #expect(w?.toolUseResults?[0].content == "output")
    }
}

// MARK: - JSONValue Tests

@Suite struct JSONValueTests {

    @Test func roundTripsString() throws {
        let original = JSONValue.string("hello")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .string(let s) = decoded {
            #expect(s == "hello")
        } else {
            Issue.record("Expected .string")
        }
    }

    @Test func roundTripsNumber() throws {
        let original = JSONValue.number(42.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .number(let n) = decoded {
            #expect(n == 42.5)
        } else {
            Issue.record("Expected .number")
        }
    }

    @Test func roundTripsBool() throws {
        let original = JSONValue.bool(true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .bool(let b) = decoded {
            #expect(b == true)
        } else {
            Issue.record("Expected .bool")
        }
    }

    @Test func nullRawValueIsEmptyString() {
        let val = JSONValue.null
        #expect(val.rawValue as? String == "")
    }
}

// MARK: - Property-Based Tests

@Suite struct PropertyTests {

    @Test func titleNeverExceeds60Chars() {
        #expect(property("title ≤ 60", iterations: 100) {
            randomSimpleConversation().title.count <= 60
        })
    }

    @Test func emptyHistoryAlwaysUntitled() {
        #expect(property("empty → Untitled", iterations: 100) {
            let c = randomEmptyConversation()
            return c.title == "Untitled" && c.messageCount == 0
        })
    }

    @Test func messageCountNeverNegative() {
        #expect(property("count ≥ 0", iterations: 100) {
            randomSimpleConversation().messageCount >= 0
        })
    }

    @Test func conversationIdPreserved() {
        #expect(property("id preserved", iterations: 100) {
            let id = randomConversationId()
            let dir = randomDirectoryPath()
            let conv = makeConversation(id: id, directory: dir)
            return conv.id == id && conv.directory == dir
        })
    }

    @Test func longPromptTitleAlwaysTruncated() {
        #expect(property("long prompt truncated", iterations: 50) {
            let len = Int.random(in: 61...300)
            let prompt = randomString(length: len)
            let turn = makeSimpleTurn(prompt: prompt, response: "ok")
            let conv = makeConversation(history: [turn])
            return conv.title.count <= 60
        })
    }
}
