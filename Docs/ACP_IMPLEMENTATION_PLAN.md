# ACP Live Chat Implementation Plan

## Overview
Implement a full live chat interface in KiroChatViewer using the Agent Client Protocol (ACP) to communicate with kiro-cli as a subprocess.

## ACP Protocol Summary

### What is ACP?
- JSON-RPC 2.0 protocol over stdin/stdout
- Spawn `kiro-cli acp` as subprocess, communicate via JSON messages
- Spec: https://agentclientprotocol.com
- Version: `2025-01-01`

### Confirmed Working Flow
```
1. Client → Agent: initialize (handshake, capabilities)
2. Client → Agent: session/new (create session with cwd, agent, model, mcpServers)
3. Client → Agent: session/prompt (send user message with sessionId)
4. Agent → Client: session/update notifications (streaming chunks, tool calls, turn end)
5. Client → Agent: session/cancel (interrupt if needed)
```

### Key Message Formats

**Initialize:**
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{
  "clientInfo":{"name":"KiroChatViewer","version":"3.5.0"},
  "protocolVersion":"2025-01-01",
  "capabilities":{}
}}
```
Response includes: `agentInfo`, `agentCapabilities` (loadSession, image support, etc.)

**Session New:**
```json
{"jsonrpc":"2.0","id":2,"method":"session/new","params":{
  "cwd":"/Users/ghiten",
  "agent":"kiro-fast",
  "model":"qwen3-coder-480b",
  "mcpServers":[]
}}
```
Response includes: `sessionId`, `modes`, `tools[]`, `mcpServers[]`, `commands[]`, `prompts[]`

**Session Prompt:**
```json
{"jsonrpc":"2.0","id":3,"method":"session/prompt","params":{
  "sessionId":"<uuid>",
  "content":[{"type":"text","text":"user message"}]
}}
```

**Session Update Notifications (streaming):**
- `AgentMessageChunk` — `{kind: "AgentMessageChunk", content: {text: "..."}}`
- `ToolCall` — `{kind: "ToolCall", name: "...", status: "running|completed"}`
- `ToolCallUpdate` — progress updates for running tools
- `TurnEnd` — signals agent finished responding

**Tool Approval (Client method):**
- `session/request_permission` — agent asks client to approve a tool call
- Client responds with allow/deny

**Other Methods:**
- `session/load` — resume existing session
- `session/cancel` — cancel current operation
- `session/set_model` — change model mid-conversation
- `session/set_mode` — switch agent mid-conversation

### Kiro Extensions (prefixed with `_kiro.dev/`)
- `_kiro.dev/commands/execute` — execute slash commands
- `_kiro.dev/commands/available` — lists available commands after session creation
- `_kiro.dev/mcp/server_initialized` — MCP server ready notification
- `_kiro.dev/compaction/status` — context compaction progress

### Available Slash Commands (from session/new response)
- `/agent` — select/list agents
- `/model` — select/list models
- `/tools` — show available tools
- `/mcp` — show MCP servers
- `/context` — show token usage
- `/clear` — clear history
- `/compact` — compact history
- `/plan` — switch to planner agent
- `/usage` — billing info

## Implementation Architecture

### New Files
```
Sources/KiroChatViewer/
├── ACPClient.swift          — ACP subprocess manager, JSON-RPC messaging
├── ACPModels.swift          — ACP message types (Codable structs)
├── LiveChatView.swift       — Live chat UI (message input, streaming display)
├── LiveChatViewModel.swift  — State management for live chat
├── ToolApprovalView.swift   — Native tool approval dialog
```

### ACPClient.swift
- Manages `kiro-cli acp` Process lifecycle
- Sends JSON-RPC requests via stdin
- Reads JSON-RPC responses/notifications from stdout (line-by-line)
- Async/await based with Combine publishers for streaming
- Auto-reconnect on process crash
- Key methods:
  - `connect()` → spawn process, initialize
  - `newSession(cwd:agent:model:)` → create session
  - `prompt(text:)` → send message, return AsyncStream of updates
  - `cancel()` → cancel current operation
  - `setModel(_:)` / `setAgent(_:)` → mid-conversation changes
  - `disconnect()` → terminate process

### ACPModels.swift
- `ACPRequest` — generic JSON-RPC request
- `ACPResponse` — generic JSON-RPC response
- `ACPNotification` — session/update notifications
- `SessionNewResult` — sessionId, modes, tools, commands
- `SessionUpdate` — AgentMessageChunk, ToolCall, TurnEnd
- `ToolPermissionRequest` — tool name, args, for approval dialog

### LiveChatView.swift
- Text input field at bottom (like iMessage/Slack)
- Streaming message display (reuse existing MessageView/MarkdownUI)
- Model/Agent selector in toolbar
- Working directory indicator
- Stop generation button (calls session/cancel)
- Tool approval inline cards

### LiveChatViewModel.swift
- `@Published messages: [LiveMessage]`
- `@Published isStreaming: Bool`
- `@Published currentModel: String`
- `@Published currentAgent: String`
- `@Published availableTools: [Tool]`
- `@Published pendingApproval: ToolPermissionRequest?`
- Manages ACPClient lifecycle
- Accumulates streaming chunks into messages

### Integration with Existing App
- New "Live Chat" tab/button in sidebar (alongside conversation list)
- Or: "New Chat" button starts a live ACP session instead of opening Terminal
- Existing conversation viewer stays for browsing history
- Live chat sessions auto-save to SQLite (kiro-cli handles this)

## Implementation Phases

### Phase 1: Basic Chat (MVP)
1. ACPClient with initialize + session/new + session/prompt
2. Read streaming AgentMessageChunk, accumulate into message
3. Simple text input + send button
4. Display streamed response with markdown rendering
5. Model selector (from session/new response)
6. Working directory picker

### Phase 2: Tool Calls & Approval
1. Handle ToolCall notifications — show tool cards
2. Implement session/request_permission — native approval dialog
3. Show tool results inline
4. Handle ToolCallUpdate for progress

### Phase 3: Session Management
1. session/load — resume existing conversations
2. session/cancel — stop button
3. session/set_model / session/set_mode — mid-conversation switching
4. Agent selector

### Phase 4: Advanced
1. Slash command support (_kiro.dev/commands/execute)
2. MCP server status display
3. Context/token usage display
4. File system operations (fs/read_text_file, fs/write_text_file)
5. Terminal integration (terminal/create, terminal/output)

## Key Technical Challenges

### 1. Non-blocking stdout reading
- Process.standardOutput pipe needs async line reading
- Use DispatchIO or FileHandle.readabilityHandler
- Each line is one JSON-RPC message

### 2. Streaming UI updates
- AgentMessageChunk arrives word-by-word
- Need to accumulate into a single message and re-render markdown
- Debounce markdown rendering (every 100ms) to avoid jank

### 3. Process lifecycle
- kiro-cli acp may crash or hang
- Need timeout handling, auto-restart
- Clean shutdown on app quit

### 4. Tool approval UX
- session/request_permission is a JSON-RPC method (expects response)
- Must respond with allow/deny before agent continues
- Show native dialog with tool name, args, allow/deny buttons

## kiro-cli Path
- Primary: `~/.toolbox/bin/kiro-cli`
- Fallbacks: `/opt/homebrew/bin/kiro-cli`, `/usr/local/bin/kiro-cli`

## Testing Notes
- Initialize works: returns agentInfo, capabilities
- session/new works with: `{cwd, agent, model, mcpServers:[]}`
- session/prompt needs: `{sessionId, content:[{type:"text", text:"..."}]}`
- Streaming confirmed: AgentMessageChunk + TurnEnd pattern
- kiro-fast agent (no MCP) is fastest for testing (~13s vs ~40s)
