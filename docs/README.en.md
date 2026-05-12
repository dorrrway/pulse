# Pulse

[中文](README.zh-CN.md) | [Privacy Policy](PRIVACY.en.md)

Pulse is a lightweight macOS menu bar app for watching local system status at a glance.

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

- macOS 26.4 or later, as currently configured by the project.
- Apple Silicon and Intel Macs are supported.

## Privacy

Pulse reads local system metrics only, such as CPU, memory, disk, network byte counters, battery, thermal state, and disk I/O.

Pulse does not upload analytics, telemetry, files, personal data, or system data to any server.

See [PRIVACY.en.md](PRIVACY.en.md) for details.

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
