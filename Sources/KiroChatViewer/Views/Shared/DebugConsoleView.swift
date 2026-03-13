import SwiftUI

// MARK: - Bottom Debug Drawer (Xcode-style)

struct DebugDrawer: View {
    @ObservedObject private var buffer = LogBuffer.shared
    @Binding var isShowing: Bool
    @State private var drawerHeight: CGFloat = 220
    @State private var filterCategory = "All"
    @State private var filterLevel = "All"
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var isDragging = false
    
    private let minHeight: CGFloat = 120
    private let maxHeight: CGFloat = 500
    private let categories = ["All", "database", "ui", "performance", "acp"]
    private let levels = ["All", "DEBUG", "INFO", "NOTICE", "ERROR"]
    
    private var filteredEntries: [LogEntry] {
        buffer.entries.filter { entry in
            (filterCategory == "All" || entry.category == filterCategory) &&
            (filterLevel == "All" || entry.level == filterLevel) &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle + toolbar
            dragHandle
            
            Divider()
            
            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredEntries) { entry in
                            logRow(entry)
                        }
                        Color.clear.frame(height: 1).id("drawer-bottom")
                    }
                }
                .onChange(of: buffer.entries.count) { _ in
                    if autoScroll {
                        proxy.scrollTo("drawer-bottom", anchor: .bottom)
                    }
                }
            }
        }
        .frame(height: drawerHeight)
        .background(Color(nsColor: .controlBackgroundColor))
        .transition(.move(edge: .bottom))
    }
    
    // MARK: - Drag Handle + Toolbar
    
    private var dragHandle: some View {
        VStack(spacing: 0) {
            // Draggable divider
            Rectangle()
                .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(height: 3)
                .contentShape(Rectangle().size(width: 10000, height: 12))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newHeight = drawerHeight - value.translation.height
                            drawerHeight = min(max(newHeight, minHeight), maxHeight)
                        }
                        .onEnded { _ in isDragging = false }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            
            // Toolbar
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("Debug Console")
                    .font(.system(size: 11, weight: .semibold))
                
                // Category pills
                ForEach(categories, id: \.self) { cat in
                    categoryPill(cat)
                }
                
                // Level filter
                Picker("", selection: $filterLevel) {
                    ForEach(levels, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 80)
                .controlSize(.small)
                
                Spacer()
                
                TextField("Filter", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 140)
                
                Text("\(filteredEntries.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Toggle("", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .help("Auto-scroll")
                
                Button { buffer.clear() } label: {
                    Image(systemName: "trash").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear logs")
                
                Button { withAnimation(.easeInOut(duration: 0.2)) { isShowing = false } } label: {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close debug console")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
    
    private func categoryPill(_ cat: String) -> some View {
        let label = cat == "All" ? "All" : String(cat.prefix(3)).uppercased()
        let isSelected = filterCategory == cat
        let count = cat == "All" ? buffer.entries.count : buffer.entries.filter({ $0.category == cat }).count
        
        return Button {
            filterCategory = cat
        } label: {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular, design: .monospaced))
                if count > 0 && cat != "All" {
                    Text("\(count)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
    
    // MARK: - Log Row
    
    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 75, alignment: .leading)
            
            Text(levelIcon(entry.level))
                .font(.system(size: 9))
                .frame(width: 14)
            
            Text(entry.category)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(categoryColor(entry.category))
                .frame(width: 65, alignment: .leading)
            
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(entry.level == "ERROR" ? .red : .primary)
                .textSelection(.enabled)
                .lineLimit(nil)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.level == "ERROR" ? Color.red.opacity(0.05) : Color.clear)
    }
    
    private func levelIcon(_ level: String) -> String {
        switch level {
        case "ERROR": return "🔴"
        case "NOTICE": return "🟡"
        case "DEBUG": return "⚪"
        default: return "🔵"
        }
    }
    
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "acp": return .green
        case "database": return .blue
        case "ui": return .purple
        case "performance": return .orange
        default: return .secondary
        }
    }
}
