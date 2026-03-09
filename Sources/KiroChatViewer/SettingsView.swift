import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case about = "About"
    case appearance = "Appearance"
    case conversations = "Conversations"
    case backup = "Backup"
    case database = "Database"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .about: return "info.circle"
        case .appearance: return "paintbrush"
        case .conversations: return "bubble.left.and.bubble.right"
        case .backup: return "externaldrive"
        case .database: return "cylinder"
        }
    }
    var color: Color {
        switch self {
        case .about: return .blue
        case .appearance: return .purple
        case .conversations: return .green
        case .backup: return .orange
        case .database: return .red
        }
    }
}

// MARK: - Settings Shell

struct SettingsView: View {
    @StateObject private var theme = ThemeManager.shared
    @State private var selectedTab: SettingsTab = .about
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                Text("Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                ForEach(SettingsTab.allCases) { tab in
                    Button { selectedTab = tab } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(selectedTab == tab ? .white : tab.color)
                                .frame(width: 26, height: 26)
                                .background(selectedTab == tab ? tab.color : tab.color.opacity(0.12))
                                .cornerRadius(6)
                            Text(tab.rawValue)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
                Spacer()
            }
            .frame(width: 200)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Detail
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Tab header
                    HStack(spacing: 10) {
                        Image(systemName: selectedTab.icon)
                            .font(.title3)
                            .foregroundStyle(selectedTab.color)
                        Text(selectedTab.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    switch selectedTab {
                    case .about: AboutSettings()
                    case .appearance: AppearanceSettings()
                    case .conversations: ConversationSettings()
                    case .backup: BackupSettings()
                    case .database: DatabaseSettings()
                    }
                }
                .frame(maxWidth: 460, alignment: .leading)
                .padding(.trailing, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(width: 680, height: 480)
        .preferredColorScheme(theme.colorScheme)
    }
}

// MARK: - Setting Card

struct SettingCard<Content: View>: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = .blue
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .padding(.horizontal, 24)
    }
}

// MARK: - Setting Row

struct SettingRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: Trailing
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(iconColor)
                .cornerRadius(5)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body)
                if let subtitle = subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - About

struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 24) {
            // App icon + info
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                
                VStack(spacing: 4) {
                    Text("KiroChatViewer")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Version 3.5.0")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .cornerRadius(4)
                }
                
                Text("A native macOS app to view, search, and manage your Kiro CLI chat conversations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            
            SettingCard(title: "INFO", icon: "person.fill", iconColor: .blue) {
                VStack(spacing: 10) {
                    HStack {
                        Text("Developer").foregroundStyle(.secondary)
                        Spacer()
                        Text("Hiten Garg").fontWeight(.medium)
                    }
                    Divider()
                    HStack {
                        Text("Platform").foregroundStyle(.secondary)
                        Spacer()
                        Text("macOS 13+").fontWeight(.medium)
                    }
                    Divider()
                    HStack {
                        Text("Built with").foregroundStyle(.secondary)
                        Spacer()
                        Text("Swift + SwiftUI").fontWeight(.medium)
                    }
                    Divider()
                    HStack {
                        Text("Source").foregroundStyle(.secondary)
                        Spacer()
                        Link("GitHub ↗", destination: URL(string: "https://github.com/hitengarg45/KiroChatViewer")!)
                            .fontWeight(.medium)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Appearance

struct AppearanceSettings: View {
    @StateObject private var theme = ThemeManager.shared
    @State private var showNewTheme = false
    @State private var editingTheme: AppTheme?
    @State private var showResetConfirm = false
    @State private var pendingMode: ThemeMode = .system
    @State private var pendingCustomThemeId: String = ""
    @State private var pendingFontSize: Double = 14
    @State private var pendingLineSpacing: Double = 4
    @State private var pendingFontFamily: String = "System"
    @State private var pendingFolderFontSize: Double = 14
    @State private var pendingConvFontSize: Double = 13
    @State private var pendingMsgFontSize: Double = 14
    @State private var pendingToolMode: String = "open"
    @State private var pendingTerminalStyle: String = "dark"
    @State private var pendingDiffStyle: String = "inline"
    @State private var hasChanges = false
    
    private func loadCurrent() {
        pendingMode = theme.mode
        pendingCustomThemeId = theme.activeCustomThemeId
        pendingFontSize = theme.fontSize
        pendingLineSpacing = theme.lineSpacing
        pendingFontFamily = theme.fontFamily
        pendingFolderFontSize = theme.folderFontSize
        pendingConvFontSize = theme.conversationFontSize
        pendingMsgFontSize = theme.messageFontSize
        pendingToolMode = theme.toolDisplayMode
        pendingTerminalStyle = theme.terminalStyle
        pendingDiffStyle = theme.diffStyle
        hasChanges = false
    }
    private func checkChanges() {
        hasChanges = pendingMode != theme.mode || pendingCustomThemeId != theme.activeCustomThemeId ||
            pendingFontSize != theme.fontSize ||
            pendingLineSpacing != theme.lineSpacing || pendingFontFamily != theme.fontFamily ||
            pendingFolderFontSize != theme.folderFontSize || pendingConvFontSize != theme.conversationFontSize ||
            pendingMsgFontSize != theme.messageFontSize || pendingToolMode != theme.toolDisplayMode ||
            pendingTerminalStyle != theme.terminalStyle || pendingDiffStyle != theme.diffStyle
    }
    private func apply() {
        theme.mode = pendingMode; theme.activeCustomThemeId = pendingCustomThemeId
        theme.fontSize = pendingFontSize
        theme.lineSpacing = pendingLineSpacing; theme.fontFamily = pendingFontFamily
        theme.folderFontSize = pendingFolderFontSize; theme.conversationFontSize = pendingConvFontSize
        theme.messageFontSize = pendingMsgFontSize; theme.toolDisplayMode = pendingToolMode
        theme.terminalStyle = pendingTerminalStyle; theme.diffStyle = pendingDiffStyle
        hasChanges = false
    }
    private var previewTheme: AppTheme {
        if !pendingCustomThemeId.isEmpty,
           let custom = theme.customThemes.first(where: { $0.id == pendingCustomThemeId }) {
            return custom
        }
        switch pendingMode {
        case .system: return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        case .light: return .light; case .dark: return .dark; case .kiro: return .kiro
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            SettingCard(title: "THEME", icon: "circle.lefthalf.filled", iconColor: .purple) {
                // Built-in themes row
                HStack(spacing: 10) {
                    ForEach(ThemeMode.allCases) { mode in
                        ThemeModeCard(mode: mode, isSelected: pendingMode == mode && pendingCustomThemeId.isEmpty) {
                            pendingMode = mode
                            pendingCustomThemeId = ""
                            checkChanges()
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // Custom themes row (if any)
                if !theme.customThemes.isEmpty || true {
                    HStack(spacing: 10) {
                        ForEach(theme.customThemes) { custom in
                            VStack(spacing: 2) {
                                Button {
                                    pendingCustomThemeId = custom.id
                                    checkChanges()
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: custom.iconName ?? "paintpalette")
                                            .font(.title3).frame(height: 24)
                                        Text(custom.name).font(.caption).lineLimit(1)
                                    }
                                    .frame(width: 70, height: 60)
                                    .background(pendingCustomThemeId == custom.id ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(pendingCustomThemeId == custom.id ? Color.accentColor : Color.clear, lineWidth: 2))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                HStack(spacing: 6) {
                                    Button { editingTheme = custom } label: {
                                        Image(systemName: "pencil").font(.system(size: 9))
                                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                                    Button { theme.deleteCustomTheme(custom) } label: {
                                        Image(systemName: "trash").font(.system(size: 9))
                                    }.buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
                                }
                            }
                        }
                        
                        Button { showNewTheme = true } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus").font(.title3).frame(height: 24)
                                Text("New").font(.caption)
                            }
                            .frame(width: 70, height: 60)
                            .background(Color.secondary.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4])))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
                
                ThemePreview(theme: previewTheme)
                    .padding(.top, 4)
            }
            
            SettingCard(title: "TYPOGRAPHY", icon: "textformat.size", iconColor: .indigo) {
                VStack(spacing: 10) {
                    HStack {
                        Text("Font").frame(width: 80, alignment: .leading)
                        Picker("", selection: $pendingFontFamily) {
                            ForEach(ThemeManager.availableFonts, id: \.self) { name in
                                Text(name).font(name == "System" ? .system(size: 13) : .custom(name, size: 13)).tag(name)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: pendingFontFamily) { _ in checkChanges() }
                    }
                    HStack {
                        Text("Spacing").frame(width: 80, alignment: .leading)
                        Slider(value: $pendingLineSpacing, in: 0...12, step: 1)
                            .onChange(of: pendingLineSpacing) { _ in checkChanges() }
                        Text("\(Int(pendingLineSpacing))px").font(.system(.caption, design: .monospaced)).frame(width: 36)
                    }
                    
                    Divider()
                    Text("Font Sizes").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    
                    FontSizeRow(label: "Folders", value: $pendingFolderFontSize, onChange: checkChanges)
                    FontSizeRow(label: "Conversations", value: $pendingConvFontSize, onChange: checkChanges)
                    FontSizeRow(label: "Messages", value: $pendingMsgFontSize, onChange: checkChanges)
                    
                    // Preview
                    VStack(alignment: .leading, spacing: pendingLineSpacing) {
                        Text("Folder Name").font(.system(size: pendingFolderFontSize, weight: .medium))
                        Text("Conversation Title").font(.system(size: pendingConvFontSize))
                        Text("Message content preview text.").font(.system(size: pendingMsgFontSize))
                        Text("func code() {}").font(.system(size: pendingMsgFontSize, design: .monospaced)).foregroundStyle(.pink)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(6)
                }
            }
            
            SettingCard(title: "TOOL CALLS", icon: "wrench.and.screwdriver", iconColor: .orange) {
                VStack(spacing: 10) {
                    // Display mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Mode").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $pendingToolMode) {
                            Text("Always Open").tag("open")
                            Text("Collapsible").tag("collapsible")
                            Text("Hidden").tag("hidden")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: pendingToolMode) { _ in checkChanges() }
                    }
                    
                    Divider()
                    
                    // Terminal style
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Terminal Style").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            TerminalStyleCard(name: "Terminal", bg: Color(white: 0.95), fg: .black, promptFg: Color(hex: "#2E7D32"),
                                              isSelected: pendingTerminalStyle == "terminal") { pendingTerminalStyle = "terminal"; checkChanges() }
                            TerminalStyleCard(name: "iTerm2", bg: Color(hex: "#1E1E2E"), fg: Color(hex: "#CDD6F4"), promptFg: Color(hex: "#89B4FA"),
                                              isSelected: pendingTerminalStyle == "iterm") { pendingTerminalStyle = "iterm"; checkChanges() }
                            TerminalStyleCard(name: "Warp", bg: Color(hex: "#16131F"), fg: Color(hex: "#B4A5FF"), promptFg: Color(hex: "#7C5BF0"),
                                              isSelected: pendingTerminalStyle == "warp") { pendingTerminalStyle = "warp"; checkChanges() }
                            TerminalStyleCard(name: "Hyper", bg: .black, fg: Color(hex: "#50FA7B"), promptFg: Color(hex: "#50FA7B"),
                                              isSelected: pendingTerminalStyle == "hyper") { pendingTerminalStyle = "hyper"; checkChanges() }
                        }
                    }
                    
                    Divider()
                    
                    // Diff style
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Diff View Style").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $pendingDiffStyle) {
                            Text("Inline").tag("inline")
                            Text("Side by Side").tag("sideBySide")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: pendingDiffStyle) { _ in checkChanges() }
                        
                        // Diff preview
                        DiffPreview(style: pendingDiffStyle)
                    }
                }
            }
            
            // Actions
            HStack {
                Button { showResetConfirm = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Restore Defaults")
                    }
                }
                Spacer()
                Button("Apply") { apply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear { loadCurrent() }
        .alert("Restore Default Appearance?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") { theme.resetToDefaults(); loadCurrent() }
        } message: { Text("This will reset theme mode to System, font to System 14px, and line spacing to 4px.") }
        .sheet(isPresented: $showNewTheme) {
            CustomThemeEditor(theme: nil) { ThemeManager.shared.saveCustomTheme($0) }
        }
        .sheet(item: $editingTheme) { existing in
            CustomThemeEditor(theme: existing) { ThemeManager.shared.saveCustomTheme($0) }
        }
    }
}

// MARK: - Theme Mode Card

struct ThemeModeCard: View {
    let mode: ThemeMode; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon).font(.title3).frame(height: 24)
                Text(mode.rawValue).font(.caption)
            }
            .frame(width: 70, height: 60)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Preview

struct ThemePreview: View {
    let theme: AppTheme
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(theme.accent.opacity(0.3)).frame(height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 10)
                Spacer()
            }.padding(6).frame(width: 70).background(theme.sidebar)
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text("How do I...").font(.caption2); Spacer() }.padding(4).background(theme.userBubble).cornerRadius(4)
                HStack { Text("Here's how:").font(.caption2); Spacer() }.padding(4).background(theme.assistantBubble).cornerRadius(4)
                Spacer()
            }.padding(6).background(theme.background)
        }
        .frame(height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
    }
}

// MARK: - Custom Theme Editor

struct CustomThemeEditor: View {
    let theme: AppTheme?; let onSave: (AppTheme) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "paintpalette"
    @State private var accentColor: Color = .purple
    @State private var sidebarColor: Color = Color(white: 0.95)
    @State private var backgroundColor: Color = .white
    @State private var userBubbleColor: Color = Color(hex: "#E8E0FF")
    @State private var assistantBubbleColor: Color = Color(hex: "#F0F0F0")
    
    var body: some View {
        VStack(spacing: 16) {
            Text(theme == nil ? "New Custom Theme" : "Edit Theme").font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Name").frame(width: 100, alignment: .leading)
                    TextField("Theme Name", text: $name)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Icon").frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        ForEach(AppTheme.availableIcons, id: \.self) { icon in
                            Button { selectedIcon = icon } label: {
                                Image(systemName: icon)
                                    .font(.body)
                                    .foregroundStyle(selectedIcon == icon ? accentColor : .secondary)
                                    .frame(width: 28, height: 28)
                                    .background(selectedIcon == icon ? accentColor.opacity(0.2) : Color.secondary.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedIcon == icon ? accentColor : Color.clear, lineWidth: 1.5))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                HStack { Text("Accent").frame(width: 100, alignment: .leading); ColorPicker("", selection: $accentColor).labelsHidden() }
                HStack { Text("Sidebar").frame(width: 100, alignment: .leading); ColorPicker("", selection: $sidebarColor).labelsHidden() }
                HStack { Text("Background").frame(width: 100, alignment: .leading); ColorPicker("", selection: $backgroundColor).labelsHidden() }
                HStack { Text("User Bubble").frame(width: 100, alignment: .leading); ColorPicker("", selection: $userBubbleColor).labelsHidden() }
                HStack { Text("Assistant Bubble").frame(width: 100, alignment: .leading); ColorPicker("", selection: $assistantBubbleColor).labelsHidden() }
            }
            .padding(.horizontal, 4)
            
            ThemePreview(theme: AppTheme(id: theme?.id ?? UUID().uuidString, name: name, accentHex: accentColor.hex, sidebarHex: sidebarColor.hex, backgroundHex: backgroundColor.hex, userBubbleHex: userBubbleColor.hex, assistantBubbleHex: assistantBubbleColor.hex, isBuiltIn: false, iconName: selectedIcon))
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    onSave(AppTheme(id: theme?.id ?? UUID().uuidString, name: name, accentHex: accentColor.hex, sidebarHex: sidebarColor.hex, backgroundHex: backgroundColor.hex, userBubbleHex: userBubbleColor.hex, assistantBubbleHex: assistantBubbleColor.hex, isBuiltIn: false, iconName: selectedIcon))
                    dismiss()
                }.disabled(name.isEmpty).buttonStyle(.borderedProminent)
            }
        }
        .padding().frame(width: 400, height: 480)
        .onAppear {
            if let t = theme { name = t.name; selectedIcon = t.iconName ?? "paintpalette"; accentColor = t.accent; sidebarColor = t.sidebar; backgroundColor = t.background; userBubbleColor = t.userBubble; assistantBubbleColor = t.assistantBubble }
        }
    }
}

// MARK: - Conversations

struct ConversationSettings: View {
    @AppStorage("isGroupedByWorkspace") private var isGroupedByWorkspace: Bool = false
    @AppStorage("groupSortOrder") private var groupSortOrder: String = "Name"
    @AppStorage("flatSortOrder") private var flatSortOrder: String = "Latest"
    @AppStorage("autoGenerateTitles") private var autoGenerateTitles: Bool = true
    @AppStorage("titleModel") private var titleModel: String = "qwen3-coder-480b"
    
    private let availableModels = [
        ("qwen3-coder-480b", "Qwen3 Coder 480B (0.01x)"),
        ("glm-4.7-flash", "GLM 4.7 Flash (0.05x)"),
        ("qwen3-coder-next", "Qwen3 Coder Next (0.05x)"),
        ("minimax-m2.1", "MiniMax M2.1 (0.15x)"),
        ("claude-haiku-4.5", "Claude Haiku 4.5 (0.40x)")
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            SettingCard(title: "LAYOUT", icon: "rectangle.split.3x1", iconColor: .green) {
                VStack(spacing: 10) {
                    SettingRow(icon: "folder", iconColor: .blue, title: "Group by Workspace", subtitle: "Organize conversations by directory") {
                        Toggle("", isOn: $isGroupedByWorkspace).labelsHidden()
                    }
                    Divider()
                    if isGroupedByWorkspace {
                        SettingRow(icon: "arrow.up.arrow.down", iconColor: .purple, title: "Group Sort") {
                            Picker("", selection: $groupSortOrder) {
                                Text("Name").tag("Name")
                                Text("Latest").tag("Latest Conversation")
                                Text("Oldest").tag("Oldest Conversation")
                            }.labelsHidden().frame(width: 120)
                        }
                    } else {
                        SettingRow(icon: "arrow.up.arrow.down", iconColor: .purple, title: "Sort Order") {
                            Picker("", selection: $flatSortOrder) {
                                Text("Title").tag("Title")
                                Text("Latest").tag("Latest")
                                Text("Oldest").tag("Oldest")
                            }.labelsHidden().frame(width: 120)
                        }
                    }
                }
            }
            
            SettingCard(title: "TITLE GENERATION", icon: "sparkles", iconColor: .yellow) {
                VStack(spacing: 10) {
                    SettingRow(icon: "wand.and.stars", iconColor: .purple, title: "Auto-generate on launch", subtitle: "Up to 10 titles per launch") {
                        Toggle("", isOn: $autoGenerateTitles).labelsHidden()
                    }
                    Divider()
                    SettingRow(icon: "cpu", iconColor: .teal, title: "Model") {
                        Picker("", selection: $titleModel) {
                            ForEach(availableModels, id: \.0) { Text($0.1).tag($0.0) }
                        }.labelsHidden().frame(width: 200)
                    }
                }
            }
            
            SettingCard(title: "FILTERING", icon: "line.3.horizontal.decrease.circle", iconColor: .gray) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Conversations in ~/Library/Application Support/ are automatically hidden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Backup

struct BackupSettings: View {
    @StateObject private var backupManager = BackupManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            SettingCard(title: "AUTO-BACKUP", icon: "clock.arrow.circlepath", iconColor: .orange) {
                VStack(spacing: 10) {
                    SettingRow(icon: "timer", iconColor: .blue, title: "Frequency", subtitle: "Backs up on every app launch") {
                        Text("1-hour cooldown").font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    SettingRow(icon: "tray.2", iconColor: .purple, title: "Max Backups") {
                        Text("3").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            
            SettingCard(title: "STORAGE", icon: "folder", iconColor: .blue) {
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location").font(.caption).foregroundStyle(.secondary)
                        Text("~/Library/Application Support/KiroChatViewer/backups/")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(4)
                    }
                    Button { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/KiroChatViewer/backups")) } label: {
                        HStack { Image(systemName: "folder"); Text("Open in Finder") }
                    }
                }
            }
            
            SettingCard(title: "EXISTING BACKUPS", icon: "archivebox", iconColor: .green) {
                if backupManager.backups.isEmpty {
                    HStack {
                        Image(systemName: "tray").foregroundStyle(.secondary)
                        Text("No backups yet").foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 6) {
                        ForEach(backupManager.backups) { backup in
                            HStack {
                                Image(systemName: "doc.zipper").foregroundStyle(.orange)
                                Text(backup.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                Spacer()
                                Text(backup.sizeString)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .padding(6)
                            .background(Color.secondary.opacity(0.03))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 16)
        .onAppear { backupManager.refreshBackupList() }
    }
}

// MARK: - Database

struct DatabaseSettings: View {
    var body: some View {
        VStack(spacing: 12) {
            SettingCard(title: "KIRO CLI DATABASE", icon: "cylinder", iconColor: .red) {
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Path").font(.caption).foregroundStyle(.secondary)
                        Text("~/Library/Application Support/kiro-cli/data.sqlite3")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(4)
                    }
                    Button { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/kiro-cli")) } label: {
                        HStack { Image(systemName: "folder"); Text("Open in Finder") }
                    }
                }
            }
            
            SettingCard(title: "HOW IT WORKS", icon: "questionmark.circle", iconColor: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "1.circle", color: .blue, text: "Reads conversations from the Kiro CLI database")
                    InfoRow(icon: "2.circle", color: .green, text: "Merges missing conversations from the latest backup")
                    InfoRow(icon: "3.circle", color: .orange, text: "Database is never modified except when you delete a conversation")
                }
            }
        }
        .padding(.bottom, 16)
    }
}

struct InfoRow: View {
    let icon: String; let color: Color; let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.caption)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct FontSizeRow: View {
    let label: String
    @Binding var value: Double
    var onChange: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            Slider(value: $value, in: 10...22, step: 1)
                .onChange(of: value) { _ in onChange?() }
            Text("\(Int(value))px").font(.system(.caption, design: .monospaced)).frame(width: 36)
        }
    }
}

struct TerminalStyleCard: View {
    let name: String; let bg: Color; let fg: Color; let promptFg: Color; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Text("$").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(promptFg)
                        Text("swift build").font(.system(size: 8, design: .monospaced)).foregroundStyle(fg)
                    }
                    Text("Build complete!").font(.system(size: 7, design: .monospaced)).foregroundStyle(fg.opacity(0.6))
                }
                .padding(6)
                .frame(width: 90, height: 36)
                .background(bg)
                .cornerRadius(4)
                .overlay(name == "Warp" ? RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#7C5BF0").opacity(0.3), lineWidth: 1) : nil)
                
                Text(name).font(.caption2)
            }
            .padding(4)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct DiffPreview: View {
    let style: String
    var body: some View {
        if style == "sideBySide" {
            HStack(spacing: 1) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Old").font(.system(size: 8, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 2)
                    HStack(spacing: 2) {
                        Text("−").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.red)
                        Text("let x = false").font(.system(size: 8, design: .monospaced))
                    }.padding(.horizontal, 4).padding(.vertical, 1).frame(maxWidth: .infinity, alignment: .leading).background(Color.red.opacity(0.1))
                    HStack(spacing: 2) {
                        Text(" ").font(.system(size: 8, design: .monospaced))
                        Text("let y = 10").font(.system(size: 8, design: .monospaced))
                    }.padding(.horizontal, 4).padding(.vertical, 1)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor).opacity(0.5))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("New").font(.system(size: 8, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 2)
                    HStack(spacing: 2) {
                        Text("+").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.green)
                        Text("let x = true").font(.system(size: 8, design: .monospaced))
                    }.padding(.horizontal, 4).padding(.vertical, 1).frame(maxWidth: .infinity, alignment: .leading).background(Color.green.opacity(0.1))
                    HStack(spacing: 2) {
                        Text(" ").font(.system(size: 8, design: .monospaced))
                        Text("let y = 10").font(.system(size: 8, design: .monospaced))
                    }.padding(.horizontal, 4).padding(.vertical, 1)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor).opacity(0.5))
            }
            .cornerRadius(6)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("−").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.red).frame(width: 10)
                    Text("let x = false").font(.system(size: 8, design: .monospaced))
                }.padding(.horizontal, 6).padding(.vertical, 1).frame(maxWidth: .infinity, alignment: .leading).background(Color.red.opacity(0.1))
                HStack(spacing: 4) {
                    Text("+").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.green).frame(width: 10)
                    Text("let x = true").font(.system(size: 8, design: .monospaced))
                }.padding(.horizontal, 6).padding(.vertical, 1).frame(maxWidth: .infinity, alignment: .leading).background(Color.green.opacity(0.1))
                HStack(spacing: 4) {
                    Text(" ").frame(width: 10)
                    Text("let y = 10").font(.system(size: 8, design: .monospaced))
                }.padding(.horizontal, 6).padding(.vertical, 1)
            }
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)
        }
    }
}
