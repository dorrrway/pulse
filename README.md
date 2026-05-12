<h1 align="center">
  <img src="pulse/pulse-icon.icon/Assets/Alienmonster-Theme=Flat.svg" width="72" alt="Pulse icon"><br>
  Pulse
</h1>

<h3 align="center">
  <a href="#下载">下载</a> |
  <a href="#安装">安装</a> |
  <a href="#更新日志">更新日志</a> |
  <a href="docs/RELEASE_RULES.md">发布规则</a> |
  <a href="docs/PRIVACY.zh-CN.md">隐私政策</a> |
  <a href="docs/README.en.md">English</a>
</h3>

<p align="center">
  <img alt="release" src="https://img.shields.io/badge/release-v1.0.0-0A84FF">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS-147EFB">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-FA7343">
  <img alt="notarized" src="https://img.shields.io/badge/Developer%20ID-notarized-34C759">
</p>

Pulse 是一款轻量级 macOS 菜单栏应用，用来快速查看本机系统状态。

<p align="center">
  <img src="docs/assets/pulse-preview-combined.gif" width="640" alt="Pulse 浅色和深色模式菜单栏状态面板预览">
</p>

## 下载

最新版本：

- 官网：[timelikesilver.com/apps/pulse](https://timelikesilver.com/apps/pulse)
- [Pulse 1.0.0](https://github.com/dorrrway/pulse/releases/tag/v1.0.0)
- DMG: [Pulse-1.0.dmg](https://github.com/dorrrway/pulse/releases/download/v1.0.0/Pulse-1.0.dmg)

SHA-256：

```text
3997d96332a23c674af77383f6391f3ba72cd151b8fe5c070facfebc1e7c250d  Pulse-1.0.dmg
```

## 安装

1. 下载 `Pulse-1.0.dmg`。
2. 打开 DMG。
3. 将 `Pulse.app` 拖入“应用程序”。
4. 从“应用程序”中启动 Pulse。

应用已使用 Developer ID 签名，并通过 Apple notarization。

## 系统要求

- 当前工程配置要求 macOS 26.0 或更高版本。
- 支持 Apple Silicon 和 Intel Mac。

## 隐私

Pulse 只读取本机系统指标，例如 CPU、内存、磁盘、网络收发字节计数、电池、热状态和磁盘 I/O。为显示占用排行，Pulse 也会读取本机正在运行进程的名称、CPU/内存占用，以及用于显示 App 图标的本机 App bundle 路径。

Pulse 不会向任何服务器上传分析数据、遥测数据、文件、个人数据或系统数据。

详情见 [隐私政策](docs/PRIVACY.zh-CN.md)。

## 更新日志

### 未发布

- 新增 CPU 和内存占用排行，展示本机应用/进程的实时资源占用。
- CPU 和内存占用图扩展为前五项，列表仍保持前三名。
- 占用排行前三名支持显示本机 App 图标。
- 使用像素化占比图展示排行构成。
- 更新隐私说明，明确进程名称、App bundle 路径及其 CPU、内存占用只用于本机界面展示。

### 1.0.0

- 初始版本：菜单栏系统状态面板、CPU/内存/磁盘/网络/电池/热状态/磁盘 I/O 指标、浅色与深色模式、开机启动设置。

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
