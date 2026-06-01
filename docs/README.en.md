<h1 align="center">
  <img src="../pulse/pulse-icon.icon/Assets/Alienmonster-Theme=Flat.svg" width="72" alt="Pulse icon"><br>
  Pulse
</h1>

<h3 align="center">
  <a href="#download">Download</a> |
  <a href="#installation">Installation</a> |
  <a href="#changelog">Changelog</a> |
  <a href="RELEASE_RULES.md">Release Rules</a> |
  <a href="PRIVACY.en.md">Privacy Policy</a> |
  <a href="../README.md">中文</a>
</h3>

<p align="center">
  <img alt="release" src="https://img.shields.io/badge/release-v2.3.0-0A84FF">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS-147EFB">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-FA7343">
  <img alt="notarized" src="https://img.shields.io/badge/Developer%20ID-notarized-34C759">
</p>

Pulse is a local-first macOS control center that stays at the top of your screen, bringing system status, everyday tools, and device controls into one Dynamic Island-style surface.

<p align="center">
  <img src="assets/pulse-preview-combined.gif" width="640" alt="Pulse status panel preview in Light and Dark Mode">
</p>

## Download

Latest release:

- [Pulse 2.3.0](https://github.com/dorrrway/pulse/releases/tag/v2.3.0)
- DMG: [Pulse-2.3.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.3.0/Pulse-2.3.0.dmg)

SHA-256:

```text
66be3ba207946b71e449bf547a963bd4c4bd8f15d780146235958bb405c3efde  Pulse-2.3.0.dmg
```

## Installation

1. Download `Pulse-2.3.0.dmg`.
2. Open the DMG.
3. Follow the bilingual DMG guide and drag `Pulse.app` to Applications.
4. Launch Pulse from Applications.

The app is signed with Developer ID and notarized by Apple.

This version includes the updater and checks for updates in the background. When a new version is available, the full panel shows an Update button in the footer; clicking it lets Sparkle download, verify, and install the update. `1.0.0` itself does not include the updater, so moving from `1.0.0` to `1.1.0` still requires one manual download and install.

## System Requirements

- macOS 15.0 or later, as currently configured by the project.
- Apple Silicon and Intel Macs are supported.

## Privacy

Pulse reads local system metrics, such as CPU, memory, disk, network byte counters, battery, thermal state, disk I/O, and the system's last boot time. To show usage rankings, Pulse also reads the names of running local processes, their CPU and memory usage, and local app bundle paths used to display app icons. To show the Applications list, Pulse reads app names, bundle IDs, versions, and bundle paths from standard application locations, and reads those apps' running state; when the user adds an app to Favorite Apps, Pulse stores that app bundle path locally. After Bluetooth access is granted, the Bluetooth module reads local Bluetooth device names, types, connection state, Bluetooth addresses, and battery or charging-state fields exposed by macOS in local memory so it can show the device list, connect or disconnect paired devices, display available battery levels and charging state, and show local low-battery alerts for Bluetooth devices; this data is not uploaded, written to a persistent database, or saved as battery or charging history. The Clipboard module reads system clipboard changes and stores text, links, file URL/path representations, images, original pasteboard representations, source-app hints, and sensitive or transient markers in local history; when files are copied, Pulse does not proactively read or store the file contents themselves. Sensitive entries are masked by default but remain searchable and copyable. Double-clicking a clipboard entry can send one paste shortcut to the currently focused target after macOS Accessibility permission is granted; Pulse does not read the target app's input contents. OCR is off by default; when enabled, Vision processes image text locally on the Mac. The Memo module stores user-entered memos, todo state, pin state, and timestamps in the local Application Support directory and does not upload them.

The Capture module calls native macOS screenshot and recording APIs only when the user clicks an action or triggers a shortcut; first use requires macOS Screen Recording permission. Screenshots continue to use native `screencapture`, hide Pulse before capture by default, and are written to the system clipboard. If clipboard history is enabled, that image follows the existing local Clipboard history rules. Full-screen and window recordings first reuse the native macOS screenshot picker to create and immediately delete a temporary target-selection screenshot only to read macOS's selected target metadata. Custom-region recording shows a local AppKit selection layer that dims unselected areas while keeping the selected region at its original brightness. After recording starts, custom-region recording keeps a non-interactive local region guide visible so the unrecorded area stays dimmed and the selected area keeps a blue boundary; Pulse excludes that guide from the final recording output. Pulse then records the selected display, window, or region with native ScreenCaptureKit and writes the temporary `.mov` with AVFoundation.

Recordings do not capture system audio or microphone audio and hide the mouse pointer by default. After recording starts, the Pulse island returns with an elapsed-time label and a stop button. When Hide Pulse is enabled, ScreenCaptureKit excludes Pulse itself from the final recording output, so the saved video does not contain the Pulse island. The live macOS sharing indicator is controlled by the system and is not written into the final video by Pulse. After recording stops, Pulse keeps the temporary `.mov` in an island video preview, lets the user play it locally first, and then save, share, or discard it. Discarding or replacing the preview removes the temporary file.

The screenshot completion reminder's Save, Share, Edit, Pin, and Recognize Text actions run only after the user clicks them: Save writes a PNG to the user-selected location, Share hands the image to the macOS share sheet, Edit opens a local foreground floating editor for brush-based mosaic redaction, rectangles, circles, arrows, pen strokes, and text; the editor's Save, Share, and Pin actions also operate only on the current edited image, and completing the edit writes the edited image back to the system clipboard. Pin keeps the current screenshot in a local foreground floating window until the user closes it, and Recognize Text uses local Vision before letting the user choose whether to copy text to the clipboard. Dragging the screenshot preview to Finder, chat windows, or documents provides PNG data for that drag and prepares a PNG file representation in the system temporary directory; old temporary drag files are cleaned up by later drags.

Pulse requests the TimeLikeSilver-hosted appcast to check for new versions and downloads a release archive when the user clicks Update. This update-check request may be used to aggregate runtime trends, but it does not attach files, personal data, system metrics, process lists, application lists, Bluetooth device lists, Bluetooth battery levels, Bluetooth charging state, app bundle paths, persistent tracking identifiers, or Sparkle system profiling data.

See [Privacy Policy](PRIVACY.en.md) for details.

## Changelog

### Unreleased

- Renamed the Screenshots module to Capture and added native recording actions below the existing full-screen, window, and selection screenshot actions; full-screen and window target selection still reuse the native macOS screenshot picker, custom-region recording uses local selection and recording guide layers that dim unselected areas, and recording output is written with ScreenCaptureKit + AVFoundation.
- After recording starts, the Pulse island shows elapsed time and a stop button; when Hide Pulse is enabled, Pulse is hidden before target selection and excluded from the final recording output.
- Each recording mode can also have a global shortcut set from the Capture panel or Settings; shortcuts follow the Hide Pulse and Hide Mouse options, and triggering the same mode while it is recording stops the recording and opens an island video preview so the user can play, save, share, or discard the temporary `.mov`.
- Added Hide Pulse and Hide Mouse options so screenshots can hide Pulse before capture, recordings can exclude Pulse from saved videos, and recordings can hide the pointer for cleaner screen videos.
- Refined Capture panel icons and mode labels: recording actions now use dedicated icons, recording buttons reuse the Full Screen, Window, and Selection mode names, and Hide Pulse uses a clearer dedicated icon.
- Added a Memo module for local notes and todos in the Pulse island, with all/todo/notes/done filters, search, editing, pinning, copy, delete, and clearing completed todos. All memo content stays local.

### 2.3.0 - 2026-06-01

- Added a Screenshots module with native macOS full-screen, window, and selection capture modes; full-screen capture opens the native display picker for confirmation first, window capture omits the system window shadow, captures are written to the system clipboard, the island shows an image preview reminder after capture and auto-collapses after 3 seconds only when it is not hovered, the reminder exposes explicit Save, Share, Edit, foreground pinning, local text-recognition, and direct preview-drag export actions, and each mode can have its global shortcut set directly in the Screenshots panel without requiring modifier keys.
- Added a bottom Screenshots panel option to hide Pulse while capturing. It is on by default; turning it off lets users include Pulse itself in screenshots, and both panel actions and screenshot shortcuts follow the setting.
- The screenshot completion reminder now includes an Edit action that opens a pinned-image-style foreground floating editor, with a light-mode white and dark-mode adaptive icon toolbar below the image. The toolbar starts with a separated hand Move button and then offers rectangles, circles, arrows, pen strokes, mosaic redaction, text, undo, save, share, pin, cancel, and done.
- Mosaic redaction in the screenshot editor now uses source-image pixelation with a brush stroke, letting users cover along content contours instead of drawing only rectangular regions.
- Pinned screenshot floating windows keep the same borderless image-window style and now use native macOS window resizing while preserving the original image aspect ratio.
- Fixed the screenshot editor starting with Mosaic selected and accidentally adding redaction while dragging the image; it now starts with no selected tool, and selecting a tool locks the image area so drawing does not move the editor window.
- Fixed canceling the native macOS screenshot picker showing the previous screenshot preview; Pulse now shows the completion reminder only when the current capture writes a new clipboard image.
- The Screenshots panel now shows an orange authorization notice when macOS Screen Recording permission has not been granted, clarifying that captures only run after a user click or shortcut.
- Added a Bluetooth module that lists local Bluetooth devices, connection state, and readable battery levels; single-battery devices such as keyboards, trackpads, and mice show one circular battery indicator, Apple HID devices lightly alternate the center battery icon with a bolt when macOS returns charging state, AirPods-style devices show left, right, and case battery levels when macOS returns them, and paired devices can be connected or disconnected from the list.
- Bluetooth devices at or below 20% or 10% now reuse the Pulse Island two-line alert style, colors, and animation for local low-battery reminders; each continuous low-battery state is shown once.
- Refined the screenshot completion reminder header so its icon, title, and completion state align with the island's top row.
- Added a Copy item action to the Clipboard record context menu, letting users write a saved record back to the system clipboard from right-click.
- Fixed a case where launching some apps from the Applications module could collapse the island panel and immediately reopen it from a stale hover event.
- Release archive: [Pulse-2.3.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.3.0/Pulse-2.3.0.dmg); SHA-256: `66be3ba207946b71e449bf547a963bd4c4bd8f15d780146235958bb405c3efde`.

### 2.2.0 - 2026-05-27

- Expanded system compatibility: the minimum system requirement is now macOS 15.0 instead of macOS 26.0; macOS 26 and later continue to use the existing clipboard permission status and favorite-removal drag feedback paths.
- Release archive: [Pulse-2.2.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.2.0/Pulse-2.2.0.dmg); SHA-256: `47aa82f18b1b44af26ed31fa66224bd7f5564a914cc42d7513e0e83b871c86fb`.

### 2.1.0 - 2026-05-27

- Refined the transition from resting state to expanded state: the header text, icon, and common action buttons now fade in after the island begins opening, making the expansion feel less abrupt.
- Moved common actions into the expanded-state header: Settings and Quit now sit at the top right, while the Resource Monitor footer only keeps panel-specific controls; pinned panels now place Minimize at the bottom right.
- Simplified the Resource Monitor panel by removing the repeated Pulse title, device name, and pixel icon; the expanded-state Resource Monitor footer now shows the refresh time, while pinned panels no longer show time.
- Improved multi-display behavior: the Dynamic Island-style entry and pinned Resource Monitor panel now follow the current display, so switching between external monitors feels more consistent.
- Changed expanded-state module switching to a horizontal selector: Resource Monitor and Applications now sit in one row, click or row-wide left/right swipes switch modules, the selected module stays centered, and swipe direction follows natural paging.
- After first launch or restart, expanding the island now defaults to the Applications module so users can launch favorite apps directly.
- Added the Clipboard module: Pulse records text, links, files, images, and sensitive or transient markers by default, keeps history locally, supports filtering by all/text/images/links/files plus search, copy, reveal, delete, and clear actions, supports double-click direct paste into the currently focused target when Accessibility permission allows it, and lets users adjust entry and time retention in Settings; duplicate payloads are merged into one history entry, copying from Clipboard history does not add another entry, sensitive entries are masked by default while copying the complete original payload, and OCR is off by default and local-only.
- Fixed mojibake when some apps provide clipboard text as UTF-16 without a byte-order mark; matching local history entries repair their display text on next launch.
- Added a Shortcuts area in Settings for separate global shortcuts that wake Clipboard or Applications; shortcuts are stored only in local preferences.
- Shortcut wake now reuses the mounted island panel and opens directly into the target module, making the expansion feel closer to pointer hover.
- The resting island now shows a 1.5-second minimal confirmation when Clipboard saves a new record, using a content-type icon, Copied label on non-notched screens, and completion checkmark without opening the panel or changing the data boundary.
- Clearing clipboard history now asks for confirmation inline in the footer, preventing accidental removal of all records.
- Added a single-row Favorite Apps panel in the Applications module: the module now opens in icon view by default, icon view supports dragging apps into favorites, list view uses a pin button to add or remove favorites quickly, favorites can be reordered by dragging or removed by dragging them back to the app area, and running apps show a highlighted dot below their icons.
- Opening an app from the Applications module now returns Pulse to its resting state, reducing overlap while the target app launches.
- Smoothed Favorite Apps drop placement: dragging or reordering an app between two favorites now reserves the real landing width, reducing the jump after release.
- Release archive: [Pulse-2.1.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.1.0/Pulse-2.1.0.dmg); SHA-256: `fd784f829c28e672fd88f94024ecd9a4fe08ca60492154d632040a9274249017`.

### 2.0.0 - 2026-05-25

- Pulse now works like a Dynamic Island-style surface at the top of the screen, becoming the only primary entry point without a menu bar icon or menu bar status panel; Settings, updates, the pinned panel, and Quit remain available from the expanded state.
- Added the resting state: Pulse stays at the top center and lightly rotates between memory and CPU; when a Mac is on battery or charging from a low level at or below 20%, battery level joins the rotation with 20%, 10%, or charging icons.
- Hovering over Pulse opens the expanded state, with a Resource Monitor header and the full status panel below.
- Added the alert state: when a Mac is on battery at or below 10%, thermal state becomes critical, storage is extremely low, or memory pressure is high, Pulse briefly shows a more visible two-line alert, then returns to the resting state after 3 seconds; each continuous condition is shown once.
- Refined resting-state rotation with vertical rolling and numeric text transitions while respecting the system Reduce Motion setting.
- The expanded-state header supports horizontal module switching; the new Applications module opens local apps from standard application locations in either list view or a Launchpad-like icon view.
- Fixed Pulse placement on MacBooks with a camera housing by avoiding the hidden top-center area.
- Release archive: [Pulse-2.0.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.0.0/Pulse-2.0.0.dmg); SHA-256: `eb19283e73273f8df1f70e466888aa95f95ef25dec227eaa129a4ca21ac46028`.

### 1.2.0 - 2026-05-15

- Fixed Language > System sometimes showing English under macOS settings whose preferred language is Chinese; Pulse now matches supported languages from the system preferred-language list.
- Fixed Appearance > System not immediately refreshing open windows after switching back from Light or Dark mode.
- Improved the DMG installer window with bilingual drag guidance and fixed Pulse-to-Applications layout.
- Release archive: [Pulse-1.2.0.dmg](https://github.com/dorrrway/pulse/releases/download/v1.2.0/Pulse-1.2.0.dmg); SHA-256: `4549673b0017257a46326c5f6b91f8833ddd98a386c218bda484c8bac6e45c95`.

### 1.1.4 - 2026-05-14

- Fixed the pinned floating panel Update button staying gray under system rendering while preserving its original size.
- The settings page now shows the current app version at the bottom.
- Release archive: [Pulse-1.1.4.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.4/Pulse-1.1.4.dmg); SHA-256: `36147b065eea136d272502bbb09c5d054cafe54c174acd33deb73080a1717d6e`.

### 1.1.3 - 2026-05-14

- Refined the full-panel update prompt: in pinned floating panels, the Update button now sits after the minimize control and uses a more visible blue background.
- Release archive: [Pulse-1.1.3.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.3/Pulse-1.1.3.dmg); SHA-256: `fd8d4116081d4eaad0c03113fd08489b64b855f0d8cb688653cf293e078f82b9`.

### 1.1.2 - 2026-05-14

- Moved update checks to the TimeLikeSilver-hosted appcast endpoint so update checks can aggregate runtime trends; requests still do not attach system metrics, files, process lists, app bundle paths, persistent tracking identifiers, or Sparkle system profiling data.
- Refined full-panel status dots and CPU ranking warning colors so high-CPU app names and values use the same staged color feedback.
- Release archive: [Pulse-1.1.2.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.2/Pulse-1.1.2.dmg); SHA-256: `aac8429ff0a48e4f44767e95ca9d42a205e13f9138e31016d9d35dfb9a6b0726`.

### 1.1.1 - 2026-05-14

- Adjusted the high-activity threshold for disk I/O and reduced Pulse's own refresh overhead without slowing real-time CPU, memory, network, or disk I/O updates.

### 1.1.0 - 2026-05-14

- Added a pinnable floating panel and minimal mode for switching between the full status panel and a compact metrics view.
- Added CPU and memory usage rankings with local app/process usage, app icons, pixel share charts, and detail popovers.
- Refined full-panel status feedback with System Runtime, status-colored memory, thermal, power, and disk I/O cards, and warning colors for high CPU usage.
- Added Sparkle updates, allowing new versions to be downloaded, verified, and installed from the panel.
- Added Appearance and Contact settings, and simplified the startup and language settings.
- Improved menu bar and floating panel layout, made metric feedback more responsive, and fixed theme syncing, settings-window focus, and floating-panel stability issues.
- Updated the privacy wording to clarify local use of process names, app bundle paths, resource usage, and update checks without uploading system metrics or profiling data.

### 1.0.0

- Initial release with a menu bar system status panel, CPU, memory, disk, network, battery, thermal state, and disk I/O metrics, Light and Dark Mode support, and launch-at-login settings.

## Development

Run tests:

```sh
xcodebuild test \
  -project pulse.xcodeproj \
  -scheme pulse \
  -destination 'platform=macOS'
```

Build locally:

```sh
xcodebuild \
  -project pulse.xcodeproj \
  -scheme pulse \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

When publishing a new version, sign the release archive with the Sparkle EdDSA private key and append the signed item to `appcast.xml`. Never commit the private key.
