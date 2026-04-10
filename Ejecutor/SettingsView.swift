import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)

            Divider()

            Text("Files to Remove")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(".DS_Store",                        isOn: $settings.removeDSStore)
                Toggle("._* (AppleDouble)",                isOn: $settings.removeAppleDouble)
                Toggle("Only if paired file exists",       isOn: $settings.appleDoubleOnlyIfPaired)
                    .padding(.leading, 16)
                    .disabled(!settings.removeAppleDouble)
                Toggle(".Trashes",                         isOn: $settings.removeTrashes)
                Toggle(".Spotlight-V100",                  isOn: $settings.removeSpotlight)
                Toggle(".fseventsd",                       isOn: $settings.removeFSEvents)
                Toggle(".TemporaryItems",                  isOn: $settings.removeTemporaryItems)
                Toggle(".DocumentRevisions-V100",          isOn: $settings.removeDocumentRevisions)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
