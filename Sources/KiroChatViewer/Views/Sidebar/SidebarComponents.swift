import SwiftUI

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
                        .foregroundStyle(.primary)
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
    let isSelected: Bool
    var indented: Bool = false
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
        HStack(spacing: 0) {
            if titles.isPinned(conversation.id) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3)
                    .padding(.vertical, 2)
                    .padding(.trailing, 6)
            }
            
            HStack(spacing: 8) {
                if titles.generatingId == conversation.id {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "terminal.fill")
                            .font(.caption)
                            .foregroundStyle(.purple.opacity(0.6))
                        if titles.isPinned(conversation.id) {
                            Image(systemName: "pin.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white, .blue)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if bookmarks.isBookmarked(conversationId: conversation.id) {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Text(displayTitle)
                            .font(.system(size: ThemeManager.shared.conversationFontSize))
                            .lineLimit(2)
                            .fontWeight(titles.isPinned(conversation.id) ? .semibold : .regular)
                    }
                    HStack {
                        Text("\(conversation.messages.count) msg\(conversation.messages.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(conversation.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            
                if isHovering {
                    conversationMenu
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .padding(.leading, indented ? 16 : 0)
        .contentShape(Rectangle())
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering && !isSelected ? Color.secondary.opacity(0.1) :
                      titles.isPinned(conversation.id) && !isSelected ? Color.blue.opacity(0.05) : Color.clear)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
        )
        .listRowSeparator(.visible)
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
    
    private var conversationMenu: some View {
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
            Button {
                titles.generateSingleTitle(for: conversation)
            } label: {
                Label("Generate Title", systemImage: "sparkles")
            }
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
                .foregroundColor(.gray)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .frame(width: 24)
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
