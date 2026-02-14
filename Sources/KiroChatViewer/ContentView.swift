import SwiftUI

struct ContentView: View {
    @StateObject private var db = DatabaseManager()
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""
    @AppStorage("appearance") private var appearance: String = "system"
    
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
                Menu {
                    Button(action: { appearance = "system" }) {
                        Label("System", systemImage: appearance == "system" ? "checkmark" : "")
                    }
                    Button(action: { appearance = "light" }) {
                        Label("Light", systemImage: appearance == "light" ? "checkmark" : "")
                    }
                    Button(action: { appearance = "dark" }) {
                        Label("Dark", systemImage: appearance == "dark" ? "checkmark" : "")
                    }
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
                
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
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
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
