import Foundation
import ServiceManagement

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var removeDSStore: Bool {
        didSet { UserDefaults.standard.set(removeDSStore, forKey: "removeDSStore") }
    }
    @Published var removeAppleDouble: Bool {
        didSet { UserDefaults.standard.set(removeAppleDouble, forKey: "removeAppleDouble") }
    }
    @Published var appleDoubleOnlyIfPaired: Bool {
        didSet { UserDefaults.standard.set(appleDoubleOnlyIfPaired, forKey: "appleDoubleOnlyIfPaired") }
    }
    @Published var removeTrashes: Bool {
        didSet { UserDefaults.standard.set(removeTrashes, forKey: "removeTrashes") }
    }
    @Published var removeSpotlight: Bool {
        didSet { UserDefaults.standard.set(removeSpotlight, forKey: "removeSpotlight") }
    }
    @Published var removeFSEvents: Bool {
        didSet { UserDefaults.standard.set(removeFSEvents, forKey: "removeFSEvents") }
    }
    @Published var removeTemporaryItems: Bool {
        didSet { UserDefaults.standard.set(removeTemporaryItems, forKey: "removeTemporaryItems") }
    }
    @Published var removeDocumentRevisions: Bool {
        didSet { UserDefaults.standard.set(removeDocumentRevisions, forKey: "removeDocumentRevisions") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard #available(macOS 13.0, *) else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[Ejecutor] LaunchAtLogin error: \(error)")
                // Откатываем тоггл к реальному состоянию системы
                DispatchQueue.main.async {
                    self.launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "removeDSStore": true,
            "removeAppleDouble": true,
            "appleDoubleOnlyIfPaired": true,
            "removeTrashes": true,
            "removeSpotlight": true,
            "removeFSEvents": true,
            "removeTemporaryItems": true,
            "removeDocumentRevisions": true,
        ])
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLogin = false
        }
        removeDSStore              = d.bool(forKey: "removeDSStore")
        removeAppleDouble          = d.bool(forKey: "removeAppleDouble")
        appleDoubleOnlyIfPaired    = d.bool(forKey: "appleDoubleOnlyIfPaired")
        removeTrashes           = d.bool(forKey: "removeTrashes")
        removeSpotlight         = d.bool(forKey: "removeSpotlight")
        removeFSEvents          = d.bool(forKey: "removeFSEvents")
        removeTemporaryItems    = d.bool(forKey: "removeTemporaryItems")
        removeDocumentRevisions = d.bool(forKey: "removeDocumentRevisions")
    }

    var cleanupSettings: CleanupSettings {
        CleanupSettings(
            removeDSStore:           removeDSStore,
            removeAppleDouble:       removeAppleDouble,
            appleDoubleOnlyIfPaired: appleDoubleOnlyIfPaired,
            removeTrashes:           removeTrashes,
            removeSpotlight:         removeSpotlight,
            removeFSEvents:          removeFSEvents,
            removeTemporaryItems:    removeTemporaryItems,
            removeDocumentRevisions: removeDocumentRevisions
        )
    }
}
