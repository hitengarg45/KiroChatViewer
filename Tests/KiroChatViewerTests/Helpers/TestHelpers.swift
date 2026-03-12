import Foundation
@testable import KiroChatViewer

// MARK: - Factory Functions

func makeConversation(
    id: String = "test-\(UUID().uuidString.prefix(8))",
    directory: String = "/Users/test/project",
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    history: [[MessageWrapper]] = []
) -> Conversation {
    Conversation(id: id, directory: directory, createdAt: createdAt, updatedAt: updatedAt, history: history)
}

// MARK: - MessageWrapper JSON Helpers

func decodeWrapper(from json: String) -> MessageWrapper? {
    guard let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(MessageWrapper.self, from: data)
}

private func jsonStr(_ s: String) -> String {
    // Wrap in array, serialize, then strip the brackets to get a properly escaped JSON string
    let data = try! JSONSerialization.data(withJSONObject: [s])
    let arr = String(data: data, encoding: .utf8)!
    // arr is like ["value"], strip leading [ and trailing ]
    return String(arr.dropFirst().dropLast())
}

func makePromptWrapper(_ prompt: String) -> MessageWrapper? {
    decodeWrapper(from: """
    {"content": {"Prompt": {"prompt": \(jsonStr(prompt))}}}
    """)
}

func makeResponseWrapper(_ response: String) -> MessageWrapper? {
    decodeWrapper(from: """
    {"Response": {"content": \(jsonStr(response))}}
    """)
}

func makeToolUseWrapper(
    content: String = "Thinking...",
    toolUses: [(id: String, name: String, args: [String: String])] = []
) -> MessageWrapper? {
    let tusJSON = toolUses.map { tu in
        let argsJSON = tu.args.map { "\(jsonStr($0.key)): \(jsonStr($0.value))" }.joined(separator: ", ")
        return """
        {"id": \(jsonStr(tu.id)), "name": \(jsonStr(tu.name)), "args": {\(argsJSON)}}
        """
    }.joined(separator: ", ")
    return decodeWrapper(from: """
    {"ToolUse": {"content": \(jsonStr(content)), "tool_uses": [\(tusJSON)]}}
    """)
}

func makeToolResultsWrapper(
    results: [(toolUseId: String, status: String, content: String)]
) -> MessageWrapper? {
    let rJSON = results.map { r in
        """
        {"tool_use_id": \(jsonStr(r.toolUseId)), "status": \(jsonStr(r.status)), "content": [{"Text": \(jsonStr(r.content))}]}
        """
    }.joined(separator: ", ")
    return decodeWrapper(from: """
    {"content": {"ToolUseResults": {"tool_use_results": [\(rJSON)]}}}
    """)
}

/// Builds a prompt + response turn.
func makeSimpleTurn(prompt: String, response: String) -> [MessageWrapper] {
    [makePromptWrapper(prompt), makeResponseWrapper(response)].compactMap { $0 }
}

/// Builds a turn with tool use in the middle.
func makeToolTurn(
    prompt: String,
    toolId: String = "tool-1",
    toolName: String = "execute_bash",
    toolArgs: [String: String] = ["command": "ls"],
    toolResultContent: String = "file1.txt",
    response: String
) -> [MessageWrapper] {
    [
        makePromptWrapper(prompt),
        makeToolUseWrapper(content: "Let me help.", toolUses: [(id: toolId, name: toolName, args: toolArgs)]),
        makeToolResultsWrapper(results: [(toolUseId: toolId, status: "Success", content: toolResultContent)]),
        makeResponseWrapper(response)
    ].compactMap { $0 }
}
