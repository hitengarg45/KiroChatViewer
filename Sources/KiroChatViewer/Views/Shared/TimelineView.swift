import SwiftUI

struct TimelineView: View {
    let conversations: [Conversation]
    @Environment(\.dismiss) private var dismiss
    
    private var timelineData: [(date: Date, conversations: [Conversation])] {
        let grouped = Dictionary(grouping: conversations) { conv in
            Calendar.current.startOfDay(for: conv.createdAt)
        }
        return grouped.map { (date: $0.key, conversations: $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(timelineData, id: \.date) { day in
                        VStack(alignment: .leading, spacing: 12) {
                            // Date header
                            HStack {
                                Text(day.date, style: .date)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(day.conversations.count) conversation\(day.conversations.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Timeline entries
                            ForEach(day.conversations) { conv in
                                TimelineEntry(conversation: conv)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Timeline")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct TimelineEntry: View {
    let conversation: Conversation
    
    private var duration: String {
        let interval = conversation.updatedAt.timeIntervalSince(conversation.createdAt)
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 2)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(conversation.createdAt, style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(conversation.title)
                    .font(.body)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "folder")
                        .font(.caption2)
                    Text(conversation.directory.split(separator: "/").last.map(String.init) ?? conversation.directory)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                
                Text("\(conversation.messageCount) message\(conversation.messageCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.trailing)
        }
        .padding(.leading)
    }
}
