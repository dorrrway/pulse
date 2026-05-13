# 隐私政策

<h3 align="center">
  <a href="../README.md">README</a> |
  <a href="PRIVACY.zh-CN.md">中文</a> |
  <a href="PRIVACY.en.md">English</a>
</h3>

最后更新：2026 年 5 月 13 日

Pulse 是一款本地运行的 macOS 菜单栏工具，用于展示当前 Mac 的系统状态。

## Pulse 会读取的数据

Pulse 可能会读取以下本机系统指标：

- CPU 使用情况
- 内存使用情况
- 磁盘容量与磁盘 I/O 计数
- 网络收发字节计数
- 电池状态
- 热状态
- 正在运行进程的名称及其 CPU、内存占用
- 用于显示 App 图标的本机 App bundle 路径

这些数据只用于显示应用界面，不会上传或用于持久追踪。

## Pulse 不会收集的数据

Pulse 不会收集、存储或传输：

- 个人文件
- 通讯录、照片、日历、定位或剪贴板数据
- 密码、凭据或钥匙串内容
- 分析数据或遥测数据
- 设备序列号或持久追踪标识

## 网络使用

Pulse 会通过 HTTPS 请求 GitHub 上的 appcast 文件，用于检查是否存在新版本；当用户点击更新时，Pulse 会下载对应发布包并由 Sparkle 验证签名后安装。

Pulse 不会向任何服务器发送应用分析、遥测数据、系统指标或 Sparkle 系统画像。更新检查不会附加 CPU、内存、设备型号、进程列表、App bundle 路径或其他本机监控数据。

## 本地偏好设置

Pulse 可能会使用 macOS 本地存储保存语言、开机启动等偏好设置。
