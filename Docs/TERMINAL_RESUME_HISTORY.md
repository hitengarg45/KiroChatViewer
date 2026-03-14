# Terminal Resume: Implementation History

## Current Approach (v3.7+ — Embedded Terminal)

Uses SwiftTerm's `LocalProcessTerminalView` embedded directly in the detail view.

**Flow:**
1. User clicks "Continue in Terminal" on a conversation
2. `TerminalSessionManager` creates a `LocalProcessTerminalView`, spawns a shell, sends the resume command
3. The command chain:
   ```bash
   cd '<directory>' && sqlite3 '<db-path>' "UPDATE conversations_v2 SET updated_at = (now + 30) * 1000 WHERE conversation_id = '<id>'" && exec kiro-cli chat --resume
   ```
4. The `sqlite3` update sets `updated_at` to 30 seconds in the future, ensuring `--resume` picks the correct conversation even if another session updates concurrently
5. `exec` replaces the shell process with kiro-cli for a clean process tree

**Session Management:**
- `TerminalSessionManager` (singleton) keeps terminal sessions alive across conversation switches
- Sessions stored in `terminalViews: [String: LocalProcessTerminalView]` dictionary
- Switching conversations hides/shows the terminal — doesn't destroy it
- Minimize button collapses to header-only (session still running)
- Close button sends `SIGHUP` to shell process and removes from dictionary
- Deleting a conversation also closes its terminal session
- `deinit` calls `closeAll()` to kill all processes on app quit
- Settings Apply button calls `applyTheme()` to update colors on all active terminals

**Race Condition Mitigation:**
- `updated_at` set to now + 30 seconds — gives a 30-second window where the target conversation is guaranteed to be the "newest"
- The `&&` chain ensures `sqlite3` update and `--resume` execute atomically in the same shell
- Risk: another kiro-cli instance updating the same directory within the 30-second window could still cause a race (extremely unlikely in practice)

**Files:**
- `TerminalSessionManager.swift` — session lifecycle, process cleanup, theme updates
- `EmbeddedTerminalView.swift` — SwiftTerm NSViewRepresentable wrapper
- `ConversationDetailView.swift` — terminal panel UI (resize, minimize, close)

---

## Previous Approach (v1.0–v3.6 — External Terminal.app)

Used AppleScript to open macOS Terminal.app with a self-deleting temp script.

**Flow:**
1. Create `/tmp/kiro_resume_<8chars>.sh`:
   ```bash
   #!/bin/bash
   sqlite3 '<db-path>' "UPDATE conversations_v2 SET updated_at = ... WHERE conversation_id = '<id>'"
   cd '<directory>'
   rm -f '/tmp/kiro_resume_<8chars>.sh'
   exec kiro-cli chat --resume
   ```
2. `chmod +x` the script
3. AppleScript opens Terminal.app and runs the script:
   ```applescript
   tell application "Terminal"
       activate
       do script "'/tmp/kiro_resume_<8chars>.sh'"
   end tell
   ```

**Why a temp script?**
- AppleScript's `do script` takes a single string
- Multiple sequential commands needed (update DB → cd → exec kiro-cli)
- Script bundles them atomically
- `exec` replaces shell process with kiro-cli (clean process tree)
- `rm -f` self-deletes to avoid temp file accumulation

**Why replaced?**
- Required switching to a separate app (Terminal.app)
- User lost context of the conversation they were viewing
- No integration with the app's theme or layout

---

## Key Detail: Why `updated_at` Update is Required

`kiro-cli chat --resume` resumes the most recently updated conversation in the current directory. Without updating `updated_at`, it would resume whichever conversation was last active — not necessarily the one the user clicked on.

The `sqlite3` command sets `updated_at` to the current timestamp (milliseconds since epoch), making the selected conversation the "most recent" one.

---

## "View in Terminal" (Sidebar Menu — Still Uses Terminal.app)

The three-dot menu on conversation rows has "View in Terminal" which opens Terminal.app with `--resume-picker`. This is a different feature — it shows a picker of all sessions in that directory. This still uses the AppleScript approach since it's a directory-level action, not a specific conversation resume.

---

## Alternative Approach: Expect-Based Picker Automation (Not Yet Implemented)

Eliminates the race condition entirely by using `--resume-picker` instead of `--resume`.

**How it works:**
1. Sort conversations for the directory by `updatedAt` (newest first) — same order the picker displays
2. Find the target conversation's index in that sorted list
3. Generate an `expect` script (or send keystrokes directly to PTY) that:
   - Runs `kiro-cli chat --resume-picker`
   - Waits for the picker prompt to appear
   - Sends N down-arrow keystrokes (`\033[B`) to navigate to the correct entry
   - Sends Enter (`\r`) to select it
4. No database modification needed — no race condition possible

**Example for target at index 2:**
```expect
spawn kiro-cli chat --resume-picker
expect "Select a chat session"
expect "❯"
sleep 0.1
send "\033[B"    # down arrow to position 1
sleep 0.1
send "\033[B"    # down arrow to position 2
sleep 0.1
send "\r"        # enter to select
interact
```

**For embedded terminal (SwiftTerm):**
```swift
tv.send(txt: "kiro-cli chat --resume-picker\n")
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    for _ in 0..<targetIndex {
        tv.send(txt: "\u{1b}[B")  // down arrow
    }
    tv.send(txt: "\r")  // enter
}
```

**Pros:** No race condition, uses official picker mechanism
**Cons:** Fragile timing (depends on picker render speed), breaks if picker format changes
**Dependency:** `expect` (pre-installed on macOS at `/usr/bin/expect`)

**Status:** Documented for future implementation. Current approach uses `updated_at + 30 seconds` to minimize race window.

---

## How IDEs Implement Embedded Terminals

All major IDEs use the same fundamental architecture: PTY + VT100 Parser + Rendering Layer.

### Architecture Pattern

```
User's Shell (zsh/bash)
        ↕ (stdin/stdout via PTY)
VT100 Parser (parses ANSI escape codes)
        ↕ (styled text, cursor position, colors)
Rendering Layer (draws to screen)
        ↕
IDE Panel (bottom panel, resizable, tabbed)
```

### IDE Implementations

| IDE | PTY Layer | VT100 Parser | Renderer | Language |
|---|---|---|---|---|
| VS Code | `node-pty` (Node.js → native `forkpty`) | `xterm.js` | Canvas/DOM in Electron | TypeScript |
| IntelliJ | JNA → native `openpty` | `JediTerm` (custom) | Swing/AWT | Java |
| Xcode | Private framework | Private | AppKit | Objective-C |
| **KiroChatViewer** | SwiftTerm `LocalProcess` → `forkpty` | SwiftTerm `Terminal` | SwiftTerm AppKit `NSView` | Swift |

### Our Implementation

SwiftTerm bundles all three layers into `LocalProcessTerminalView`:
- PTY creation via `forkpty`
- VT100/Xterm escape code parsing
- AppKit `NSView` rendering with CoreText

We wrap it in `NSViewRepresentable` for SwiftUI integration.

### Key Differences from Full IDE Terminals

| Feature | VS Code / IntelliJ | KiroChatViewer |
|---|---|---|
| Multiple tabs | ✅ | ❌ (one per conversation) |
| Split terminals | ✅ | ❌ |
| Shell selection | ✅ (configurable) | Uses system default |
| Profile/theme | ✅ (custom colors, fonts) | Uses SwiftTerm defaults |
| Drag to detach | ✅ | ❌ |

These are potential future enhancements if needed.
