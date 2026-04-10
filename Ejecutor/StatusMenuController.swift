import Cocoa
import SwiftUI
import UserNotifications

final class StatusMenuController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var settingsWindow: NSWindow?
    private var scanResultWindow: NSWindow?

    override init() {
        super.init()
        setupIcon()
        updateMenu()
        observeVolumeChanges()
    }

    // MARK: - Setup

    private func setupIcon() {
        statusItem.button?.image = icon()
    }

    private func icon(color: NSColor? = nil) -> NSImage? {
        guard let img = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Ejecutor") else { return nil }
        if let color {
            return img.withSymbolConfiguration(.init(paletteColors: [color]))
        }
        img.isTemplate = true
        return img
    }

    private func observeVolumeChanges() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(updateMenu),
                       name: NSWorkspace.didMountNotification, object: nil)
        nc.addObserver(self, selector: #selector(updateMenu),
                       name: NSWorkspace.didUnmountNotification, object: nil)
    }

    // MARK: - Menu

    @objc private func updateMenu() {
        DispatchQueue.main.async {
            self.statusItem.menu = self.buildMenu()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let volumes = VolumeManager.externalVolumes()

        if volumes.isEmpty {
            let empty = NSMenuItem(title: NSLocalizedString("No external drives", comment: ""), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            volumes.forEach { addVolumeItem($0, to: menu) }
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: NSLocalizedString("Settings…", comment: ""), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func addVolumeItem(_ volume: Volume, to menu: NSMenu) {
        let item = NSMenuItem(title: "\(volume.name)  \(volume.displayCapacity)", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.addItem(action(NSLocalizedString("Clean and Eject", comment: ""), #selector(cleanAndEject(_:)), volume))
        sub.addItem(action(NSLocalizedString("Clean Only",      comment: ""), #selector(cleanOnly(_:)),     volume))
        sub.addItem(action(NSLocalizedString("Find Junk…",      comment: ""), #selector(scanVolume(_:)),    volume))
        sub.addItem(.separator())
        sub.addItem(action(NSLocalizedString("Eject Only",      comment: ""), #selector(ejectOnly(_:)),     volume))
        item.submenu = sub
        menu.addItem(item)
    }

    private func action(_ title: String, _ sel: Selector, _ volume: Volume) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.representedObject = volume
        item.target = self
        return item
    }

    // MARK: - Volume Actions

    @objc private func cleanAndEject(_ sender: NSMenuItem) {
        guard let volume = sender.representedObject as? Volume else { return }
        performCleanAndEject(volume: volume)
    }

    @objc private func cleanOnly(_ sender: NSMenuItem) {
        guard let volume = sender.representedObject as? Volume else { return }
        performClean(volume: volume)
    }

    @objc private func scanVolume(_ sender: NSMenuItem) {
        guard let volume = sender.representedObject as? Volume else { return }
        let settings = SettingsManager.shared.cleanupSettings

        DispatchQueue.global(qos: .userInitiated).async {
            let items = CleanupManager.scan(volume: volume, settings: settings)
            DispatchQueue.main.async { self.showScanResult(volume: volume, items: items) }
        }
    }

    private func performCleanAndEject(volume: Volume) {
        let settings = SettingsManager.shared.cleanupSettings
        startBlinking()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = CleanupManager.clean(volume: volume, settings: settings)
            do {
                try VolumeManager.eject(volume)
                DispatchQueue.main.async {
                    self.stopBlinking()
                    self.flashIcon()
                }
                self.notify(
                    String(format: NSLocalizedString("✓ %@ ejected", comment: ""), volume.name),
                    body: self.cleanupBody(result)
                )
            } catch {
                DispatchQueue.main.async { self.stopBlinking() }
                self.notify(
                    NSLocalizedString("Eject Error", comment: ""),
                    body: String(format: NSLocalizedString("Failed to eject %@: %@", comment: ""), volume.name, error.localizedDescription)
                )
            }
        }
    }

    private func performClean(volume: Volume) {
        let settings = SettingsManager.shared.cleanupSettings
        startBlinking()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = CleanupManager.clean(volume: volume, settings: settings)
            DispatchQueue.main.async { self.stopBlinking() }
            self.notify(
                String(format: NSLocalizedString("✓ %@ cleaned", comment: ""), volume.name),
                body: self.cleanupBody(result)
            )
        }
    }

    private func cleanupBody(_ result: CleanupResult) -> String {
        let freed = ByteCountFormatter.string(fromByteCount: result.freedBytes, countStyle: .file)
        let errNote = result.errors.isEmpty ? "" : String(format: NSLocalizedString(", errors: %d", comment: ""), result.errors.count)
        return String(format: NSLocalizedString("Deleted %d files, freed %@%@", comment: ""), result.deletedCount, freed, errNote)
    }

    private func showScanResult(volume: Volume, items: [ScannedFile]) {
        scanResultWindow?.close()
        let view = ScanResultView(
            volume: volume,
            items: items,
            onClean: { [weak self] in self?.performClean(volume: volume) },
            onCleanAndEject: { [weak self] in self?.performCleanAndEject(volume: volume) },
            onDismiss: { [weak self] in self?.scanResultWindow?.close() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(format: NSLocalizedString("Scanning: %@", comment: ""), volume.name)
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 560, height: 420))
        window.minSize = NSSize(width: 560, height: 280)
        window.center()
        window.level = .floating
        scanResultWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
    }

    @objc private func ejectOnly(_ sender: NSMenuItem) {
        guard let volume = sender.representedObject as? Volume else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VolumeManager.eject(volume)
                DispatchQueue.main.async { self.flashIcon() }
                self.notify(String(format: NSLocalizedString("✓ %@ ejected", comment: ""), volume.name), body: "")
            } catch {
                self.notify(
                    NSLocalizedString("Error", comment: ""),
                    body: String(format: NSLocalizedString("Failed to eject %@: %@", comment: ""), volume.name, error.localizedDescription)
                )
            }
        }
    }

    // MARK: - Icon Animation

    private var blinkTimer: Timer?
    private var flashTimer: Timer?

    private func startBlinking() {
        stopBlinking()
        var on = true
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.statusItem.button?.image = on ? self?.icon(color: .systemOrange) : self?.icon()
            on.toggle()
        }
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        flashTimer?.invalidate()
        flashTimer = nil
        statusItem.button?.image = icon()
    }

    private func flashIcon(times: Int = 3) {
        flashTimer?.invalidate()
        var count = 0
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if count >= times * 2 {
                timer.invalidate()
                self.flashTimer = nil
                self.statusItem.button?.image = self.icon()
                return
            }
            self.statusItem.button?.image = count % 2 == 0 ? self.icon(color: .systemRed) : self.icon()
            count += 1
        }
    }

    // MARK: - Settings Window

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Ejecutor Settings", comment: "")
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 300, height: 306))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Notifications

    private func notify(_ title: String, body: String) {
        DispatchQueue.main.async {
            let content = UNMutableNotificationContent()
            content.title = title
            if !body.isEmpty { content.body = body }
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req)
        }
    }
}
