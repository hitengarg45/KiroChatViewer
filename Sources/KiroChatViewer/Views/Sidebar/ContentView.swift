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
    @State private var showSettingsPopover = false
    @State private var hasTriggeredBackup = false
    @State private var showLiveChat = false
    @ObservedObject private var backupManager = BackupManager.shared
    @ObservedObject private var terminalManager = TerminalSessionManager.shared
    @State private var cachedFiltered: [Conversation] = []
    @State private var cachedGrouped: [(directory: String, conversations: [Conversation])] = []
    @StateObject private var acpSessions = ACPSessionManager()
    @State private var selectedACPSession: ACPSession?
    
    
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
    
    private func updateWindowAppearance() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }
            if themeManager.usesCustomColors {
                window.backgroundColor = NSColor(themeManager.activeTheme.background)
            } else {
                window.backgroundColor = NSColor.underPageBackgroundColor
            }
            window.titlebarAppearsTransparent = true
        }
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
    
    @State private var sidebarWidth: CGFloat = 450
    @State private var isDraggingSidebar = false
    @State private var isHoveringResizer = false
    @State private var hoverTask: Task<Void, Never>?
    
    @State private var sidebarVisible = true
    
    enum ActivityTab: Hashable {
        case conversations, liveChat
    }
    @State private var activeTab: ActivityTab = .conversations
    
    var body: some View {
        bodyContent
            .onChange(of: flatSortOrder) { _ in updateFilteredConversations() }
            .onChange(of: groupSortOrder) { _ in updateFilteredConversations() }
            .onChange(of: selectedFolder?.id) { _ in updateFilteredConversations() }
            .onChange(of: titles.pinnedConversations) { _ in updateFilteredConversations() }
            .onChange(of: titles.titles.count) { _ in updateFilteredConversations() }
            .onChange(of: bookmarks.folders) { _ in updateFilteredConversations() }
            .alert("Error", isPresented: .constant(db.error != nil)) { Button("OK") { db.error = nil } } message: { Text(db.error ?? "") }
            .sheet(isPresented: $showNewFolderSheet) { newFolderSheet }
            .sheet(isPresented: $showTimeline) { TimelineView(conversations: db.conversations) }
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in openNewChat(result) }
            .alert("Backup Database?", isPresented: $showBackupConfirm) { Button("Cancel", role: .cancel) {}; Button("Backup") { DispatchQueue.global(qos: .utility).async { backupManager.performBackup() } } } message: { Text("Saves a snapshot.") }
            .alert(backupManager.lastBackupStatus ?? "", isPresented: Binding(get: { backupManager.lastBackupStatus != nil }, set: { if !$0 { backupManager.lastBackupStatus = nil } })) { Button("OK") { backupManager.lastBackupStatus = nil } }
    }
    
    private var bodyContent: some View {
        mainLayout
            .background(themeManager.usesCustomColors ? themeManager.activeTheme.background : Color(nsColor: .underPageBackgroundColor))
            .overlay(alignment: .bottomTrailing) { toastOverlay }
            .environmentObject(bookmarks)
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search conversations")
            .preferredColorScheme(themeManager.colorScheme)
            .onAppear { onLaunch() }
            .onChange(of: themeManager.themeMode) { _ in updateWindowAppearance() }
            .onChange(of: themeManager.activeCustomThemeId) { _ in updateWindowAppearance() }
            .onChange(of: db.conversations) { _ in onConversationsChanged() }
            .onChange(of: searchText) { newValue in onSearchChanged(newValue) }
    }
    
    private func onLaunch() {
        AppLogger.ui.info("App launched"); perf.start("Load"); db.loadConversations(); acpSessions.loadSessions(); updateWindowAppearance()
    }
    
    private var newFolderSheet: some View {
        NewFolderSheet(name: $newFolderName) { if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty { bookmarks.createFolder(name: newFolderName.trimmingCharacters(in: .whitespaces)) }; newFolderName = "" }
    }
    
    private func openNewChat(_ result: Result<URL, Error>) {
        if case .success(let url) = result { let s = "tell application \"Terminal\"\nactivate\ndo script \"cd '\(url.path)' && kiro-cli chat\"\nend tell"; let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); p.arguments = ["-e", s]; try? p.run() }
    }
    
    private var mainLayout: some View {
        VStack(spacing: 2) {
            mainContent
            statusBar
        }
    }
    
    private var mainContent: some View {
        HStack(spacing: 0) {
            // Activity Bar
            activityBar
            
            // Sidebar
            if sidebarVisible {
                sidebarPanel
                    .frame(width: sidebarWidth)
                
                // Resize handle — invisible until hovered/dragged
                Rectangle()
                .fill(isDraggingSidebar ? Color.accentColor : isHoveringResizer ? Color.secondary.opacity(0.4) : Color.clear)
                .frame(width: isDraggingSidebar || isHoveringResizer ? 3 : 1)
                .contentShape(Rectangle().size(width: 12, height: 10000))
                .padding(.horizontal, 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDraggingSidebar = true
                            sidebarWidth = max(220, sidebarWidth + value.translation.width)
                        }
                        .onEnded { _ in isDraggingSidebar = false }
                )
                .onHover { h in
                    if h {
                        NSCursor.resizeLeftRight.push()
                        hoverTask = Task {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            guard !Task.isCancelled else { return }
                            withAnimation(.easeIn(duration: 0.15)) { isHoveringResizer = true }
                        }
                    } else {
                        NSCursor.pop()
                        hoverTask?.cancel()
                        withAnimation(.easeOut(duration: 0.1)) { isHoveringResizer = false }
                    }
                }
            }
            
            if !sidebarVisible {
                Spacer().frame(width: 4)
            }
            
            // Detail + Debug/Terminal Panel
            VStack(spacing: 4) {
                detailArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.usesCustomColors ? themeManager.activeTheme.sidebar : Color(nsColor: .textBackgroundColor))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Terminal panel (outside detail view)
                if let conv = selectedConversation, terminalManager.isActive(conv.id) {
                    terminalPanelView(for: conv)
                }
                
                if showDebugConsole {
                    DebugDrawer(isShowing: $showDebugConsole)
                }
            }
            .padding(.trailing, 4).padding(.vertical, 2)
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 9))
                Text("\(db.conversations.count) conversations").font(.system(size: 10))
            }.foregroundStyle(.secondary)
            
            if let loadTime = perf.metrics["Load"] {
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 9))
                    Text("Load: \(loadTime)").font(.system(size: 10, design: .monospaced))
                }.foregroundStyle(.secondary)
            }
            
            if let totalMsgs = perf.metrics["Total Messages"] {
                HStack(spacing: 4) {
                    Image(systemName: "message").font(.system(size: 9))
                    Text("\(totalMsgs) msgs").font(.system(size: 10))
                }.foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: themeManager.mode.icon).font(.system(size: 9))
                Text(themeManager.mode.rawValue).font(.system(size: 10))
            }.foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 3)
        .padding(.horizontal, 4).padding(.bottom, 2)
    }
    
    private var toastOverlay: some View {
        Group {
            if let toast = backupManager.toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill.badge.checkmark").font(.body)
                    Text(toast).font(.body)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.ultraThinMaterial).cornerRadius(8).shadow(radius: 4)
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
    }
    
    // Modifiers are in body
    
    private func onConversationsChanged() {
        perf.end("Load")
        perf.captureAppMetrics(conversations: db.conversations, titles: titles, bookmarks: bookmarks)
        AppLogger.ui.info("Conversations updated: \(db.conversations.count) total")
        updateFilteredConversations()
        if let selected = selectedConversation, let updated = db.conversations.first(where: { $0.id == selected.id }) { selectedConversation = updated }
        if !db.conversations.isEmpty && !hasTriggeredBackup { hasTriggeredBackup = true; DispatchQueue.global(qos: .utility).async { BackupManager.shared.backupIfNeeded() } }
        if !db.conversations.isEmpty { titles.startAutoGeneration(for: db.conversations) }
    }
    
    private func onSearchChanged(_ newValue: String) {
        searchDebounceTask?.cancel()
        if newValue.isEmpty { debouncedSearchText = ""; updateFilteredConversations() }
        else { searchDebounceTask = Task { try? await Task.sleep(nanoseconds: 300_000_000); guard !Task.isCancelled else { return }; debouncedSearchText = newValue; updateFilteredConversations() } }
    }
    
    // MARK: - Activity Bar
    
    private var activityBar: some View {
        VStack(spacing: 10) {
            activityButton(.conversations, icon: "bubble.left.and.bubble.right", label: "Chats")
            activityButton(.liveChat, icon: "bolt.fill", label: "Live Chat")
            
            Spacer()
            
            Button { showDebugConsole.toggle() } label: {
                Image(systemName: "rectangle.bottomhalf.inset.filled")
                    .font(.system(size: 14))
                    .foregroundStyle(showDebugConsole ? .purple : .secondary)
                    .frame(width: 36, height: 30)
            }
            .buttonStyle(ActivityButtonStyle(isActive: showDebugConsole))
            .help("Debug Console")
            
            Button { showSettingsPopover.toggle() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundStyle(showSettingsPopover ? .purple : .secondary)
                    .frame(width: 36, height: 30)
            }
            .buttonStyle(ActivityButtonStyle(isActive: showSettingsPopover))
            .help("Settings")
            .popover(isPresented: $showSettingsPopover, arrowEdge: .leading) {
                settingsPopoverContent
            }
        }
        .padding(.vertical, 8)
        .frame(width: 44)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 8, bottomLeadingRadius: 8,
                bottomTrailingRadius: sidebarVisible ? 0 : 8, topTrailingRadius: sidebarVisible ? 0 : 8
            )
            .fill(themeManager.usesCustomColors ? themeManager.activeTheme.sidebar : Color(nsColor: .controlBackgroundColor))
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 8, bottomLeadingRadius: 8,
                bottomTrailingRadius: sidebarVisible ? 0 : 8, topTrailingRadius: sidebarVisible ? 0 : 8
            )
        )
        .padding(.leading, 4).padding(.vertical, 2)
        .overlay(alignment: .trailing) {
            if sidebarVisible {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1)
                    .padding(.vertical, 2)
            }
        }
    }
    
    private func activityButton(_ tab: ActivityTab, icon: String, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if activeTab == tab {
                    sidebarVisible.toggle()
                } else {
                    activeTab = tab
                    sidebarVisible = true
                    showLiveChat = (tab == .liveChat)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(activeTab == tab ? .purple : .secondary)
                .frame(width: 36, height: 30)
                .background(activeTab == tab ? Color.purple.opacity(0.1) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(ActivityButtonStyle(isActive: activeTab == tab))
        .help(label)
    }
    
    // MARK: - Sidebar Panel
    
    private var sidebarPanel: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack(spacing: 8) {
                Text(sidebarTitle).font(.system(size: 12, weight: .semibold))
                Spacer()
                
                if activeTab == .conversations {
                    Button { showFolderPicker = true } label: {
                        Image(systemName: "plus").font(.system(size: 13))
                    }.buttonStyle(.plain).foregroundStyle(.primary.opacity(0.6)).help("New Chat")
                    
                    Menu {
                        Toggle(isOn: $isGroupedByWorkspace) { Label("Group by Workspace", systemImage: "folder.fill") }
                        Divider()
                        if isGroupedByWorkspace {
                            Picker("Sort", selection: $groupSortOrder) {
                                Text("Name").tag(GroupSortOrder.name)
                                Text("Latest").tag(GroupSortOrder.latestConversation)
                                Text("Oldest").tag(GroupSortOrder.oldestConversation)
                            }
                        } else {
                            Picker("Sort", selection: $flatSortOrder) {
                                Text("Title").tag(FlatSortOrder.title)
                                Text("Latest").tag(FlatSortOrder.latest)
                                Text("Oldest").tag(FlatSortOrder.oldest)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 13))
                    }.menuStyle(.borderlessButton).frame(width: 20).help("Filter & Sort")
                    
                    Button {
                        withAnimation(.linear(duration: 0.5)) { rotationAngle += 360 }
                        perf.start("Load"); db.loadConversations()
                        acpSessions.loadSessions()
                    } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13))
                    }
                    .buttonStyle(.plain).foregroundStyle(.primary.opacity(0.6))
                    .rotationEffect(.degrees(rotationAngle)).help("Refresh")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            
            Divider()
            
            switch activeTab {
            case .conversations:
                conversationsSidebarContent
            case .liveChat:
                liveChatSidebarContent
            }
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 8, topTrailingRadius: 8
            )
            .fill(themeManager.usesCustomColors ? themeManager.activeTheme.sidebar : Color(nsColor: .controlBackgroundColor))
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 8, topTrailingRadius: 8
            )
        )
        .padding(.vertical, 2)
    }
    
    private var sidebarTitle: String {
        switch activeTab {
        case .conversations: return "Conversations"
        case .liveChat: return "Live Chat"
        }
    }
    
    // MARK: - Conversations Sidebar Content
    
    private var conversationsSidebarContent: some View {
        VStack(spacing: 0) {
            // Folders
            folderSection
            
            Divider()
            
            terminalSessionsSidebar
        }
    }
    
    // MARK: - Live Chat Sidebar Content
    
    private var liveChatSidebarContent: some View {
        VStack(spacing: 0) {
            acpSessionsSidebar
        }
    }
    
    // MARK: - Detail Area
    
    @State private var terminalHeight: CGFloat = 300
    @State private var isDraggingTerminal = false
    @State private var isHoveringTerminalResizer = false
    @State private var terminalHoverTask: Task<Void, Never>?
    
    private func terminalPanelView(for conv: Conversation) -> some View {
        VStack(spacing: 0) {
            if !terminalManager.isMinimized(conv.id) {
                Rectangle()
                    .fill(isDraggingTerminal ? Color.purple : isHoveringTerminalResizer ? Color.secondary.opacity(0.4) : Color.clear)
                    .frame(height: isDraggingTerminal || isHoveringTerminalResizer ? 3 : 1)
                    .contentShape(Rectangle().size(width: 10000, height: 12))
                    .gesture(DragGesture()
                        .onChanged { v in isDraggingTerminal = true; terminalHeight = max(150, min(600, terminalHeight - v.translation.height)) }
                        .onEnded { _ in isDraggingTerminal = false })
                    .onHover { h in
                        if h {
                            NSCursor.resizeUpDown.push()
                            terminalHoverTask = Task {
                                try? await Task.sleep(nanoseconds: 800_000_000)
                                guard !Task.isCancelled else { return }
                                withAnimation(.easeIn(duration: 0.15)) { isHoveringTerminalResizer = true }
                            }
                        } else {
                            NSCursor.pop()
                            terminalHoverTask?.cancel()
                            withAnimation(.easeOut(duration: 0.1)) { isHoveringTerminalResizer = false }
                        }
                    }
            }
            
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill").font(.system(size: 11)).foregroundStyle(.purple)
                    Text("Terminal").font(.system(size: 11, weight: .semibold))
                    Text(conv.directory.split(separator: "/").last.map(String.init) ?? "")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button { withAnimation(.easeInOut(duration: 0.2)) { terminalManager.toggleMinimize(conv.id) } } label: {
                        Image(systemName: terminalManager.isMinimized(conv.id) ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                    if !terminalManager.isMinimized(conv.id) {
                        Button { withAnimation(.easeInOut(duration: 0.2)) { terminalHeight = terminalHeight < 400 ? 500 : 250 } } label: {
                            Image(systemName: terminalHeight < 400 ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left").font(.system(size: 9))
                        }.buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    Button { terminalManager.closeSession(id: conv.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                
                if !terminalManager.isMinimized(conv.id) {
                    Divider()
                    if let tv = terminalManager.terminalView(for: conv.id) {
                        EmbeddedTerminalView(terminalView: tv)
                            .frame(height: terminalHeight)
                            .padding(.leading, 4)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(themeManager.usesCustomColors ? themeManager.activeTheme.sidebar : Color(nsColor: .textBackgroundColor)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
        }
    }
    
    private var detailArea: some View {
        Group {
            if activeTab == .liveChat, let session = selectedACPSession {
                ACPSessionDetailView(session: session, events: acpSessions.loadEvents(for: session.id))
            } else if showLiveChat {
                LiveChatView()
            } else if let selected = selectedConversation,
                      let conv = db.conversations.first(where: { $0.id == selected.id }) ?? selectedConversation {
                ConversationDetailView(conversation: conv, selectedConversation: $selectedConversation)
                    .environmentObject(db).environmentObject(titles)
                    .id(conv.id)
                    .background(themeManager.usesCustomColors ? themeManager.activeTheme.sidebar : Color.clear)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 56)).foregroundStyle(.purple.opacity(0.2))
                    Text("Select a conversation").font(.title3).foregroundStyle(.secondary)
                    Text("Choose from the sidebar or start a new chat").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.usesCustomColors ? themeManager.activeTheme.sidebar : Color.clear)
            }
        }
    }
    
    private var settingsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings").font(.system(size: 12, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            
            // Theme quick switch
            Menu {
                ForEach(ThemeMode.allCases) { mode in
                    Button {
                        themeManager.mode = mode
                        updateWindowAppearance()
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                settingsRowLabel(icon: "circle.lefthalf.filled", color: .blue, title: "Theme", detail: themeManager.mode.rawValue)
            }.buttonStyle(.plain)
            
            Divider().padding(.horizontal, 8)
            
            settingsRow(icon: "clock", color: .orange, title: "Timeline") {
                showTimeline = true; showSettingsPopover = false
            }
            settingsRow(icon: "speedometer", color: .green, title: "Performance") {
                showPerformance = true; showSettingsPopover = false
            }
            
            Divider().padding(.horizontal, 8)
            
            settingsRow(icon: "externaldrive.badge.plus", color: .orange, title: "Backup Now") {
                showBackupConfirm = true; showSettingsPopover = false
            }
            
            Divider().padding(.horizontal, 8)
            
            settingsRow(icon: "gearshape.2", color: .secondary, title: "All Settings...") {
                if #available(macOS 14.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                showSettingsPopover = false
            }
        }
        .frame(width: 220)
        .popover(isPresented: $showPerformance) { PerformancePopover(monitor: perf) }
    }
    
    private func settingsRow(icon: String, color: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsRowLabel(icon: icon, color: color, title: title, detail: nil)
        }
        .buttonStyle(.plain)
    }
    
    private func settingsRowLabel(icon: String, color: Color, title: String, detail: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color).cornerRadius(4)
            Text(title).font(.system(size: 12))
            Spacer()
            if let detail {
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    
    // MARK: - Terminal Sessions Sidebar
    
    private var terminalSessionsSidebar: some View {
        VStack(spacing: 0) {
            if isGroupedByWorkspace {
                List(selection: $selectedConversation) {
                    ForEach(cachedGrouped, id: \.directory) { group in
                        Section {
                            if expandedDirectories.contains(group.directory) {
                                ForEach(group.conversations) { conv in
                                    ConversationRow(conversation: conv, isSelected: selectedConversation?.id == conv.id, indented: true, bookmarks: bookmarks, titles: titles, onDelete: {
                                        if selectedConversation?.id == conv.id { selectedConversation = nil }
                                        TerminalSessionManager.shared.closeSession(id: conv.id)
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
                                                Text("Latest: \(latest.updatedAt, style: .relative)").font(.caption).foregroundStyle(.secondary)
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
                .scrollContentBackground(.hidden)
                .padding(.top, 4)
            } else {
                List(cachedFiltered, selection: $selectedConversation) { conv in
                    ConversationRow(conversation: conv, isSelected: selectedConversation?.id == conv.id, bookmarks: bookmarks, titles: titles, onDelete: {
                        if selectedConversation?.id == conv.id { selectedConversation = nil }
                        TerminalSessionManager.shared.closeSession(id: conv.id)
                        db.deleteConversation(conv)
                    }).tag(conv)
                }
                .overlay { if db.isLoading && cachedFiltered.isEmpty { loadingView } else if cachedFiltered.isEmpty { emptyStateView } }
                .scrollContentBackground(.hidden)
                .padding(.top, 4)
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
                            .font(.caption).foregroundStyle(.secondary)
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
        .scrollContentBackground(.hidden)
        
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


// MARK: - Activity Button Style

private struct ActivityButtonStyle: ButtonStyle {
    let isActive: Bool
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                isActive ? Color.purple.opacity(0.15) :
                isHovering ? Color.purple.opacity(0.08) :
                Color.clear
            )
            .cornerRadius(6)
            .onHover { isHovering = $0 }
    }
}
