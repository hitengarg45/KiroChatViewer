import SwiftUI

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case kiro = "Kiro"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .system: return "laptopcomputer"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .kiro: return "sparkles"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark, .kiro: return .dark
        }
    }
}

// MARK: - App Theme

struct AppTheme: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let accentHex: String
    let sidebarHex: String
    let backgroundHex: String
    let userBubbleHex: String
    let assistantBubbleHex: String
    let isBuiltIn: Bool
    var iconName: String?
    
    var accent: Color { Color(hex: accentHex) }
    var sidebar: Color { Color(hex: sidebarHex) }
    var background: Color { Color(hex: backgroundHex) }
    var userBubble: Color { Color(hex: userBubbleHex) }
    var assistantBubble: Color { Color(hex: assistantBubbleHex) }
    
    static let availableIcons = ["paintpalette", "leaf", "flame", "snowflake", "bolt", "heart", "star", "cloud", "drop", "wand.and.stars"]
    
    static let light = AppTheme(id: "light", name: "Light", accentHex: "#8B5CF6", sidebarHex: "#F5F5F5", backgroundHex: "#FFFFFF", userBubbleHex: "#E8E0FF", assistantBubbleHex: "#F0F0F0", isBuiltIn: true)
    static let dark = AppTheme(id: "dark", name: "Dark", accentHex: "#A78BFA", sidebarHex: "#1E1E1E", backgroundHex: "#1A1A1A", userBubbleHex: "#2D2554", assistantBubbleHex: "#2A2A2A", isBuiltIn: true)
    static let kiro = AppTheme(id: "kiro", name: "Kiro", accentHex: "#C084FC", sidebarHex: "#150B26", backgroundHex: "#0D0618", userBubbleHex: "#4C2882", assistantBubbleHex: "#2A1650", isBuiltIn: true)
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("themeMode") var themeMode: String = ThemeMode.system.rawValue
    @AppStorage("fontSize") var fontSize: Double = 14
    @AppStorage("lineSpacing") var lineSpacing: Double = 4
    @AppStorage("fontFamily") var fontFamily: String = "System"
    @AppStorage("folderFontSize") var folderFontSize: Double = 14
    @AppStorage("conversationFontSize") var conversationFontSize: Double = 13
    @AppStorage("messageFontSize") var messageFontSize: Double = 14
    @AppStorage("toolDisplayMode") var toolDisplayMode: String = "open"
    @AppStorage("terminalStyle") var terminalStyle: String = "terminal"
    @AppStorage("diffStyle") var diffStyle: String = "inline"
    @Published var customThemes: [AppTheme] = []
    @AppStorage("activeCustomThemeId") var activeCustomThemeId: String = ""
    
    var mode: ThemeMode {
        get { ThemeMode(rawValue: themeMode) ?? .system }
        set { themeMode = newValue.rawValue }
    }
    
    var colorScheme: ColorScheme? {
        if isCustomTheme {
            // Determine from background brightness
            let bg = activeTheme.backgroundHex
            let hex = bg.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
            let brightness: Double = {
                let r = Double((int >> 16) & 0xFF)
                let g = Double((int >> 8) & 0xFF)
                let b = Double(int & 0xFF)
                return (r + g + b) / (255.0 * 3.0)
            }()
            return brightness < 0.5 ? .dark : .light
        }
        switch mode {
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        case .light: return .light
        case .dark, .kiro: return .dark
        }
    }
    
    var activeTheme: AppTheme {
        if !activeCustomThemeId.isEmpty,
           let custom = customThemes.first(where: { $0.id == activeCustomThemeId }) {
            return custom
        }
        switch mode {
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        case .kiro: return .kiro
        }
    }
    
    var isCustomTheme: Bool { !activeCustomThemeId.isEmpty }
    var isKiro: Bool { mode == .kiro && !isCustomTheme }
    var usesCustomColors: Bool { isKiro || isCustomTheme }
    
    func resetToDefaults() {
        mode = .system
        fontSize = 14
        lineSpacing = 4
        fontFamily = "System"
        folderFontSize = 14
        conversationFontSize = 13
        messageFontSize = 14
        toolDisplayMode = "open"
        terminalStyle = "terminal"
        diffStyle = "inline"
        activeCustomThemeId = ""
    }
    
    static let availableFonts = [
        "System",
        "SF Pro",
        "Helvetica Neue",
        "Avenir Next",
        "Georgia",
        "Menlo",
        "Monaco",
        "Source Code Pro"
    ]
    
    func font(size: CGFloat? = nil, design: Font.Design? = nil) -> Font {
        let s = CGFloat(size ?? fontSize)
        if fontFamily == "System" {
            return .system(size: s, design: design ?? .default)
        }
        return .custom(fontFamily, size: s)
    }
    
    private let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/KiroChatViewer/custom_themes.json")
    
    init() { loadCustomThemes() }
    
    func saveCustomTheme(_ theme: AppTheme) {
        if let idx = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[idx] = theme
        } else {
            customThemes.append(theme)
        }
        persistCustomThemes()
    }
    
    func deleteCustomTheme(_ theme: AppTheme) {
        customThemes.removeAll { $0.id == theme.id }
        if activeCustomThemeId == theme.id { activeCustomThemeId = "" }
        persistCustomThemes()
    }
    
    private func loadCustomThemes() {
        guard let data = try? Data(contentsOf: fileURL),
              let themes = try? JSONDecoder().decode([AppTheme].self, from: data) else { return }
        customThemes = themes
    }
    
    private func persistCustomThemes() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(customThemes) else { return }
        try? data.write(to: fileURL)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
    
    var hex: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
