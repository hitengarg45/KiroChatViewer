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

