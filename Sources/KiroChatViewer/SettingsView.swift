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
}

struct SettingsView: View {
    @StateObject private var theme = ThemeManager.shared
    @State private var selectedTab: SettingsTab = .about
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .frame(width: 20)
                            Text(tab.rawValue)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 8)
            .frame(width: 190)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Detail
            ScrollView {
                VStack(alignment: .leading) {
                    switch selectedTab {
                    case .about: AboutSettings()
                    case .appearance: AppearanceSettings()
                    case .conversations: ConversationSettings()
                    case .backup: BackupSettings()
                    case .database: DatabaseSettings()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 380)
        .preferredColorScheme(theme.colorScheme)
    }
}

// MARK: - About

struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .cornerRadius(20)
                .shadow(radius: 4)
            
            VStack(spacing: 4) {
                Text("KiroChatViewer")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Version 3.3.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("A native macOS app to view, search, and manage your Kiro CLI chat conversations.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            VStack(spacing: 4) {
                Text("Developer")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Hiten Garg")
                    .font(.body)
            }
            
            Link("GitHub Repository", destination: URL(string: "https://github.com/hitengarg45/KiroChatViewer")!)
                .font(.caption)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Appearance

struct AppearanceSettings: View {
    @StateObject private var theme = ThemeManager.shared
    @State private var showNewTheme = false
    @State private var editingTheme: AppTheme?
    @State private var showResetConfirm = false
    
    // Pending state
    @State private var pendingMode: ThemeMode = .system
    @State private var pendingFontSize: Double = 14
    @State private var pendingLineSpacing: Double = 4
    @State private var pendingFontFamily: String = "System"
    @State private var hasChanges = false
    
    private func loadCurrent() {
        pendingMode = theme.mode
        pendingFontSize = theme.fontSize
        pendingLineSpacing = theme.lineSpacing
        pendingFontFamily = theme.fontFamily
        hasChanges = false
    }
    
    private func checkChanges() {
        hasChanges = pendingMode != theme.mode ||
            pendingFontSize != theme.fontSize ||
            pendingLineSpacing != theme.lineSpacing ||
            pendingFontFamily != theme.fontFamily
    }
    
    private func apply() {
        theme.mode = pendingMode
        theme.fontSize = pendingFontSize
        theme.lineSpacing = pendingLineSpacing
        theme.fontFamily = pendingFontFamily
        hasChanges = false
    }
    
    private var previewTheme: AppTheme {
        switch pendingMode {
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        case .kiro: return .kiro
        }
    }
    
    var body: some View {
        Form {
            Section("Theme Mode") {
                HStack(spacing: 12) {
                    ForEach(ThemeMode.allCases) { mode in
                        ThemeModeCard(mode: mode, isSelected: pendingMode == mode) {
                            pendingMode = mode
                            checkChanges()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Preview") {
                ThemePreview(theme: previewTheme)
            }
            
            Section("Font") {
                Picker("Family", selection: $pendingFontFamily) {
                    ForEach(ThemeManager.availableFonts, id: \.self) { name in
                        Text(name).font(name == "System" ? .system(size: 13) : .custom(name, size: 13)).tag(name)
                    }
                }
                .onChange(of: pendingFontFamily) { _ in checkChanges() }
                
                HStack {
                    Text("Size")
                    Slider(value: $pendingFontSize, in: 11...20, step: 1)
                        .onChange(of: pendingFontSize) { _ in checkChanges() }
                    Text("\(Int(pendingFontSize))px")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 36)
                }
                HStack {
                    Text("Line Spacing")
                    Slider(value: $pendingLineSpacing, in: 0...12, step: 1)
                        .onChange(of: pendingLineSpacing) { _ in checkChanges() }
                    Text("\(Int(pendingLineSpacing))px")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 36)
                }
                
                VStack(alignment: .leading, spacing: pendingLineSpacing) {
                    Text("The quick brown fox jumps over the lazy dog.")
                        .font(pendingFontFamily == "System" ? .system(size: pendingFontSize) : .custom(pendingFontFamily, size: pendingFontSize))
                    Text("func hello() { print(\"world\") }")
                        .font(.system(size: pendingFontSize, design: .monospaced))
                        .foregroundStyle(.pink)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            }
            
            Section("Custom Themes") {
                ForEach(theme.customThemes) { custom in
                    HStack {
                        Circle().fill(Color(hex: custom.accentHex)).frame(width: 14, height: 14)
                        Text(custom.name)
                        Spacer()
                        Button("Edit") { editingTheme = custom }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        Button("Delete") { theme.deleteCustomTheme(custom) }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                    }
                }
                Button("Create Custom Theme") { showNewTheme = true }
            }
            
            Section {
                HStack {
                    Button("Restore Defaults") { showResetConfirm = true }
                    Spacer()
                    Button("Apply") { apply() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasChanges)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadCurrent() }
        .alert("Restore Default Appearance?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") {
                theme.resetToDefaults()
                loadCurrent()
            }
        } message: {
            Text("This will reset theme mode to System, font to System 14px, and line spacing to 4px.")
        }
        .sheet(isPresented: $showNewTheme) {
            CustomThemeEditor(theme: nil) { newTheme in
                ThemeManager.shared.saveCustomTheme(newTheme)
            }
        }
        .sheet(item: $editingTheme) { existing in
            CustomThemeEditor(theme: existing) { updated in
                ThemeManager.shared.saveCustomTheme(updated)
            }
        }
    }
}

// MARK: - Theme Mode Card

struct ThemeModeCard: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .frame(height: 24)
                Text(mode.rawValue)
                    .font(.caption)
            }
            .frame(width: 70, height: 60)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
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
            // Sidebar preview
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(theme.accent.opacity(0.3)).frame(height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 10)
                Spacer()
            }
            .padding(6)
            .frame(width: 70)
            .background(theme.sidebar)
            
            // Chat preview
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("How do I...").font(.caption2).foregroundStyle(.primary)
                    Spacer()
                }
                .padding(4)
                .background(theme.userBubble)
                .cornerRadius(4)
                
                HStack {
                    Text("Here's how:").font(.caption2).foregroundStyle(.primary)
                    Spacer()
                }
                .padding(4)
                .background(theme.assistantBubble)
                .cornerRadius(4)
                
                Spacer()
            }
            .padding(6)
            .background(theme.background)
        }
        .frame(height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
    }
}

// MARK: - Custom Theme Editor

struct CustomThemeEditor: View {
    let theme: AppTheme?
    let onSave: (AppTheme) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var accentColor: Color = .purple
    @State private var sidebarColor: Color = Color(white: 0.95)
    @State private var backgroundColor: Color = .white
    @State private var userBubbleColor: Color = Color(hex: "#E8E0FF")
    @State private var assistantBubbleColor: Color = Color(hex: "#F0F0F0")
    
    var body: some View {
        VStack(spacing: 16) {
            Text(theme == nil ? "New Custom Theme" : "Edit Theme")
                .font(.headline)
            
            Form {
                TextField("Theme Name", text: $name)
                ColorPicker("Accent Color", selection: $accentColor)
                ColorPicker("Sidebar Background", selection: $sidebarColor)
                ColorPicker("Content Background", selection: $backgroundColor)
                ColorPicker("User Bubble", selection: $userBubbleColor)
                ColorPicker("Assistant Bubble", selection: $assistantBubbleColor)
            }
            
            // Live preview
            ThemePreview(theme: AppTheme(
                id: theme?.id ?? UUID().uuidString,
                name: name,
                accentHex: accentColor.hex,
                sidebarHex: sidebarColor.hex,
                backgroundHex: backgroundColor.hex,
                userBubbleHex: userBubbleColor.hex,
                assistantBubbleHex: assistantBubbleColor.hex,
                isBuiltIn: false
            ))
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let saved = AppTheme(
                        id: theme?.id ?? UUID().uuidString,
                        name: name,
                        accentHex: accentColor.hex,
                        sidebarHex: sidebarColor.hex,
                        backgroundHex: backgroundColor.hex,
                        userBubbleHex: userBubbleColor.hex,
                        assistantBubbleHex: assistantBubbleColor.hex,
                        isBuiltIn: false
                    )
                    onSave(saved)
                    dismiss()
                }
                .disabled(name.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 380, height: 420)
        .onAppear {
            if let t = theme {
                name = t.name
                accentColor = t.accent
                sidebarColor = t.sidebar
                backgroundColor = t.background
                userBubbleColor = t.userBubble
                assistantBubbleColor = t.assistantBubble
            }
        }
    }
}

// MARK: - Conversations

struct ConversationSettings: View {
    @AppStorage("isGroupedByWorkspace") private var isGroupedByWorkspace: Bool = false
    @AppStorage("groupSortOrder") private var groupSortOrder: String = "Name"
    @AppStorage("flatSortOrder") private var flatSortOrder: String = "Latest"
    
    var body: some View {
        Form {
            Section("Layout") {
                Toggle("Group by Workspace", isOn: $isGroupedByWorkspace)
            }
            
            Section("Default Sort Order") {
                if isGroupedByWorkspace {
                    Picker("Group Sort", selection: $groupSortOrder) {
                        Text("Name").tag("Name")
                        Text("Latest Conversation").tag("Latest Conversation")
                        Text("Oldest Conversation").tag("Oldest Conversation")
                    }
                } else {
                    Picker("Sort By", selection: $flatSortOrder) {
                        Text("Title").tag("Title")
                        Text("Latest").tag("Latest")
                        Text("Oldest").tag("Oldest")
                    }
                }
            }
            
            Section("Filtering") {
                Text("Conversations in ~/Library/Application Support/ are automatically hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Backup

struct BackupSettings: View {
    @StateObject private var backupManager = BackupManager.shared
    
    var body: some View {
        Form {
            Section("Auto-Backup") {
                LabeledContent("Frequency") {
                    Text("Every app launch (1-hour cooldown)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Max Backups") {
                    Text("3")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Storage") {
                LabeledContent("Location") {
                    Text("~/Library/Application Support/KiroChatViewer/backups/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                
                Button("Open in Finder") {
                    let url = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Application Support/KiroChatViewer/backups")
                    NSWorkspace.shared.open(url)
                }
            }
            
            Section("Existing Backups") {
                if backupManager.backups.isEmpty {
                    Text("No backups yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(backupManager.backups) { backup in
                        LabeledContent(backup.date.formatted(date: .abbreviated, time: .shortened)) {
                            Text(backup.sizeString)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { backupManager.refreshBackupList() }
    }
}

// MARK: - Database

struct DatabaseSettings: View {
    var body: some View {
        Form {
            Section("Kiro CLI Database") {
                LabeledContent("Path") {
                    Text("~/Library/Application Support/kiro-cli/data.sqlite3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                
                Button("Open in Finder") {
                    let url = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Application Support/kiro-cli")
                    NSWorkspace.shared.open(url)
                }
            }
            
            Section("How It Works") {
                Text("The app reads conversations from the Kiro CLI database and merges any missing ones from the latest backup. The database is never modified except when you delete a conversation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
