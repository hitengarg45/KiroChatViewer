# KiroChatViewer v3.5.0 Release Notes

**Release Date**: 2026-03-09

## Settings Overhaul & Tool Rendering

### Settings UI
- ✅ Complete settings redesign with card-based layout, colored icon badges, tab headers
- ✅ Reusable `SettingCard` and `SettingRow` components for consistent styling
- ✅ Custom themes now inline alongside built-in themes with `+` button and right-click edit/delete
- ✅ All settings use pending state — nothing applies until "Apply" is clicked

### Appearance Settings
- ✅ Granular font sizes: separate sliders for folders, conversations, and messages
- ✅ Terminal styles: macOS Terminal, iTerm2, Warp, Hyper — each with distinct colors and preview cards
- ✅ Diff view modes: Inline vs Side-by-Side with live previews
- ✅ Tool display modes: Always Open, Collapsible (closed by default), Hidden

### Tool-Specific Rendering
- ✅ `execute_bash`: Terminal-style block with `$` prompt, working dir, themed colors
- ✅ `fs_write` (str_replace): Diff view with red/green lines, inline or side-by-side
- ✅ `fs_write` (create): File content in green-tinted block
- ✅ `fs_read`: File icon + path + mode badge
- ✅ `grep`/`WorkspaceSearch`: Search pattern in yellow with path
- ✅ `glob`: Pattern in cyan with directory
- ✅ `use_aws`: AWS CLI terminal style with service/operation/region
- ✅ `web_search`/`web_fetch`: Globe icon with query in blue card
- ✅ `code`: Code intelligence with operation + symbol + file path
- ✅ All other tools: Generic args + result fallback

### Conversation List
- ✅ Terminal icon with pin badge overlay for pinned conversations
- ✅ Blue accent bar + bold title + tinted background for pinned rows
- ✅ Hover highlight on non-selected rows
- ✅ Message count per conversation
- ✅ Folder rows with chat count and latest time

### Auto Title Generation
- ✅ Generates 3-8 word titles using kiro-cli with lightweight `kiro-fast` agent
- ✅ Sequential processing, max 10 per launch, newest first
- ✅ Model picker in settings (qwen3-coder-480b default at 0.01x credits)
- ✅ "Generate Title" option in conversation three-dot menu
- ✅ Toggle auto-generation on/off in settings
- ✅ Titles shown in both conversation list and detail view

### Other Changes
- ✅ Export button uses icon instead of text
- ✅ Toolbar items grouped to prevent overflow on narrow sidebar
- ✅ Conversation detail title uses generated/custom title
- ✅ Filtered Application Support conversations
