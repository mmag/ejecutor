import Foundation
import Darwin

struct CleanupSettings {
    var removeDSStore              = true
    var removeAppleDouble          = true   // файлы ._*
    var appleDoubleOnlyIfPaired    = true   // удалять ._* только если рядом есть парный файл
    var removeTrashes              = true
    var removeSpotlight            = true   // .Spotlight-V100
    var removeFSEvents             = true   // .fseventsd
    var removeTemporaryItems       = true
    var removeDocumentRevisions    = true   // .DocumentRevisions-V100
}

struct ScannedFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
}

struct CleanupResult {
    var deletedCount = 0
    var freedBytes: Int64 = 0
    var errors: [String] = []
}

private struct PendingDelete {
    let url: URL
    let size: Int64
}

enum CleanupManager {
    static func scan(volume: Volume, settings: CleanupSettings) -> [ScannedFile] {
        let candidates = findCandidates(in: volume.url, settings: settings)
        let fm = FileManager.default
        return candidates.map { ScannedFile(url: $0, size: diskSize(of: $0, fm: fm)) }
    }

    static func clean(volume: Volume, settings: CleanupSettings) -> CleanupResult {
        var result = CleanupResult()
        let fm = FileManager.default
        let candidates = findCandidates(in: volume.url, settings: settings)

        var needsPrivileges: [PendingDelete] = []

        for url in candidates {
            let size = diskSize(of: url, fm: fm)
            do {
                try fm.removeItem(at: url)
                result.deletedCount += 1
                result.freedBytes += size
            } catch let error as NSError {
                if isPermissionError(error) {
                    needsPrivileges.append(PendingDelete(url: url, size: size))
                } else {
                    result.errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        if !needsPrivileges.isEmpty {
            if deleteWithElevatedPrivileges(needsPrivileges.map(\.url)) {
                for item in needsPrivileges {
                    result.deletedCount += 1
                    result.freedBytes += item.size
                }
            } else {
                for item in needsPrivileges {
                    result.errors.append("\(item.url.lastPathComponent): \(NSLocalizedString("no permissions", comment: ""))")
                }
            }
        }

        return result
    }

    // MARK: - Candidate search

    // FileManager.enumerator скрывает ._* файлы (AppleDouble) через VFS-слой macOS —
    // они невидимы для высокоуровневых API. POSIX opendir/readdir работает ниже этого слоя.
    private static func findCandidates(in volumeURL: URL, settings: CleanupSettings) -> [URL] {
        var results: [URL] = []
        posixScan(volumeURL, volumeURL: volumeURL, settings: settings, into: &results)
        return results
    }

    private static func posixScan(
        _ dir: URL, volumeURL: URL, settings: CleanupSettings, into results: inout [URL]
    ) {
        guard let dp = opendir(dir.path) else { return }
        defer { closedir(dp) }

        while let entry = readdir(dp) {
            let name = withUnsafePointer(to: entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(NAME_MAX) + 1) {
                    String(cString: $0)
                }
            }
            guard name != ".", name != ".." else { continue }

            let isDir: Bool
            switch entry.pointee.d_type {
            case UInt8(DT_DIR):
                isDir = true
            case UInt8(DT_UNKNOWN):
                // Некоторые ФС не заполняют d_type — проверяем через stat
                var st = stat()
                isDir = stat(dir.appendingPathComponent(name).path, &st) == 0
                    && (st.st_mode & S_IFMT) == S_IFDIR
            default:
                isDir = false
            }

            let url = dir.appendingPathComponent(name, isDirectory: isDir)

            if shouldDelete(url, volumeURL: volumeURL, settings: settings) {
                results.append(url)
                // Найдено — не заходим внутрь
            } else if isDir {
                // Не заходим в пакеты (.app, .bundle и т.д.)
                let ext = url.pathExtension.lowercased()
                guard !["app", "bundle", "framework", "plugin", "kext"].contains(ext) else { continue }
                posixScan(url, volumeURL: volumeURL, settings: settings, into: &results)
            }
        }
    }

    // MARK: - Deletion rules

    // .DS_Store и ._* — на любой глубине
    // Системные директории — только в корне тома
    private static func shouldDelete(_ url: URL, volumeURL: URL, settings: CleanupSettings) -> Bool {
        let name = url.lastPathComponent
        let isAtRoot = url.deletingLastPathComponent().standardized.path == normalizedPath(volumeURL)

        if settings.removeDSStore && name == ".DS_Store"      { return true }
        if settings.removeAppleDouble && name.hasPrefix("._") {
            if settings.appleDoubleOnlyIfPaired {
                let paired = url.deletingLastPathComponent().appendingPathComponent(String(name.dropFirst(2)))
                return FileManager.default.fileExists(atPath: paired.path)
            }
            return true
        }

        guard isAtRoot else { return false }

        if settings.removeTrashes && name == ".Trashes"                          { return true }
        if settings.removeSpotlight && name == ".Spotlight-V100"                 { return true }
        if settings.removeFSEvents && name == ".fseventsd"                       { return true }
        if settings.removeTemporaryItems && name == ".TemporaryItems"            { return true }
        if settings.removeDocumentRevisions && name == ".DocumentRevisions-V100" { return true }
        return false
    }

    private static func normalizedPath(_ url: URL) -> String {
        var path = url.standardized.path
        if path.hasSuffix("/") { path = String(path.dropLast()) }
        return path
    }

    // MARK: - Size

    private static func diskSize(of url: URL, fm: FileManager) -> Int64 {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        guard isDir else {
            return Int64((try? url.resourceValues(forKeys: [.totalFileSizeKey]))?.totalFileSize ?? 0)
        }
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileSizeKey], options: []) {
            for case let fileURL as URL in enumerator {
                total += Int64((try? fileURL.resourceValues(forKeys: [.totalFileSizeKey]))?.totalFileSize ?? 0)
            }
        }
        return total
    }

    // MARK: - Elevated privileges

    private static func isPermissionError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == 513 { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain && underlying.code == Int(EPERM) { return true }
        return false
    }

    private static func deleteWithElevatedPrivileges(_ urls: [URL]) -> Bool {
        var commands: [String] = []

        let spotlight = urls.filter { $0.lastPathComponent == ".Spotlight-V100" }
        let rest      = urls.filter { $0.lastPathComponent != ".Spotlight-V100" }

        for url in spotlight {
            let path = shellEscape(url.path)
            commands.append("chflags -R nouchg,noschg \(path) 2>/dev/null; /bin/rm -rf \(path)")
        }
        if !rest.isEmpty {
            let args = rest.map { shellEscape($0.path) }.joined(separator: " ")
            commands.append("/bin/rm -rf \(args)")
        }

        let shellCmd = commands.joined(separator: "; ")
        let asEscaped = shellCmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(asEscaped)\" with administrator privileges"

        return runOsascript(script)
    }

    private static func runOsascript(_ script: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("[Ejecutor] osascript error: \(error)")
            return false
        }
    }

    private static func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
