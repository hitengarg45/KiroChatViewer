import SwiftUI

struct ContentView: View {
    @StateObject private var db = DatabaseManager()
    @StateObject private var bookmarks = BookmarkManager()
    @StateObject private var titles = TitleManager()
    @StateObject private var perf = PerformanceMonitor()
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var selectedFolder: BookmarkFolder?
    @State private var showNewFolderSheet = false
    @State private var newFolderName = ""
    @State private var showFolderPicker = false
    @AppStorage("isGroupedByWorkspace") private var isGroupedByWorkspace: Bool = false
    @AppStorage("groupSortOrder") private var groupSortOrder: GroupSortOrder = .name
    @AppStorage("flatSortOrder") private var flatSortOrder: FlatSortOrder = .latest
    @State private var expandedDirectories: Set<String> = []
    @State private var showTimeline = false
    @State private var showPerformance = false
    
    enum GroupSortOrder: String {
        case name = "Name"
        case latestConversation = "Latest Conversation"
        case oldestConversation = "Oldest Conversation"
    }
    
    enum FlatSortOrder: String {
        case title = "Title"
        case latest = "Latest"
        case oldest = "Oldest"
    }
    
    var filteredConversations: [Conversation] {
        var convs = db.conversations
        
        // Filter by folder if selected
        if let folder = selectedFolder {
            convs = convs.filter { folder.conversationIds.contains($0.id) }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            convs = convs.filter { conv in
                let displayTitle = titles.getTitle(for: conv.id) ?? conv.title
                return displayTitle.localizedCaseInsensitiveContains(searchText) ||
                conv.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sort based on flat sort order
        return convs.sorted { lhs, rhs in
            let lhsPinned = titles.isPinned(lhs.id)
            let rhsPinned = titles.isPinned(rhs.id)
            if lhsPinned != rhsPinned {
                return lhsPinned
            }
            
            switch flatSortOrder {
            case .title:
                let lhsTitle = titles.getTitle(for: lhs.id) ?? lhs.title
                let rhsTitle = titles.getTitle(for: rhs.id) ?? rhs.title
                return lhsTitle.localizedCaseInsensitiveCompare(rhsTitle) == .orderedAscending
            case .latest:
                return lhs.updatedAt > rhs.updatedAt
            case .oldest:
                return lhs.updatedAt < rhs.updatedAt
            }
        }
    }
    
    var groupedConversations: [(directory: String, conversations: [Conversation])] {
        let grouped = Dictionary(grouping: filteredConversations) { $0.directory }
        let mapped = grouped.map { (directory: $0.key, conversations: $0.value.sorted { lhs, rhs in
            let lhsPinned = titles.isPinned(lhs.id)
            let rhsPinned = titles.isPinned(rhs.id)
            if lhsPinned != rhsPinned {
                return lhsPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }) }
        
        switch groupSortOrder {
        case .name:
            return mapped.sorted { $0.directory < $1.directory }
        case .latestConversation:
            return mapped.sorted { ($0.conversations.first?.updatedAt ?? .distantPast) > ($1.conversations.first?.updatedAt ?? .distantPast) }
        case .oldestConversation:
            return mapped.sorted { ($0.conversations.last?.updatedAt ?? .distantFuture) < ($1.conversations.last?.updatedAt ?? .distantFuture) }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Folders section
                folderSection
                
                Divider()
                
                // Conversations list
                if isGroupedByWorkspace {
                    List(selection: $selectedConversation) {
                        ForEach(groupedConversations, id: \.directory) { group in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedDirectories.contains(group.directory) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedDirectories.insert(group.directory)
                                        } else {
                                            expandedDirectories.remove(group.directory)
                                        }
                                    }
                                )
                            ) {
                                ForEach(group.conversations) { conv in
                                    ConversationRow(
                                        conversation: conv,
                                        bookmarks: bookmarks,
                                        titles: titles,
                                        onDelete: {
                                            if selectedConversation?.id == conv.id { selectedConversation = nil }
                                            db.deleteConversation(conv)
                                        }
                                    )
                                    .tag(conv)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.directory.split(separator: "/").last.map(String.init) ?? group.directory)
                                            .fontWeight(.medium)
                                        Text(group.directory)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text("\(group.conversations.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .overlay {
                        if filteredConversations.isEmpty {
                            emptyStateView
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search conversations")
                    .padding(.top, 4)
                } else {
                    List(filteredConversations, selection: $selectedConversation) { conv in
                        ConversationRow(
                            conversation: conv,
                            bookmarks: bookmarks,
                            titles: titles,
                            onDelete: {
                                if selectedConversation?.id == conv.id { selectedConversation = nil }
                                db.deleteConversation(conv)
                            }
                        )
                        .tag(conv)
                    }
                    .overlay {
                        if filteredConversations.isEmpty {
                            emptyStateView
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search conversations")
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Kiro Chats")
            .toolbar {
                Button { showFolderPicker = true } label: {
                    Label("New Chat", systemImage: "plus.message")
                }
                .help("Start a new chat in a folder")
                
                Toggle(isOn: $isGroupedByWorkspace) {
                    Label("Group", systemImage: isGroupedByWorkspace ? "folder.fill" : "list.bullet")
                }
                .toggleStyle(.button)
                .help(isGroupedByWorkspace ? "Show flat list" : "Group by workspace")
                
                Menu {
                    if isGroupedByWorkspace {
                        Picker("Sort Groups By", selection: $groupSortOrder) {
                            Text("Name").tag(GroupSortOrder.name)
                            Text("Latest Conversation").tag(GroupSortOrder.latestConversation)
                            Text("Oldest Conversation").tag(GroupSortOrder.oldestConversation)
                        }
                    } else {
                        Picker("Sort By", selection: $flatSortOrder) {
                            Text("Title").tag(FlatSortOrder.title)
                            Text("Latest").tag(FlatSortOrder.latest)
                            Text("Oldest").tag(FlatSortOrder.oldest)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help(isGroupedByWorkspace ? "Sort workspace groups" : "Sort conversations")
                
                Menu {
                    Button { showTimeline = true } label: {
                        Label("Timeline", systemImage: "clock")
                    }
                    Button { showPerformance = true } label: {
                        Label("Performance", systemImage: "speedometer")
                    }
                } label: {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }
                .help("View tools and metrics")
                .popover(isPresented: $showPerformance) {
                    PerformancePopover(monitor: perf)
                }
                
                Toggle(isOn: $isDarkMode) {
                    Label(isDarkMode ? "Dark" : "Light", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                }
                .toggleStyle(.button)
                .help(isDarkMode ? "Switch to Light mode" : "Switch to Dark mode")
                
                Button {
                    withAnimation(.linear(duration: 0.5)) { rotationAngle += 360 }
                    perf.start("Load")
                    Task {
                        db.loadConversations()
                        try? await Task.sleep(for: .milliseconds(100))
                        await MainActor.run {
                            perf.end("Load")
                            perf.record("Count", "\(db.conversations.count)")
                        }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .rotationEffect(.degrees(rotationAngle))
                .help("Refresh conversation list")
            }
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    let appleScript = """
                    tell application "Terminal"
                        activate
                        do script "cd '\(url.path)' && kiro-cli chat"
                    end tell
                    """
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    proc.arguments = ["-e", appleScript]
                    try? proc.run()
                }
            }
        } detail: {
            if let conv = selectedConversation {
                ConversationDetailView(conversation: conv, selectedConversation: $selectedConversation)
                    .environmentObject(db)
                    .id("\(conv.id)-\(conv.messages.count)")
            } else {
                Text("Select a conversation")
                    .foregroundStyle(.secondary)
            }
        }
        .environmentObject(bookmarks)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            AppLogger.ui.info("App launched")
            perf.start("Load")
            db.loadConversations()
        }
        .onChange(of: db.conversations) { _ in
            perf.end("Load")
            perf.record("Count", "\(db.conversations.count)")
            AppLogger.ui.info("Conversations updated: \(db.conversations.count) total")
        }
        .alert("Error", isPresented: .constant(db.error != nil)) {
            Button("OK") { db.error = nil }
        } message: {
            Text(db.error ?? "")
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet(name: $newFolderName) {
                if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                    bookmarks.createFolder(name: newFolderName.trimmingCharacters(in: .whitespaces))
                }
                newFolderName = ""
            }
        }
        .sheet(isPresented: $showTimeline) {
            TimelineView(conversations: db.conversations)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: db.conversations.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(db.conversations.isEmpty ? "No Conversations Yet" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(db.conversations.isEmpty 
                ? "Start a new chat to see it here"
                : "Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if db.conversations.isEmpty {
                Button {
                    showFolderPicker = true
                } label: {
                    Label("Start New Chat", systemImage: "plus.message")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Folders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button { showNewFolderSheet = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // All conversations
            FolderRow(
                name: "All Conversations",
                icon: "tray.full",
                count: db.conversations.count,
                isSelected: selectedFolder == nil
            )
            .onTapGesture { selectedFolder = nil }
            
            // Bookmark folders
            ForEach(bookmarks.folders) { folder in
                FolderRow(
                    name: folder.name,
                    icon: folder.isBuiltIn ? "star.fill" : "folder.fill",
                    iconColor: folder.isBuiltIn ? .yellow : .blue,
                    count: folder.conversationIds.count,
                    isSelected: selectedFolder?.id == folder.id,
                    isCustom: !folder.isBuiltIn,
                    onDelete: { bookmarks.deleteFolder(folder) },
                    onRename: { bookmarks.renameFolder(folder, to: $0) }
                )
                .onTapGesture { selectedFolder = folder }
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let name: String
    let icon: String
    var iconColor: Color = .secondary
    var count: Int
    var isSelected: Bool
    var isCustom: Bool = false
    var onDelete: (() -> Void)?
    var onRename: ((String) -> Void)?
    
    @State private var isHovering = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if isCustom && isHovering {
                Menu {
                    Button {
                        renameText = name
                        showRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 4)
        .onHover { isHovering = $0 }
        .alert("Delete Folder?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete?() }
        } message: {
            Text("Bookmarks in this folder will be removed.")
        }
        .sheet(isPresented: $showRename) {
            NewFolderSheet(name: $renameText, title: "Rename Folder", buttonLabel: "Rename") {
                if !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    onRename?(renameText.trimmingCharacters(in: .whitespaces))
                }
            }
        }
    }
}

// MARK: - New Folder Sheet

struct NewFolderSheet: View {
    @Binding var name: String
    var title: String = "New Folder"
    var buttonLabel: String = "Create"
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(.headline)
            TextField("Folder name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit { onSubmit(); dismiss() }
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(buttonLabel) { onSubmit(); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var titles: TitleManager
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var showDeleteConfirm = false
    @State private var showRenameDialog = false
    @State private var editedTitle = ""
    
    var displayTitle: String {
        titles.getTitle(for: conversation.id) ?? conversation.title
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if titles.isPinned(conversation.id) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if bookmarks.isBookmarked(conversationId: conversation.id) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text(displayTitle)
                        .lineLimit(2)
                }
                HStack {
                    Text(conversation.directory.split(separator: "/").last ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if isHovering {
                Menu {
                    Button {
                        titles.togglePin(for: conversation.id)
                    } label: {
                        Label(titles.isPinned(conversation.id) ? "Unpin" : "Pin", 
                              systemImage: titles.isPinned(conversation.id) ? "pin.slash" : "pin")
                    }
                    
                    Button {
                        editedTitle = displayTitle
                        showRenameDialog = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    // Bookmark submenu
                    Menu {
                        ForEach(bookmarks.folders) { folder in
                            let isIn = folder.conversationIds.contains(conversation.id)
                            Button {
                                if isIn {
                                    bookmarks.removeBookmark(conversationId: conversation.id, from: folder.id)
                                } else {
                                    bookmarks.addBookmark(conversationId: conversation.id, to: folder.id)
                                }
                            } label: {
                                HStack {
                                    Text(folder.name)
                                    if isIn { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Label("Bookmark", systemImage: "bookmark")
                    }
                    
                    Button {
                        resumeInTerminal(conversation)
                    } label: {
                        Label("View in Terminal", systemImage: "terminal")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
            }
        }
        .padding(.vertical, 4)
        .onHover { isHovering = $0 }
        .alert("Delete Conversation?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This will permanently delete this conversation from the database.")
        }
        .alert("Rename Conversation", isPresented: $showRenameDialog) {
            TextField("Title", text: $editedTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                titles.setTitle(editedTitle, for: conversation.id)
            }
        }
    }
    
    private func resumeInTerminal(_ conversation: Conversation) {
        let dir = conversation.directory
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let appleScript = """
            tell application "Terminal"
                activate
                do script "cd '\(dir)' && kiro-cli chat --resume-picker"
            end tell
            """
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", appleScript]
            try? proc.run()
        }
    }
}
