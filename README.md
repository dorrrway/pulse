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

已内置更新器的后续版本会在后台检查更新。检测到新版本时，完整面板底部会显示“更新”按钮，点击后由 Sparkle 下载、验证并安装新版本。`1.0.0` 本身尚未内置更新器，因此从 `1.0.0` 升级到首个内置更新器的版本仍需要手动下载安装一次。

## 系统要求

- 当前工程配置要求 macOS 26.0 或更高版本。
- 支持 Apple Silicon 和 Intel Mac。

## 隐私

Pulse 只读取本机系统指标，例如 CPU、内存、磁盘、网络收发字节计数、电池、热状态和磁盘 I/O。为显示占用排行，Pulse 也会读取本机正在运行进程的名称、CPU/内存占用，以及用于显示 App 图标的本机 App bundle 路径。

Pulse 会请求 GitHub 上的 appcast 以检查新版本，并在用户点击更新时下载发布包。Pulse 不会向任何服务器上传分析数据、遥测数据、文件、个人数据、系统指标或 Sparkle 系统画像。

详情见 [隐私政策](docs/PRIVACY.zh-CN.md)。

## 更新日志

### 未发布

- 设置页在“语言”下新增外观选项，支持跟随系统、浅色模式和深色模式，默认跟随系统。
- 修复外观切换后已打开的菜单面板、独立悬浮面板和设置窗口没有同步更新主题的问题。
- 将面板图钉两态更新为 pinned 系列 18 pt 自定义 PDF template 图标，收起、展开、设置和退出按钮继续使用同尺寸自定义图标，并保持原有按钮尺寸与语义。
- 将完整面板摘要卡片前的圆点标记改为像素块，并移除与内存压力卡片重复的底部内存说明行。
- 简化设置页启动与语言区域：移除冗余分组标题和说明文案，语言选项保留行内标签，常态只保留“开机启动”开关，仅在登录项状态异常时显示提醒。
- 修复设置页面在点击设置项时可能被其他窗口遮住，点击后会置前显示（菜单栏应用场景）。
- 在设置页“语言”行下新增“联系我们”行，放置 Pulse 官网快捷入口图标，可点击跳转网站。
- 将主资源面板刷新频率从 2 秒调整为 1 秒，提升网络速率、CPU、内存和磁盘 I/O 的实时反馈；进程占用排行仍保持较低频率刷新以控制常驻开销。
- 接入 Sparkle 更新器，检测到新版本时在完整面板底部显示更新按钮，点击后下载、验证并安装更新。
- 调整更新按钮为左侧图钉旁的纯文字蓝色按钮，并移除底部“仅监控”状态文案。
- 修复点击图钉打开悬浮面板时可能因为更新状态环境缺失而崩溃的问题。
- 新增 CPU 和内存占用排行，展示本机应用/进程的实时资源占用。
- CPU 和内存占用图扩展为前五项，列表仍保持前三名。
- 占用排行前三名支持显示本机 App 图标。
- 使用像素化占比图展示排行构成。
- 占用排行的像素占比图支持点击打开详情浮层。
- 菜单栏面板改为固定高度，完整承载当前状态布局并取消内部滚动。
- 新增图钉按钮，可将菜单栏面板固定为可拖动的独立悬浮面板。
- 悬浮面板新增极简模式，可从完整面板一键缩小为只显示 CPU、内存、网络和磁盘的紧凑视图。
- 极简悬浮面板在鼠标悬停时显示恢复按钮，可一键展开回完整面板。
- 优化菜单栏和悬浮面板布局，使用固定高度预算并避免状态文字被压缩变小。
- 更新隐私说明，明确进程名称、App bundle 路径及其 CPU、内存占用只用于本机界面展示，并说明更新检查只请求 appcast、不上传系统指标或画像。

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
