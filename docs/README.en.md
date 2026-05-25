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
  <img alt="release" src="https://img.shields.io/badge/release-v2.0.0-0A84FF">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS-147EFB">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-FA7343">
  <img alt="notarized" src="https://img.shields.io/badge/Developer%20ID-notarized-34C759">
</p>

Pulse is a lightweight Dynamic Island-style Mac system monitor that stays at the top of the screen, with quick access to Resource Monitor and Applications.

<p align="center">
  <img src="assets/pulse-preview-combined.gif" width="640" alt="Pulse status panel preview in Light and Dark Mode">
</p>

## Download

Latest release:

- [Pulse 2.0.0](https://github.com/dorrrway/pulse/releases/tag/v2.0.0)
- DMG: [Pulse-2.0.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.0.0/Pulse-2.0.0.dmg)

SHA-256:

```text
eb19283e73273f8df1f70e466888aa95f95ef25dec227eaa129a4ca21ac46028  Pulse-2.0.0.dmg
```

## Installation

1. Download `Pulse-2.0.0.dmg`.
2. Open the DMG.
3. Follow the bilingual DMG guide and drag `Pulse.app` to Applications.
4. Launch Pulse from Applications.

The app is signed with Developer ID and notarized by Apple.

This version includes the updater and checks for updates in the background. When a new version is available, the full panel shows an Update button in the footer; clicking it lets Sparkle download, verify, and install the update. `1.0.0` itself does not include the updater, so moving from `1.0.0` to `1.1.0` still requires one manual download and install.

## System Requirements

- macOS 26.0 or later, as currently configured by the project.
- Apple Silicon and Intel Macs are supported.

## Privacy

Pulse reads local system metrics only, such as CPU, memory, disk, network byte counters, battery, thermal state, disk I/O, and the system's last boot time. To show usage rankings, Pulse also reads the names of running local processes, their CPU and memory usage, and local app bundle paths used to display app icons. To show the Applications list, Pulse reads app names, bundle IDs, versions, and bundle paths from standard application locations, and reads those apps' running state; when the user adds an app to Favorite Apps, Pulse stores that app bundle path locally.

Pulse requests the TimeLikeSilver-hosted appcast to check for new versions and downloads a release archive when the user clicks Update. This update-check request may be used to aggregate runtime trends, but it does not attach files, personal data, system metrics, process lists, application lists, app bundle paths, persistent tracking identifiers, or Sparkle system profiling data.

See [Privacy Policy](PRIVACY.en.md) for details.

## Changelog

### Unreleased

- Refined the transition from resting state to expanded state: the header text, icon, and common action buttons now fade in after the island begins opening, making the expansion feel less abrupt.
- Moved common actions into the expanded-state header: Settings and Quit now sit at the top right, while the Resource Monitor footer only keeps panel-specific controls; pinned panels now place Minimize at the bottom right.
- Simplified the Resource Monitor panel by removing the repeated Pulse title, device name, and pixel icon; the expanded-state Resource Monitor footer now shows the refresh time, while pinned panels no longer show time.
- Improved multi-display behavior: the Dynamic Island-style entry and pinned Resource Monitor panel now follow the current display, so switching between external monitors feels more consistent.
- Changed expanded-state module switching to a horizontal selector: Resource Monitor and Applications now sit in one row, left/right swipes switch modules, and the selected module stays centered.
- Added a single-row Favorite Apps panel in the Applications module: the module now opens in icon view by default, icon view supports dragging apps into favorites, list view uses a pin button to add or remove favorites quickly, favorites can be reordered by dragging or removed by dragging them back to the app area, and running apps show a highlighted dot below their icons.
- Smoothed Favorite Apps drop placement: dragging or reordering an app between two favorites now reserves the real landing width, reducing the jump after release.

### 2.0.0 - 2026-05-25

- Pulse now works like a Dynamic Island-style surface at the top of the screen, becoming the only primary entry point without a menu bar icon or menu bar status panel; Settings, updates, the pinned panel, and Quit remain available from the expanded state.
- Added the resting state: Pulse stays at the top center and lightly rotates between memory and CPU; when a Mac is on battery or charging from a low level at or below 20%, battery level joins the rotation with 20%, 10%, or charging icons.
- Hovering over Pulse opens the expanded state, with a Resource Monitor header and the full status panel below.
- Added the alert state: when a Mac is on battery at or below 10%, thermal state becomes critical, storage is extremely low, or memory pressure is high, Pulse briefly shows a more visible two-line alert, then returns to the resting state after 3 seconds; each continuous condition is shown once.
- Refined resting-state rotation with vertical rolling and numeric text transitions while respecting the system Reduce Motion setting.
- The expanded-state header can now be dragged or scrolled vertically to switch modules; the new Applications module opens local apps from standard application locations in either list view or a Launchpad-like icon view.
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
