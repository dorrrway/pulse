<h1 align="center">
  <img src="../pulse/pulse-icon.icon/Assets/Alienmonster-Theme=Flat.svg" width="72" alt="Pulse icon"><br>
  Pulse
</h1>

<h3 align="center">
  <a href="#download">Download</a> |
  <a href="#installation">Installation</a> |
  <a href="#changelog">Changelog</a> |
  <a href="PRIVACY.en.md">Privacy Policy</a> |
  <a href="../README.md">中文</a>
</h3>

<p align="center">
  <img alt="release" src="https://img.shields.io/badge/release-v1.0.0-0A84FF">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS-147EFB">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-FA7343">
  <img alt="notarized" src="https://img.shields.io/badge/Developer%20ID-notarized-34C759">
</p>

Pulse is a lightweight macOS menu bar app for watching local system status at a glance.

<p align="center">
  <img src="assets/pulse-preview-combined.gif" width="640" alt="Pulse menu bar status panel preview in Light and Dark Mode">
</p>

## Download

Latest release:

- [Pulse 1.0.0](https://github.com/dorrrway/pulse/releases/tag/v1.0.0)
- DMG: [Pulse-1.0.dmg](https://github.com/dorrrway/pulse/releases/download/v1.0.0/Pulse-1.0.dmg)

SHA-256:

```text
3997d96332a23c674af77383f6391f3ba72cd151b8fe5c070facfebc1e7c250d  Pulse-1.0.dmg
```

## Installation

1. Download `Pulse-1.0.dmg`.
2. Open the DMG.
3. Drag `Pulse.app` to Applications.
4. Launch Pulse from Applications.

The app is signed with Developer ID and notarized by Apple.

## System Requirements

- macOS 26.0 or later, as currently configured by the project.
- Apple Silicon and Intel Macs are supported.

## Privacy

Pulse reads local system metrics only, such as CPU, memory, disk, network byte counters, battery, thermal state, and disk I/O. To show usage rankings, Pulse also reads the names of running local processes and their CPU and memory usage.

Pulse does not upload analytics, telemetry, files, personal data, or system data to any server.

See [Privacy Policy](PRIVACY.en.md) for details.

## Changelog

### Unreleased

- Added CPU and memory usage rankings for local apps and processes.
- Added pixel-style share charts for the ranking breakdown.
- Updated the privacy wording to clarify that process names and their CPU and memory usage are used only to render the local interface.

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
