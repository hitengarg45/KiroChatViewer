import Foundation
@testable import KiroChatViewer

// MARK: - Lightweight Property Test Helper

/// Runs `body` with `iterations` random seeds. Fails with the first failing input description.
func property(_ name: String, iterations: Int = 100, _ body: () -> Bool) -> Bool {
    for _ in 0..<iterations {
        guard body() else { return false }
    }
    return true
}

// MARK: - Random Generators

func randomConversationId() -> String {
    let prefixes = ["conv", "chat", "session", "test"]
    return "\(prefixes.randomElement()!)-\(UInt32.random(in: 1000...99999))"
}

func randomDirectoryPath() -> String {
    let paths = [
        "/Users/dev/projects/my-app",
        "/Users/test/workspace/service",
        "/home/user/code/frontend",
        "/tmp/test/cli-tool"
    ]
    return paths.randomElement()!
}

func randomMessageContent() -> String {
    let phrases = [
        "Hello, how can I help?",
        "Please fix the bug in main.swift",
        "Here is the updated code.",
        "Can you explain this error?",
        "The build succeeded.",
        "What does this function do?"
    ]
    return phrases.randomElement()!
}

func randomToolName() -> String {
    let names = ["execute_bash", "fs_write", "fs_read", "grep", "glob", "web_search", "code"]
    return names.randomElement()!
}

func randomDate() -> Date {
    Date(timeIntervalSinceNow: -TimeInterval.random(in: 0...(365 * 24 * 3600)))
}

func randomSimpleConversation() -> Conversation {
    makeConversation(
        id: randomConversationId(),
        directory: randomDirectoryPath(),
        createdAt: randomDate(),
        updatedAt: randomDate(),
        history: [makeSimpleTurn(prompt: randomMessageContent(), response: randomMessageContent())]
    )
}

func randomEmptyConversation() -> Conversation {
    let d = randomDate()
    return makeConversation(
        id: randomConversationId(),
        directory: randomDirectoryPath(),
        createdAt: d,
        updatedAt: d,
        history: []
    )
}

func randomString(length: Int) -> String {
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
    return String((0..<length).map { _ in chars.randomElement()! })
}
