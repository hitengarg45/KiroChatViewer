# ACP Implementation Plan v2 — Based on Official Documentation

## Sources
- Official Kiro ACP docs: https://kiro.dev/docs/cli/acp/
- ACP Spec: https://agentclientprotocol.com/protocol/prompt-turn

## Confirmed Correct Message Formats

### 1. Initialize
```json
{
  "jsonrpc": "2.0",
  "id": 0,
  "method": "initialize",
  "params": {
    "protocolVersion": 1,
    "clientCapabilities": {
      "fs": { "readTextFile": true, "writeTextFile": true },
      "terminal": true
    },
    "clientInfo": { "name": "KiroChatViewer", "version": "3.5.0" }
  }
}
```
**Note**: `protocolVersion` is integer `1`, not string `"1"` or `"2025-01-01"`.

### 2. Session New
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "session/new",
  "params": {
    "cwd": "/home/user/my-project",
    "mcpServers": []
  }
}
```
Response includes `sessionId`.

### 3. Session Prompt
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "session/prompt",
  "params": {
    "sessionId": "sess_abc123def456",
    "prompt": [
      { "type": "text", "text": "your question here" }
    ]
  }
}
```
**CRITICAL**: The field is `prompt` (array of content blocks), NOT `content`.
Each block has `type` and `text`.

### 4. Session Updates (Notifications from Agent)
All use `session/update` method with `sessionUpdate` field (NOT `kind`):

**Agent message chunk:**
```json
{
  "method": "session/update",
  "params": {
    "sessionId": "...",
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "content": { "type": "text", "text": "streaming text..." }
    }
  }
}
```

**Tool call:**
```json
{
  "update": {
    "sessionUpdate": "tool_call",
    "toolCallId": "call_001",
    "title": "Analyzing code",
    "kind": "other",
    "status": "pending"
  }
}
```

**Tool call update:**
```json
{
  "update": {
    "sessionUpdate": "tool_call_update",
    "toolCallId": "call_001",
    "status": "completed",
    "content": [...]
  }
}
```

**Turn end (as response to session/prompt, NOT notification):**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": { "stopReason": "end_turn" }
}
```

### 5. Cancel
```json
{
  "jsonrpc": "2.0",
  "method": "session/cancel",
  "params": { "sessionId": "..." }
}
```
This is a notification (no `id`).

## What Was Wrong in Our Previous Implementation

1. **`protocolVersion`**: We used `"1"` (string) — should be `1` (integer)
2. **Prompt field**: We used `content: [{type, text}]` — should be `prompt: [{type, text}]`
3. **Session update kind**: We checked for `kind: "AgentMessageChunk"` — should check `sessionUpdate: "agent_message_chunk"` (snake_case)
4. **Turn end**: We expected a notification — it's actually the **response** to the `session/prompt` request (same `id`), with `result: {stopReason: "end_turn"}`
5. **Timing**: We sent session/new before initialize response arrived — should wait for init response first
6. **Prompt sent too early**: MCP servers take ~10s to load. The prompt was likely queued but the agent wasn't ready. Need to wait for session to be fully ready.

## Correct Flow

```
Client                              Agent (kiro-cli acp)
  |                                    |
  |--- initialize (id:0) ------------>|
  |<-- result: agentInfo, caps --------|
  |                                    |
  |--- session/new (id:1) ----------->|
  |<-- notifications: _kiro.dev/* -----|  (MCP servers loading, ~10s)
  |<-- result: sessionId -------------|
  |<-- notifications: _kiro.dev/* -----|  (more MCP servers)
  |                                    |
  |  (wait for notifications to stop)  |
  |                                    |
  |--- session/prompt (id:2) -------->|
  |<-- notification: agent_message_chunk (streaming)
  |<-- notification: agent_message_chunk (streaming)
  |<-- notification: tool_call --------|
  |<-- notification: tool_call_update -|
  |<-- notification: agent_message_chunk (more streaming)
  |<-- result (id:2): stopReason ------|  (turn complete)
```

## Implementation Steps

### Step 1: Fix ACPClient.swift
- Fix `protocolVersion` to integer `1`
- Fix prompt to use `prompt` field not `content`
- Wait for initialize response before sending session/new
- Wait for session/new response before allowing prompts
- Handle `sessionUpdate` field (snake_case) for notifications
- Handle turn end as response to prompt request (check `result.stopReason`)
- Read stderr for parse errors (critical for debugging)

### Step 2: Fix LiveChatView.swift
- Show proper connecting states
- Disable send until session is ready
- Handle streaming chunks correctly

### Step 3: Test
- Use `KIRO_LOG_LEVEL=debug` for verbose logging
- Check `$TMPDIR/kiro-log/kiro-chat.log` for agent-side logs
- Check our app logs via Console.app

## Session Storage
Sessions saved at: `~/.kiro/sessions/cli/`
- `<session-id>.json` — metadata
- `<session-id>.jsonl` — event log

## Logging
Agent logs: `$TMPDIR/kiro-log/kiro-chat.log`
Enable debug: `KIRO_LOG_LEVEL=debug kiro-cli acp`
