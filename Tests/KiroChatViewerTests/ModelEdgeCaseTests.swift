import Foundation
import Testing
@testable import KiroChatViewer

// MARK: - Conversation Codable Tests

@Suite struct ConversationCodableTests {

    @Test func decodesFromMinimalJSON() throws {
        let json = """
        {"conversation_id": "abc-123", "history": []}
        """
        let conv = try JSONDecoder().decode(Conversation.self, from: json.data(using: .utf8)!)
        #expect(conv.id == "abc-123")
        #expect(conv.history.isEmpty)
        #expect(conv.title == "Untitled")
    }

    @Test func decodesWithPromptAndResponse() throws {
        let json = """
        {
          "conversation_id": "c1",
          "history": [[
            {"content": {"Prompt": {"prompt": "Hello"}}},
            {"Response": {"content": "Hi there"}}
          ]]
        }
        """
        let conv = try JSONDecoder().decode(Conversation.self, from: json.data(using: .utf8)!)
        #expect(conv.id == "c1")
        #expect(conv.history.count == 1)
        #expect(conv.title == "Hello")
    }

    @Test func decodesWithToolUseInHistory() throws {
        let json = """
        {
          "conversation_id": "c2",
          "history": [[
            {"content": {"Prompt": {"prompt": "list files"}}},
            {"ToolUse": {"content": "Let me check.", "tool_uses": [{"id": "t1", "name": "fs_read", "args": {"path": "/tmp"}}]}},
            {"content": {"ToolUseResults": {"tool_use_results": [{"tool_use_id": "t1", "status": "Success", "content": [{"Text": "file.txt"}]}]}}},
            {"Response": {"content": "Here are the files."}}
          ]]
        }
        """
        let conv = try JSONDecoder().decode(Conversation.self, from: json.data(using: .utf8)!)
        let msgs = conv.messages
        #expect(msgs.count == 3) // prompt, tool, response
        #expect(msgs[1].role == .tool)
        #expect(msgs[1].toolCalls[0].result?.content == "file.txt")
    }

    @Test func handlesEmptyHistoryArray() throws {
        let json = """
        {"conversation_id": "empty", "history": []}
        """
        let conv = try JSONDecoder().decode(Conversation.self, from: json.data(using: .utf8)!)
        #expect(conv.messages.isEmpty)
        #expect(conv.messageCount == 0)
    }

    @Test func handlesMalformedHistoryGracefully() throws {
        // history with empty inner arrays
        let json = """
        {"conversation_id": "weird", "history": [[], []]}
        """
        let conv = try JSONDecoder().decode(Conversation.self, from: json.data(using: .utf8)!)
        #expect(conv.messages.isEmpty)
    }
}

// MARK: - Multi-Turn Conversation Tests

@Suite struct MultiTurnConversationTests {

    @Test func multipleTurnsAllParsed() {
        let turn1 = makeSimpleTurn(prompt: "First question", response: "First answer")
        let turn2 = makeSimpleTurn(prompt: "Second question", response: "Second answer")
        let conv = makeConversation(history: [turn1, turn2])
        let msgs = conv.messages
        #expect(msgs.count == 4)
        #expect(msgs[0].content == "First question")
        #expect(msgs[1].content == "First answer")
        #expect(msgs[2].content == "Second question")
        #expect(msgs[3].content == "Second answer")
    }

    @Test func titleComesFromFirstPromptOnly() {
        let turn1 = makeSimpleTurn(prompt: "Short", response: "ok")
        let turn2 = makeSimpleTurn(prompt: "This is a much longer second prompt that should not be the title", response: "ok")
        let conv = makeConversation(history: [turn1, turn2])
        #expect(conv.title == "Short")
    }

    @Test func mixedToolAndSimpleTurns() {
        let simple = makeSimpleTurn(prompt: "hi", response: "hello")
        let tool = makeToolTurn(prompt: "run ls", toolName: "execute_bash", response: "done")
        let conv = makeConversation(history: [simple, tool])
        let msgs = conv.messages
        #expect(msgs.count == 5) // 2 from simple + 3 from tool
        #expect(msgs[2].role == .user)
        #expect(msgs[3].role == .tool)
        #expect(msgs[4].role == .assistant)
    }
}

// MARK: - ToolCall Tests

@Suite struct ToolCallTests {

    @Test func argsDescriptionTruncatesLongStrings() {
        let call = ToolCall(id: "t1", name: "fs_write", args: [
            "path": "/tmp/file.txt",
            "content": String(repeating: "x", count: 200)
        ])
        let desc = call.argsDescription
        // Long values should be truncated to 80 chars + "..."
        #expect(desc.contains("..."))
    }

    @Test func argsDescriptionHandlesArrays() {
        let call = ToolCall(id: "t1", name: "test", args: [
            "items": ["a", "b", "c"]
        ])
        #expect(call.argsDescription.contains("3 items"))
    }

    @Test func argsDescriptionHandlesDicts() {
        let call = ToolCall(id: "t1", name: "test", args: [
            "config": ["key1": "val1", "key2": "val2"] as [String: Any]
        ])
        #expect(call.argsDescription.contains("2 keys"))
    }

    @Test func fullArgsDescriptionShowsFullContent() {
        let longContent = String(repeating: "y", count: 200)
        let call = ToolCall(id: "t1", name: "fs_write", args: ["content": longContent])
        let full = call.fullArgsDescription
        #expect(full.contains(longContent)) // not truncated
    }
}

// MARK: - JSONValue Comprehensive Tests

@Suite struct JSONValueComprehensiveTests {

    @Test func objectRoundTrip() throws {
        let obj = JSONValue.object(["name": .string("test"), "count": .number(5)])
        let data = try JSONEncoder().encode(obj)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .object(let dict) = decoded {
            #expect(dict.count == 2)
            if case .string(let s) = dict["name"] { #expect(s == "test") }
            if case .number(let n) = dict["count"] { #expect(n == 5) }
        } else {
            Issue.record("Expected .object")
        }
    }

    @Test func arrayRoundTrip() throws {
        let arr = JSONValue.array([.string("a"), .number(1), .bool(false)])
        let data = try JSONEncoder().encode(arr)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .array(let items) = decoded {
            #expect(items.count == 3)
        } else {
            Issue.record("Expected .array")
        }
    }

    @Test func nestedObjectRoundTrip() throws {
        let nested = JSONValue.object([
            "outer": .object(["inner": .string("deep")])
        ])
        let data = try JSONEncoder().encode(nested)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .object(let d) = decoded,
           case .object(let inner) = d["outer"],
           case .string(let s) = inner["inner"] {
            #expect(s == "deep")
        } else {
            Issue.record("Expected nested object")
        }
    }

    @Test func rawValueConversions() {
        #expect(JSONValue.string("hi").rawValue as? String == "hi")
        #expect(JSONValue.number(3.14).rawValue as? Double == 3.14)
        #expect(JSONValue.bool(true).rawValue as? Bool == true)
        #expect(JSONValue.null.rawValue as? String == "")

        if let arr = JSONValue.array([.string("a")]).rawValue as? [Any] {
            #expect(arr.count == 1)
        } else {
            Issue.record("Expected array rawValue")
        }

        if let dict = JSONValue.object(["k": .string("v")]).rawValue as? [String: Any] {
            #expect(dict["k"] as? String == "v")
        } else {
            Issue.record("Expected dict rawValue")
        }
    }
}

// MARK: - Property Tests (Extended)

@Suite struct ExtendedPropertyTests {

    @Test func multiTurnMessageCountMatchesTurns() {
        #expect(property("count matches turns", iterations: 50) {
            let turnCount = Int.random(in: 1...5)
            let turns = (0..<turnCount).map { _ in
                makeSimpleTurn(prompt: randomMessageContent(), response: randomMessageContent())
            }
            let conv = makeConversation(history: turns)
            // Each simple turn has 2 wrappers (prompt + response), both counted
            return conv.messageCount == turnCount * 2
        })
    }

    @Test func toolTurnMessageCountIs3() {
        #expect(property("tool turn = 3 messages", iterations: 50) {
            let turn = makeToolTurn(
                prompt: randomMessageContent(),
                toolName: randomToolName(),
                response: randomMessageContent()
            )
            let conv = makeConversation(history: [turn])
            return conv.messageCount == 3 // prompt + toolUse + response (toolResult excluded)
        })
    }

    @Test func conversationEqualityIsById() {
        #expect(property("equality by id", iterations: 100) {
            let id = randomConversationId()
            let a = makeConversation(id: id, directory: randomDirectoryPath())
            let b = makeConversation(id: id, directory: randomDirectoryPath())
            return a == b
        })
    }

    @Test func differentIdsNeverEqual() {
        #expect(property("different ids ≠", iterations: 100) {
            let a = makeConversation(id: randomConversationId())
            let b = makeConversation(id: randomConversationId() + "-extra")
            return a != b
        })
    }
}
