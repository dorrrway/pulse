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
  <img alt="release" src="https://img.shields.io/badge/release-v2.2.0-0A84FF">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS-147EFB">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-FA7343">
  <img alt="notarized" src="https://img.shields.io/badge/Developer%20ID-notarized-34C759">
</p>

Pulse 是一款像灵动岛一样停留在屏幕顶部的轻量级 macOS 工具，可快速查看本机状态，并进入资源监控、应用程序和剪贴板历史。

<p align="center">
  <img src="docs/assets/pulse-preview-combined.gif" width="640" alt="Pulse 浅色和深色模式状态面板预览">
</p>

## 下载

最新版本：

- 官网：[timelikesilver.com/apps/pulse](https://timelikesilver.com/apps/pulse)
- [Pulse 2.2.0](https://github.com/dorrrway/pulse/releases/tag/v2.2.0)
- DMG: [Pulse-2.2.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.2.0/Pulse-2.2.0.dmg)

SHA-256：

```text
47aa82f18b1b44af26ed31fa66224bd7f5564a914cc42d7513e0e83b871c86fb  Pulse-2.2.0.dmg
```

## 安装

1. 下载 `Pulse-2.2.0.dmg`。
2. 打开 DMG。
3. 按 DMG 窗口中的中英文提示，将 `Pulse.app` 拖入“应用程序”。
4. 从“应用程序”中启动 Pulse。

应用已使用 Developer ID 签名，并通过 Apple notarization。

本版本已内置更新器，会在后台检查更新。检测到新版本时，完整面板底部会显示“更新”按钮，点击后由 Sparkle 下载、验证并安装新版本。`1.0.0` 本身尚未内置更新器，因此从 `1.0.0` 升级到 `1.1.0` 仍需要手动下载安装一次。

## 系统要求

- 当前工程配置要求 macOS 15.0 或更高版本。
- 支持 Apple Silicon 和 Intel Mac。

## 隐私

Pulse 会读取本机系统指标，例如 CPU、内存、磁盘、网络收发字节计数、电池、热状态、磁盘 I/O 和系统上次启动时间。为显示占用排行，Pulse 也会读取本机正在运行进程的名称、CPU/内存占用，以及用于显示 App 图标的本机 App bundle 路径。为显示“应用程序”列表，Pulse 会读取标准应用位置中的 App 名称、bundle id、版本和 bundle 路径，并读取这些 App 的运行状态；如果用户将 App 加入“常用应用”，Pulse 会在本机保存对应 App bundle 路径。剪贴板模块会读取系统剪贴板变化，并把文本、链接、文件 URL/路径表示、图片、原始 pasteboard 表示、来源 App 线索和敏感/临时 marker 保存在本机历史中；复制文件时 Pulse 不主动读取或保存文件本体内容。敏感内容默认遮罩，但仍可搜索和复制。双击剪贴板记录可在获得 macOS 辅助功能权限后向当前聚焦位置发送一次粘贴快捷键；Pulse 不读取目标 App 的输入内容。OCR 默认关闭，开启后只在本机用 Vision 处理图片文字。

Pulse 会请求 TimeLikeSilver 官网的 appcast 以检查新版本，并在用户点击更新时下载发布包。该更新检查请求可能用于汇总运行趋势，但不会附加文件、个人数据、系统指标、进程列表、应用程序列表、App bundle 路径、持久追踪标识或 Sparkle 系统画像。

详情见 [隐私政策](docs/PRIVACY.zh-CN.md)。

## 更新日志

### 2.2.0 - 2026-05-27

- 扩展系统兼容性：最低系统要求从 macOS 26.0 降至 macOS 15.0；macOS 26 及更新版本继续使用原有剪贴板权限状态和收藏拖出反馈路径。
- 发布包：[Pulse-2.2.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.2.0/Pulse-2.2.0.dmg)；SHA-256：`47aa82f18b1b44af26ed31fa66224bd7f5564a914cc42d7513e0e83b871c86fb`。

### 2.1.0 - 2026-05-27

- 优化常驻状态进入展开状态的过渡：标题区文字、图标和公共操作按钮会在岛体展开后淡入，减少展开瞬间的突兀感。
- 调整展开状态的公共操作区：设置和退出入口移到顶部标题栏右侧，资源监控面板底部只保留与当前面板相关的操作；固定面板的缩小按钮移到右下角。
- 精简资源监控面板：移除面板内部重复的 Pulse 标题、设备名称和像素图标；展开状态中的资源监控面板会在底部显示更新时间，固定面板不再显示时间。
- 优化多显示器体验：灵动岛入口和已固定的资源监控面板会跟随当前显示器，减少在外接屏之间切换时的割裂感。
- 调整展开状态的功能切换：资源监控和应用程序现在横排显示，可点击或在整条功能区左右滑动切换，当前选中的功能始终居中，滑动方向与自然分页一致。
- 首次打开或重新启动后，灵动岛展开时默认进入“应用程序”模块，方便直接启动常用 App。
- 新增“剪贴板”模块：默认记录文本、链接、文件、图片和敏感/临时 marker，历史保存在本机并可按全部/文本/图片/链接/文件筛选、搜索、复制、展开、删除或清空；双击记录可在辅助功能权限允许后直接粘贴到当前聚焦位置；设置中可调整保留条数和保留时间；重复内容会合并为同一条记录，从剪贴板历史中再次复制不会新增历史；敏感项默认遮罩但复制完整原始内容，OCR 默认关闭且仅本机处理。
- 修复部分 App 提供无 BOM UTF-16 剪贴板文本时可能显示乱码的问题；已保存的同类本机历史会在下次启动时自动修正展示文本。
- 设置中新增快捷键区域，可分别设置唤醒剪贴板和唤醒应用程序的全局快捷键；快捷键只保存在本机偏好设置中。
- 快捷键唤醒现在会复用已挂载的灵动岛面板，直接进入目标模块，展开过渡更接近鼠标指向时的自然状态。
- 常驻状态会在剪贴板新增记录时显示 1.5 秒极简提醒，非刘海屏使用内容类型图标、“已复制”和完成对号确认记录已保存，不展开面板也不改变数据读取范围。
- 清空剪贴板历史前会在底部栏内要求确认，避免误点后直接删除全部记录。
- 新增“常用应用”单排面板：应用程序模块默认使用图标视图，可固定常用 App；图标视图支持拖入常用应用，列表视图可通过图钉快速固定或取消固定，常用应用可拖动排序，拖到下方应用区域可移除；正在运行的 App 会在图标下方显示高亮小圆点。
- 在“应用程序”模块中打开 App 后，Pulse 会自动回到常驻状态，减少目标 App 启动后的遮挡。
- 优化常用应用拖拽落位：拖入或排序到两个常用 App 之间时会预留真实落位宽度，减少松手后的跳动感。
- 发布包：[Pulse-2.1.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.1.0/Pulse-2.1.0.dmg)；SHA-256：`fd784f829c28e672fd88f94024ecd9a4fe08ca60492154d632040a9274249017`。

### 2.0.0 - 2026-05-25

- Pulse 现在像灵动岛一样停留在屏幕顶部，作为唯一主入口启动，不再显示菜单栏图标或菜单栏状态面板；设置、更新、固定面板和退出入口保留在展开状态中。
- 新增常驻状态：Pulse 默认贴住屏幕顶部中心，以轻量入口显示内存和 CPU；当 Mac 使用电池或低电量充电且电量小于等于 20% 时，电量也会加入轮播，并用 20%、10% 或充电图标区分状态。
- 指针悬停时进入展开状态，下拉为“资源监控”标题区，并在下方显示完整状态面板。
- 新增提醒状态：当 Mac 使用电池且电量小于等于 10%、温度进入严重高温、磁盘空间极低或内存压力为高时，Pulse 会按优先级临时显示更醒目的两行提醒，并在 3 秒后回到常驻状态；同一连续异常状态只提醒一次。
- 优化常驻状态的轮播动效，指标切换时使用纵向滚动和数字滚动效果，并尊重系统“减少动态效果”设置。
- 展开状态的标题区支持横向功能切换；新增“应用程序”模块，可在列表视图或类似启动台的图标视图中查看标准应用位置的本机 App 并直接打开。
- 修复 MacBook 摄像头区域会遮挡 Pulse 的问题；检测到顶部摄像头缺口时，Pulse 会避开中间不可见区域。
- 发布包：[Pulse-2.0.0.dmg](https://github.com/dorrrway/pulse/releases/download/v2.0.0/Pulse-2.0.0.dmg)；SHA-256：`eb19283e73273f8df1f70e466888aa95f95ef25dec227eaa129a4ca21ac46028`。

### 1.2.0 - 2026-05-15

- 修复“语言 > 跟随系统”在部分 macOS 设置下错误显示英文的问题；现在会按系统首选语言列表匹配 Pulse 支持的语言。
- 修复“外观 > 跟随系统”从浅色或深色模式切回时不会立即刷新已打开窗口的问题。
- 优化 DMG 安装窗口，增加中英文拖拽引导，并固定 Pulse 与“应用程序”的布局。
- 发布包：[Pulse-1.2.0.dmg](https://github.com/dorrrway/pulse/releases/download/v1.2.0/Pulse-1.2.0.dmg)；SHA-256：`4549673b0017257a46326c5f6b91f8833ddd98a386c218bda484c8bac6e45c95`。

### 1.1.4 - 2026-05-14

- 修复固定悬浮面板中“更新”按钮在系统渲染下仍偏灰的问题，保持原有尺寸并显示为更明确的蓝色。
- 设置页底部现在会显示当前 App 版本号。
- 发布包：[Pulse-1.1.4.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.4/Pulse-1.1.4.dmg)；SHA-256：`36147b065eea136d272502bbb09c5d054cafe54c174acd33deb73080a1717d6e`。

### 1.1.3 - 2026-05-14

- 优化完整面板的更新提示：固定悬浮面板中“更新”按钮会位于缩小按钮右侧，并使用更醒目的蓝色背景。
- 发布包：[Pulse-1.1.3.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.3/Pulse-1.1.3.dmg)；SHA-256：`fd8d4116081d4eaad0c03113fd08489b64b855f0d8cb688653cf293e078f82b9`。

### 1.1.2 - 2026-05-14

- 将更新检查源切换到 TimeLikeSilver 官网 appcast 入口，以便通过更新检查汇总运行趋势；请求仍不附加系统指标、文件、进程列表、App bundle 路径、持久追踪标识或 Sparkle 系统画像。
- 优化完整面板的状态点和 CPU 占用排行警示色，高 CPU 应用名称与数值会使用一致的分级颜色。
- 发布包：[Pulse-1.1.2.dmg](https://github.com/dorrrway/pulse/releases/download/v1.1.2/Pulse-1.1.2.dmg)；SHA-256：`aac8429ff0a48e4f44767e95ca9d42a205e13f9138e31016d9d35dfb9a6b0726`。

### 1.1.1 - 2026-05-14

- 调整磁盘 I/O 高活动提示阈值，并在不降低 CPU、内存、网络、磁盘 I/O 实时刷新的前提下降低 Pulse 自身刷新开销。

### 1.1.0 - 2026-05-14

- 新增可固定的悬浮面板与极简模式，可在完整状态面板和简洁指标视图之间切换。
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
