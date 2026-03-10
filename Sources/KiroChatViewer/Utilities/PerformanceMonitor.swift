import SwiftUI

class PerformanceMonitor: ObservableObject {
    @Published var metrics: [String: String] = [:]
    private var timers: [String: Date] = [:]
    
    func start(_ key: String) {
        timers[key] = Date()
    }
    
    func end(_ key: String) {
        guard let start = timers[key] else { return }
        let duration = Date().timeIntervalSince(start)
        metrics[key] = String(format: "%.0fms", duration * 1000)
        timers.removeValue(forKey: key)
    }
    
    func record(_ key: String, _ value: String) {
        metrics[key] = value
    }
}

struct PerformancePopover: View {
    @ObservedObject var monitor: PerformanceMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
            
            Divider()
            
            if monitor.metrics.isEmpty {
                Text("No metrics yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(monitor.metrics.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Text(value)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 200)
    }
}

