# Ejecutor

macOS menu bar app for cleaning and ejecting external drives.

Removes macOS junk files (`.DS_Store`, `._*`, `.Trashes`, `.Spotlight-V100`, etc.) before or instead of ejecting.

## Features

- Lives in the menu bar, no Dock icon
- Detects all external volumes automatically (USB drives, SSDs in enclosures, SD cards)
- Updates the volume list on mount/unmount
- **Clean & Eject** — remove junk files, then eject
- **Clean only** — remove junk files, keep mounted
- **Eject only** — eject without cleaning
- **Dry run** — scan and preview what would be deleted, then optionally clean
- Settings window to toggle which file types to remove
- System notification with results (files deleted, space freed)

## Cleaned file types

| Pattern | Description |
|---|---|
| `.DS_Store` | Finder metadata |
| `._*` | AppleDouble resource forks |
| `.Trashes` | Trash folder |
| `.Spotlight-V100` | Spotlight index |
| `.fseventsd` | File system events log |
| `.TemporaryItems` | Temporary files |
| `.DocumentRevisions-V100` | Versions database |

All types can be individually toggled in Settings (⌘,).

## Requirements

- macOS 12 Ventura or later
- Xcode 15+

## Build

Open `Ejecutor.xcodeproj` in Xcode and press ⌘R.

No dependencies, no CocoaPods, no SPM packages.
