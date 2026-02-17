import SwiftUI

struct ContentView: View {
    @StateObject private var db = DatabaseManager()
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var rotationAngle: Double = 0
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return db.conversations
        }
        return db.conversations.filter { conv in
            conv.title.localizedCaseInsensitiveContains(searchText) ||
            conv.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(filteredConversations, selection: $selectedConversation) { conv in
                ConversationRow(conversation: conv, onDelete: {
                    if selectedConversation?.id == conv.id {
                        selectedConversation = nil
                    }
                    db.deleteConversation(conv)
                })
                    .tag(conv)
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .navigationTitle("Kiro Chats")
            .toolbar {
                Toggle(isOn: $isDarkMode) {
                    Label(isDarkMode ? "Dark" : "Light", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                }
                .toggleStyle(.button)
                
                Button(action: {
                    // Animate rotation
                    withAnimation(.linear(duration: 0.5)) {
                        rotationAngle += 360
                    }
                    
                    // Just reload the list
                    Task {
                        db.loadConversations()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .rotationEffect(.degrees(rotationAngle))
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
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear(perform: db.loadConversations)
        .alert("Error", isPresented: .constant(db.error != nil)) {
            Button("OK") { db.error = nil }
        } message: {
            Text(db.error ?? "")
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .lineLimit(2)
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
    }
    
    private func resumeInTerminal(_ conversation: Conversation) {
        let dir = conversation.directory
        let script = "cd '\(dir)' && kiro-cli chat --resume-picker"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal"]
        try? process.run()
        
        // Small delay then send the command
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
