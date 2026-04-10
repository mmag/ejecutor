import Foundation
import AppKit
import DiskArbitration

struct Volume {
    let name: String
    let url: URL
    let totalCapacity: Int64

    var displayCapacity: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
    }
}

enum VolumeManager {
    static func externalVolumes() -> [Volume] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeIsInternalKey,
            .volumeIsLocalKey,
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: []
        ) else { return [] }

        guard let session = DASessionCreate(kCFAllocatorDefault) else { return [] }

        return urls.compactMap { url -> Volume? in
            guard let res = try? url.resourceValues(forKeys: keys) else { return nil }

            let isInternal = res.volumeIsInternal ?? true
            let isLocal    = res.volumeIsLocal    ?? false

            guard isLocal, !isInternal else { return nil }
            guard isPhysicalDevice(url: url, session: session) else { return nil }

            return Volume(
                name: res.volumeName ?? url.lastPathComponent,
                url: url,
                totalCapacity: Int64(res.volumeTotalCapacity ?? 0)
            )
        }
    }

    // Физический накопитель имеет device protocol (USB Mass Storage, SCSI и т.д.)
    // Disk images (.dmg) этого ключа не имеют
    private static func isPhysicalDevice(url: URL, session: DASession) -> Bool {
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
              let desc = DADiskCopyDescription(disk) as? [String: Any] else { return false }
        return desc[kDADiskDescriptionDeviceProtocolKey as String] != nil
    }

    static func eject(_ volume: Volume) throws {
        try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
    }
}
