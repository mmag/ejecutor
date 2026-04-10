import Cocoa
import UserNotifications
import Darwin

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        requestNotificationPermission()
        checkFullDiskAccess()
        statusMenuController = StatusMenuController()
    }

    private func hasFullDiskAccess() -> Bool {
        let path = "/Library/Application Support/com.apple.TCC/TCC.db"
        let fd = Darwin.open(path, O_RDONLY)
        guard fd != -1 else { return false }
        Darwin.close(fd)
        return true
    }

    private func checkFullDiskAccess() {
        guard !hasFullDiskAccess() else { return }
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Full Disk Access Required", comment: "")
            alert.informativeText = NSLocalizedString("Full Disk Access Required body", comment: "")
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("Open Settings", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
        }
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert]) { _, _ in }
            case .denied:
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("Notifications Disabled", comment: "")
                    alert.informativeText = NSLocalizedString("Notifications Disabled body", comment: "")
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: NSLocalizedString("Open Settings", comment: ""))
                    alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                    }
                }
            default:
                break
            }
        }
    }
}
