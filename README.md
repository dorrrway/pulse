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
  <img alt="release" src="https://img.shields.io/badge/release-v1.1.2-0A84FF">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS-147EFB">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-FA7343">
  <img alt="notarized" src="https://img.shields.io/badge/Developer%20ID-notarized-34C759">
</p>

Pulse 是一款轻量级 macOS 菜单栏应用，用来快速查看本机系统状态。

<p align="center">
  <img src="docs/assets/pulse-preview-combined.gif" width="640" alt="Pulse 浅色和深色模式菜单栏状态面板预览">
</p>

## 下载

最新版本：

- 官网：[timelikesilver.com/apps/pulse](https://timelikesilver.com/apps/pulse)
- [Pulse 1.1.2](https://github.com/dorrrway/pulse/releases/tag/v1.1.2)
- DMG: [Pulse-1.1.2.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.2/Pulse-1.1.2.dmg)

SHA-256：

```text
aac8429ff0a48e4f44767e95ca9d42a205e13f9138e31016d9d35dfb9a6b0726  Pulse-1.1.2.dmg
```

## 安装

1. 下载 `Pulse-1.1.2.dmg`。
2. 打开 DMG。
3. 将 `Pulse.app` 拖入“应用程序”。
4. 从“应用程序”中启动 Pulse。

应用已使用 Developer ID 签名，并通过 Apple notarization。

本版本已内置更新器，会在后台检查更新。检测到新版本时，完整面板底部会显示“更新”按钮，点击后由 Sparkle 下载、验证并安装新版本。`1.0.0` 本身尚未内置更新器，因此从 `1.0.0` 升级到 `1.1.0` 仍需要手动下载安装一次。

## 系统要求

- 当前工程配置要求 macOS 26.0 或更高版本。
- 支持 Apple Silicon 和 Intel Mac。

## 隐私

Pulse 只读取本机系统指标，例如 CPU、内存、磁盘、网络收发字节计数、电池、热状态、磁盘 I/O 和系统上次启动时间。为显示占用排行，Pulse 也会读取本机正在运行进程的名称、CPU/内存占用，以及用于显示 App 图标的本机 App bundle 路径。

Pulse 会请求 TimeLikeSilver 官网的 appcast 以检查新版本，并在用户点击更新时下载发布包。该更新检查请求可能用于汇总运行趋势，但不会附加文件、个人数据、系统指标、进程列表、App bundle 路径、持久追踪标识或 Sparkle 系统画像。

详情见 [隐私政策](docs/PRIVACY.zh-CN.md)。

## 更新日志

### 未发布

### 1.1.2 - 2026-05-14

- 将更新检查源切换到 TimeLikeSilver 官网 appcast 入口，以便通过更新检查汇总运行趋势；请求仍不附加系统指标、文件、进程列表、App bundle 路径、持久追踪标识或 Sparkle 系统画像。
- 优化完整面板的状态点和 CPU 占用排行警示色，高 CPU 应用名称与数值会使用一致的分级颜色。
- 发布包：[Pulse-1.1.2.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.2/Pulse-1.1.2.dmg)；SHA-256：`aac8429ff0a48e4f44767e95ca9d42a205e13f9138e31016d9d35dfb9a6b0726`。

### 1.1.1 - 2026-05-14

- 调整磁盘 I/O 高活动提示阈值，并在不降低 CPU、内存、网络、磁盘 I/O 实时刷新的前提下降低 Pulse 自身刷新开销。

### 1.1.0 - 2026-05-14

- 新增可固定的悬浮面板与极简模式，可在完整状态面板和紧凑指标视图之间切换。
- 新增 CPU 与内存占用排行，显示本机应用/进程的资源占用、App 图标、像素占比图和详情浮层。
- 优化完整面板状态展示：新增开机时长，状态卡片按内存压力、温度、电源和磁盘 I/O 变色，并为高 CPU 占用提供警示色。
- 接入 Sparkle 更新器，检测到新版本时可在面板内下载、验证并安装更新。
- 设置页新增外观模式与联系我们入口，并简化启动和语言设置。
- 优化菜单栏面板和悬浮面板布局，提升刷新反馈，修复主题同步、设置窗口置前和悬浮面板打开稳定性问题。
- 更新隐私说明，明确进程名称、App bundle 路径、资源占用和更新检查的本机使用范围，不上传系统指标或画像。

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

发布新版本时，需要使用 Sparkle 的 EdDSA 私钥签名发布包，并把签名后的条目追加到 `appcast.xml`。私钥不得提交到仓库。
