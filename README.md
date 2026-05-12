# Pulse

Pulse is a lightweight macOS menu bar app for watching local system status at a glance.

Pulse 是一款轻量级 macOS 菜单栏应用，用来快速查看本机系统状态。

## Download

Latest release:

- [Pulse 1.0.0](https://github.com/dorrrway/pulse/releases/tag/v1.0.0)
- DMG: [Pulse-1.0.dmg](https://github.com/dorrrway/pulse/releases/download/v1.0.0/Pulse-1.0.dmg)

SHA-256:

```text
3997d96332a23c674af77383f6391f3ba72cd151b8fe5c070facfebc1e7c250d  Pulse-1.0.dmg
```

## 下载

最新版本：

- [Pulse 1.0.0](https://github.com/dorrrway/pulse/releases/tag/v1.0.0)
- DMG: [Pulse-1.0.dmg](https://github.com/dorrrway/pulse/releases/download/v1.0.0/Pulse-1.0.dmg)

SHA-256：

```text
3997d96332a23c674af77383f6391f3ba72cd151b8fe5c070facfebc1e7c250d  Pulse-1.0.dmg
```

## Installation

1. Download `Pulse-1.0.dmg`.
2. Open the DMG.
3. Drag `Pulse.app` to Applications.
4. Launch Pulse from Applications.

The app is signed with Developer ID and notarized by Apple.

## 安装

1. 下载 `Pulse-1.0.dmg`。
2. 打开 DMG。
3. 将 `Pulse.app` 拖入“应用程序”。
4. 从“应用程序”中启动 Pulse。

应用已使用 Developer ID 签名，并通过 Apple notarization。

## System Requirements

- macOS 26.4 or later, as currently configured by the project.
- Apple Silicon and Intel Macs are supported.

## 系统要求

- 当前工程配置要求 macOS 26.4 或更高版本。
- 支持 Apple Silicon 和 Intel Mac。

## Privacy

Pulse reads local system metrics only, such as CPU, memory, disk, network byte counters, battery, thermal state, and disk I/O.

Pulse does not upload analytics, telemetry, files, personal data, or system data to any server.

See [PRIVACY.md](PRIVACY.md) for details.

## 隐私

Pulse 只读取本机系统指标，例如 CPU、内存、磁盘、网络收发字节计数、电池、热状态和磁盘 I/O。

Pulse 不会向任何服务器上传分析数据、遥测数据、文件、个人数据或系统数据。

详情见 [PRIVACY.md](PRIVACY.md)。

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

## 开发

运行测试：

```sh
xcodebuild test \
  -project pulse.xcodeproj \
  -scheme pulse \
  -destination 'platform=macOS'
```

本地构建：

```sh
xcodebuild \
  -project pulse.xcodeproj \
  -scheme pulse \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```
