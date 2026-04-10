import SwiftUI

struct ScanResultView: View {
    let volume: Volume
    let items: [ScannedFile]
    let onClean: () -> Void
    let onCleanAndEject: () -> Void
    let onDismiss: () -> Void

    private var totalBytes: Int64 { items.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок
            HStack {
                Text(volume.name)
                    .font(.headline)
                Spacer()
                Text(volume.displayCapacity)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 12)

            Divider()

            // Список
            if items.isEmpty {
                Text("No junk files found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(items) { item in
                    HStack(spacing: 8) {
                        Image(systemName: iconName(for: item.url.lastPathComponent))
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Text(relativePath(item.url))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .layoutPriority(1)
            }

            Divider()

            // Футер
            HStack {
                Text(items.isEmpty ? "" : String(format: NSLocalizedString("%d files · %@", comment: ""),
                        items.count,
                        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)))
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
                Button("Close", action: onDismiss)
                Button("Clean") {
                    onClean()
                    onDismiss()
                }
                .disabled(items.isEmpty)
                .opacity(items.isEmpty ? 0 : 1)
                Button("Clean and Eject") {
                    onCleanAndEject()
                    onDismiss()
                }
                .disabled(items.isEmpty)
                .opacity(items.isEmpty ? 0 : 1)
            }
            .padding([.horizontal, .bottom], 16)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func relativePath(_ url: URL) -> String {
        var path = url.path
        if path.hasPrefix(volume.url.path) {
            path = String(path.dropFirst(volume.url.path.count))
        }
        return path.isEmpty ? "/" : path
    }

    private func iconName(for filename: String) -> String {
        switch filename {
        case ".DS_Store":           return "doc.badge.gearshape"
        case ".Trashes":            return "trash"
        case ".Spotlight-V100":     return "magnifyingglass"
        case ".fseventsd":          return "waveform"
        case ".TemporaryItems":     return "clock"
        case ".DocumentRevisions-V100": return "clock.arrow.circlepath"
        default:
            if filename.hasPrefix("._") { return "doc.on.doc" }
            return "doc"
        }
    }
}
