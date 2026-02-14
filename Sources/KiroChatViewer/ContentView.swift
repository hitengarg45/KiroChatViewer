import SwiftUI

struct ContentView: View {
    @StateObject private var db = DatabaseManager()
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""
    
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
                Button(action: db.loadConversations) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } detail: {
            if let conv = selectedConversation {
                ConversationDetailView(conversation: conv)
            } else {
                Text("Select a conversation")
                    .foregroundStyle(.secondary)
            }
        }
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
