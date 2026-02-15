import SwiftUI

struct ContentView: View {
    @StateObject private var db = DatabaseManager()
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
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
                ConversationRow(conversation: conv)
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
                    db.loadConversations()
                    // Force refresh selected conversation
                    if let selected = selectedConversation {
                        selectedConversation = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            selectedConversation = db.conversations.first { $0.id == selected.id }
                        }
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .rotationEffect(.degrees(db.isLoading ? 360 : 0))
                .animation(db.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: db.isLoading)
            }
        } detail: {
            if let conv = selectedConversation {
                ConversationDetailView(conversation: conv)
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
    
    var body: some View {
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
        .padding(.vertical, 4)
    }
}
