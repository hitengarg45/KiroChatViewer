import Foundation
import SQLite

class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    @Published var lastBackupStatus: String?
    @Published var toastMessage: String?
    @Published var backups: [BackupInfo] = []
    
    private let maxBackups = 3
    private let sourceURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3")
    private let backupDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KiroChatViewer/backups")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    struct BackupInfo: Identifiable {
        let id: String
        let url: URL
        let date: Date
        let size: Int64
        
        var sizeString: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    init() { refreshBackupList() }
    
    var latestBackupURL: URL? { existingBackups().first }
    
    // MARK: - Backup
    
    func backupIfNeeded() {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        
        let list = existingBackups()
        if let latest = list.first,
           let modified = try? latest.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           Date().timeIntervalSince(modified) < 3600 {
            AppLogger.db.info("Backup skipped - last backup less than 1 hour ago")
            return
        }
        
        performBackup(silent: true)
    }
    
    func performBackup(silent: Bool = false) {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let dest = backupDir.appendingPathComponent("data-\(timestamp).sqlite3")
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            AppLogger.db.info("Database backed up to: \(dest.lastPathComponent)")
            pruneOldBackups()
            DispatchQueue.main.async {
                self.refreshBackupList()
                if silent {
                    self.toastMessage = "Backed up recent chats"
                } else {
                    self.lastBackupStatus = "Backup successful"
                }
            }
        } catch {
            AppLogger.db.error("Backup failed: \(error.localizedDescription)")
            if !silent {
                DispatchQueue.main.async {
                    self.lastBackupStatus = "Backup failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Backup List
    
    func refreshBackupList() {
        backups = existingBackups().map { url in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let date = attrs?[.modificationDate] as? Date ?? .distantPast
            let size = attrs?[.size] as? Int64 ?? 0
            return BackupInfo(id: url.lastPathComponent, url: url, date: date, size: size)
        }
    }
    
    private func existingBackups() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "sqlite3" }
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return aDate > bDate
            }) ?? []
    }
    
    private func pruneOldBackups() {
        let list = existingBackups()
        guard list.count > maxBackups else { return }
        for old in list.dropFirst(maxBackups) {
            try? FileManager.default.removeItem(at: old)
            AppLogger.db.info("Pruned old backup: \(old.lastPathComponent)")
        }
    }
}
