import SwiftUI

struct ContentView: View {
    @StateObject private var db = DatabaseManager()
    @StateObject private var bookmarks = BookmarkManager()
    @StateObject private var titles = TitleManager()
    @StateObject private var perf = PerformanceMonitor()
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
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
    @State private var showDebugConsole = false
    @State private var showBackupConfirm = false
    @State private var hasTriggeredBackup = false
    @State private var showLiveChat = false
    @ObservedObject private var backupManager = BackupManager.shared
    @State private var cachedFiltered: [Conversation] = []
    @State private var cachedGrouped: [(directory: String, conversations: [Conversation])] = []
    @StateObject private var acpSessions = ACPSessionManager()
    @State private var selectedSource: SessionSource = .terminal
    @State private var selectedACPSession: ACPSession?
    
    enum SessionSource: String, CaseIterable {
        case terminal = "Terminal"
        case acp = "ACP"
    }
    
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
    
    private func updateFilteredConversations() {
        var convs = db.conversations
        
        if let folder = selectedFolder {
            convs = convs.filter { folder.conversationIds.contains($0.id) }
        }
        
        if !debouncedSearchText.isEmpty {
            convs = convs.filter { conv in
                let displayTitle = titles.getTitle(for: conv.id) ?? conv.title
                return displayTitle.localizedCaseInsensitiveContains(debouncedSearchText) ||
                conv.messages.contains { $0.content.localizedCaseInsensitiveContains(debouncedSearchText) }
            }
        }
        
        cachedFiltered = convs.sorted { lhs, rhs in
            let lhsPinned = titles.isPinned(lhs.id)
            let rhsPinned = titles.isPinned(rhs.id)
            if lhsPinned != rhsPinned { return lhsPinned }
            
            switch flatSortOrder {
            case .title:
                let lhsTitle = titles.getTitle(for: lhs.id) ?? lhs.title
                let rhsTitle = titles.getTitle(for: rhs.id) ?? rhs.title
                return lhsTitle.localizedCaseInsensitiveCompare(rhsTitle) == .orderedAscending
            case .latest: return lhs.updatedAt > rhs.updatedAt
            case .oldest: return lhs.updatedAt < rhs.updatedAt
            }
        }
        
        // Update grouped view
        let grouped = Dictionary(grouping: cachedFiltered) { $0.directory }
        let mapped = grouped.map { (directory: $0.key, conversations: $0.value.sorted { lhs, rhs in
            let lhsPinned = titles.isPinned(lhs.id)
            let rhsPinned = titles.isPinned(rhs.id)
            if lhsPinned != rhsPinned { return lhsPinned }
            return lhs.updatedAt > rhs.updatedAt
        }) }
        
        switch groupSortOrder {
        case .name:
            cachedGrouped = mapped.sorted { $0.directory < $1.directory }
        case .latestConversation:
            cachedGrouped = mapped.sorted { ($0.conversations.first?.updatedAt ?? .distantPast) > ($1.conversations.first?.updatedAt ?? .distantPast) }
        case .oldestConversation:
            cachedGrouped = mapped.sorted { ($0.conversations.last?.updatedAt ?? .distantFuture) < ($1.conversations.last?.updatedAt ?? .distantFuture) }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Source picker
                Picker("", selection: $selectedSource) {
                    ForEach(SessionSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                if selectedSource == .terminal {
                    terminalSessionsSidebar
                } else {
                    acpSessionsSidebar
                }
            }
            .navigationTitle("Kiro Chats")
            .background(themeManager.usesCustomColors ? themeManager.activeTheme.sidebar : Color.clear)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button { showLiveChat = true } label: {
                        Label("Live Chat", systemImage: "bolt.fill")
                    }
                    .help("Start a live chat with Kiro")
                    
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
                        Button { showDebugConsole = true } label: {
                            Label("Debug Console", systemImage: "terminal")
                        }
                        Divider()
                        Button { showBackupConfirm = true } label: {
                            Label("Backup Now", systemImage: "externaldrive.badge.plus")
                        }
                    } label: {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                    .help("View tools and metrics")
                    .popover(isPresented: $showPerformance) {
                        PerformancePopover(monitor: perf)
                    }
                    
                    Menu {
                        ForEach(ThemeMode.allCases) { mode in
                            Button {
                                themeManager.mode = mode
                                isDarkMode = (mode == .dark || mode == .kiro)
                            } label: {
                                Label(mode.rawValue, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        Label(themeManager.mode.rawValue, systemImage: themeManager.mode.icon)
                    }
                    .help("Change theme mode")
                    
                    Button {
                    withAnimation(.linear(duration: 0.5)) { rotationAngle += 360 }
                    perf.start("Load")
                    Task {
                        db.loadConversations()
                        try? await Task.sleep(for: .milliseconds(100))
                        await MainActor.run {
                            perf.end("Load")
                            perf.captureAppMetrics(conversations: db.conversations, titles: titles, bookmarks: bookmarks)
                        }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .rotationEffect(.degrees(rotationAngle))
                .help("Refresh conversation list")
                }
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
            VStack(spacing: 0) {
                // Main detail area
                Group {
                    if showLiveChat {
                        LiveChatView()
                            .toolbar {
                                ToolbarItem(placement: .automatic) {
                                    Button { showLiveChat = false } label: {
                                        Label("Back to Viewer", systemImage: "list.bullet")
                                    }
                                    .help("Return to conversation viewer")
                                }
                            }
                    } else if selectedSource == .acp, let session = selectedACPSession {
                let events = acpSessions.loadEvents(for: session.id)
                ACPSessionDetailView(session: session, events: events)
            } else if let selected = selectedConversation,
                       let conv = db.conversations.first(where: { $0.id == selected.id }) ?? selectedConversation {
                        ConversationDetailView(conversation: conv, selectedConversation: $selectedConversation)
                            .environmentObject(db)
                            .environmentObject(titles)
                            .id(conv.id)
                            .background(themeManager.usesCustomColors ? themeManager.activeTheme.background : Color.clear)
                    } else {
                        Text("Select a conversation")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(themeManager.usesCustomColors ? themeManager.activeTheme.background : Color.clear)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom debug drawer
                if showDebugConsole {
                    DebugDrawer(isShowing: $showDebugConsole)
                }
            }
        }
        .environmentObject(bookmarks)
        .preferredColorScheme(themeManager.colorScheme)
        .overlay(alignment: .bottomTrailing) {
            if let toast = backupManager.toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .font(.body)
                    Text(toast)
                        .font(.body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { backupManager.toastMessage = nil }
                    }
                }
            }
        }
        .animation(.easeInOut, value: backupManager.toastMessage)
        .onAppear {
            AppLogger.ui.info("App launched")
            perf.start("Load")
            db.loadConversations()
            acpSessions.loadSessions()
        }
        .onChange(of: selectedSource) { source in
            if source == .acp { acpSessions.loadSessions() }
        }
        .onChange(of: db.conversations) { _ in
            perf.end("Load")
            perf.captureAppMetrics(conversations: db.conversations, titles: titles, bookmarks: bookmarks)
            AppLogger.ui.info("Conversations updated: \(db.conversations.count) total")
            
            updateFilteredConversations()
            
            // Update selected conversation with fresh data
            if let selected = selectedConversation,
               let updated = db.conversations.first(where: { $0.id == selected.id }) {
                selectedConversation = updated
            }
            
            // Auto-backup after load (once per session)
            if !db.conversations.isEmpty && !hasTriggeredBackup {
                hasTriggeredBackup = true
                DispatchQueue.global(qos: .utility).async {
                    BackupManager.shared.backupIfNeeded()
                }
            }
            
            // Auto-generate titles for any new conversations
            if !db.conversations.isEmpty {
                titles.startAutoGeneration(for: db.conversations)
            }
        }
        .onChange(of: searchText) { newValue in
            searchDebounceTask?.cancel()
            if newValue.isEmpty {
                // Clear immediately
                debouncedSearchText = ""
                updateFilteredConversations()
            } else {
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    guard !Task.isCancelled else { return }
                    debouncedSearchText = newValue
                    updateFilteredConversations()
                }
            }
        }
        .onChange(of: flatSortOrder) { _ in updateFilteredConversations() }
        .onChange(of: groupSortOrder) { _ in updateFilteredConversations() }
        .onChange(of: selectedFolder?.id) { _ in updateFilteredConversations() }
        .onChange(of: titles.pinnedConversations) { _ in updateFilteredConversations() }
        .onChange(of: titles.titles.count) { _ in updateFilteredConversations() }
        .onChange(of: bookmarks.folders) { _ in updateFilteredConversations() }
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
        .alert("Backup Database?", isPresented: $showBackupConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Backup") {
                DispatchQueue.global(qos: .utility).async {
                    backupManager.performBackup()
                }
            }
        } message: {
            Text("Saves a snapshot of your current Kiro CLI database. Up to 3 backups are kept, oldest are removed automatically.")
        }
        .alert(backupManager.lastBackupStatus ?? "", isPresented: Binding(
            get: { backupManager.lastBackupStatus != nil },
            set: { if !$0 { backupManager.lastBackupStatus = nil } }
        )) {
            Button("OK") { backupManager.lastBackupStatus = nil }
        }
    }
    
    // MARK: - Terminal Sessions Sidebar
    
    private var terminalSessionsSidebar: some View {
        VStack(spacing: 0) {
            folderSection
            Divider()
            if isGroupedByWorkspace {
                List(selection: $selectedConversation) {
                    ForEach(cachedGrouped, id: \.directory) { group in
                        Section {
                            if expandedDirectories.contains(group.directory) {
                                ForEach(group.conversations) { conv in
                                    ConversationRow(conversation: conv, isSelected: selectedConversation?.id == conv.id, indented: true, bookmarks: bookmarks, titles: titles, onDelete: {
                                        if selectedConversation?.id == conv.id { selectedConversation = nil }
                                        db.deleteConversation(conv)
                                    }).tag(conv).listRowSeparator(group.conversations.count > 1 ? .visible : .hidden)
                                }
                            }
                        } header: {
                            Button {
                                withAnimation {
                                    if expandedDirectories.contains(group.directory) { expandedDirectories.remove(group.directory) }
                                    else { expandedDirectories.insert(group.directory) }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill").foregroundStyle(.blue).font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.directory.split(separator: "/").last.map(String.init) ?? group.directory)
                                            .font(.system(size: themeManager.folderFontSize, weight: .medium)).foregroundStyle(.primary)
                                        HStack(spacing: 8) {
                                            Text("\(group.conversations.count) chat\(group.conversations.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                                            if let latest = group.conversations.first {
                                                Text("Latest: \(latest.updatedAt, style: .relative)").font(.caption).foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: expandedDirectories.contains(group.directory) ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 3).padding(.horizontal, 4).padding(.trailing, 12).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .overlay { if db.isLoading && cachedFiltered.isEmpty { loadingView } else if cachedFiltered.isEmpty { emptyStateView } }
                .searchable(text: $searchText, prompt: "Search conversations").padding(.top, 4)
            } else {
                List(cachedFiltered, selection: $selectedConversation) { conv in
                    ConversationRow(conversation: conv, isSelected: selectedConversation?.id == conv.id, bookmarks: bookmarks, titles: titles, onDelete: {
                        if selectedConversation?.id == conv.id { selectedConversation = nil }
                        db.deleteConversation(conv)
                    }).tag(conv)
                }
                .overlay { if db.isLoading && cachedFiltered.isEmpty { loadingView } else if cachedFiltered.isEmpty { emptyStateView } }
                .searchable(text: $searchText, prompt: "Search conversations").padding(.top, 4)
            }
        }
    }
    
    // MARK: - ACP Sessions Sidebar
    
    private var acpSessionsSidebar: some View {
        List(acpSessions.sessions, selection: $selectedACPSession) { session in
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").font(.caption).foregroundStyle(.purple.opacity(0.6))
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.system(size: themeManager.conversationFontSize))
                        .lineLimit(2)
                    HStack {
                        Text("\(session.turnCount) turn\(session.turnCount == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.tertiary)
                        Spacer()
                        Text(session.updatedAt, style: .relative)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 4)
            .tag(session)
        }
        .overlay {
            if acpSessions.isLoading && acpSessions.sessions.isEmpty {
                loadingView
            } else if acpSessions.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("No ACP Sessions").font(.title3).fontWeight(.semibold)
                    Text("Start a live chat to create one").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search sessions")
        .padding(.top, 4)
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
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading conversations...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

