import Foundation

nonisolated enum PulseLanguagePreference: String, Sendable {
    case system
    case english
    case chinese

    var resolvedLanguage: PulseLanguage {
        switch self {
        case .system:
            PulseLanguage.systemResolved
        case .english:
            .english
        case .chinese:
            .chinese
        }
    }
}

nonisolated enum PulseLanguage: Sendable {
    case english
    case chinese

    static var systemResolved: PulseLanguage {
        resolveSystemLanguage(
            preferredLanguages: Locale.preferredLanguages,
            fallbackLanguageCode: Locale.autoupdatingCurrent.language.languageCode?.identifier
        )
    }

    static func resolveSystemLanguage(
        preferredLanguages: [String],
        fallbackLanguageCode: String?
    ) -> PulseLanguage {
        for languageIdentifier in preferredLanguages {
            switch normalizedLanguageCode(from: languageIdentifier) {
            case "zh":
                return .chinese
            case "en":
                return .english
            default:
                continue
            }
        }

        return fallbackLanguageCode?.lowercased() == "zh" ? .chinese : .english
    }

    private static func normalizedLanguageCode(from identifier: String) -> String? {
        Locale(identifier: identifier)
            .language
            .languageCode?
            .identifier
            .lowercased()
    }
}

nonisolated struct PulseStrings: Sendable {
    var language: PulseLanguage

    func text(_ key: Key) -> String {
        switch language {
        case .english:
            englishText(for: key)
        case .chinese:
            chineseText(for: key)
        }
    }

    func cores(_ count: Int) -> String {
        switch language {
        case .english:
            return "\(count) cores"
        case .chinese:
            return "\(count) 核"
        }
    }

    func memoryDetail(used: String, total: String) -> String {
        switch language {
        case .english:
            return "\(used) / \(total)"
        case .chinese:
            return "\(used) / 共 \(total)"
        }
    }

    func networkUploadDetail(rate: String) -> String {
        switch language {
        case .english:
            return "up \(rate)"
        case .chinese:
            return "上行 \(rate)"
        }
    }

    func diskFreeDetail(_ free: String) -> String {
        switch language {
        case .english:
            return "\(free) free"
        case .chinese:
            return "剩余 \(free)"
        }
    }

    func pressure(_ level: PressureLevel) -> String {
        switch (language, level) {
        case (.english, .nominal):
            "OK"
        case (.english, .elevated):
            "Watch"
        case (.english, .high):
            "High"
        case (.chinese, .nominal):
            "正常"
        case (.chinese, .elevated):
            "偏高"
        case (.chinese, .high):
            "高"
        }
    }

    func pressureDetail(_ memory: MemoryUsage) -> String {
        let swap = ResourceFormatters.byteString(bytes: memory.swapUsedBytes)
        let compressed = ResourceFormatters.byteString(bytes: memory.compressedBytes)

        switch language {
        case .english:
            return "\(text(.swap)) \(swap) · Comp \(compressed)"
        case .chinese:
            return "\(text(.swap)) \(swap) · \(text(.compressed)) \(compressed)"
        }
    }

    func pressureExplanation(_ memory: MemoryUsage) -> String {
        let usage = ResourceFormatters.percentage(memory.percentage)
        let swap = ResourceFormatters.byteString(bytes: memory.swapUsedBytes)
        let compressed = ResourceFormatters.byteString(bytes: memory.compressedBytes)

        switch (language, memory.pressureLevel) {
        case (.english, .nominal):
            return "Normal: \(usage) used, with low swap and compression."
        case (.english, .elevated):
            return "Watch: \(usage) used, swap \(swap), compressed \(compressed)."
        case (.english, .high):
            return "High: \(usage) used, swap \(swap), compressed \(compressed)."
        case (.chinese, .nominal):
            return "正常：已用 \(usage)，Swap 和压缩内存都很低。"
        case (.chinese, .elevated):
            return "偏高：已用 \(usage)，Swap \(swap)，压缩 \(compressed)。"
        case (.chinese, .high):
            return "高：已用 \(usage)，Swap \(swap)，压缩 \(compressed)。"
        }
    }

    func thermal(_ condition: ThermalCondition) -> String {
        switch (language, condition) {
        case (.english, .nominal):
            "Normal"
        case (.english, .fair):
            "Warm"
        case (.english, .serious):
            "Hot"
        case (.english, .critical):
            "Very Hot"
        case (.chinese, .nominal):
            "正常"
        case (.chinese, .fair):
            "偏热"
        case (.chinese, .serious):
            "高温"
        case (.chinese, .critical):
            "严重高温"
        }
    }

    func thermalDetail(_ thermal: ThermalUsage) -> String {
        let duration = max(thermal.stateDuration, 0)

        switch (language, thermal.condition, duration < 10) {
        case (.english, .nominal, true):
            return "Temperature stable"
        case (.english, .fair, true):
            return "Body warm"
        case (.english, .serious, true):
            return "Temperature high"
        case (.english, .critical, true):
            return "Temperature too high"
        case (.chinese, .nominal, true):
            return "温度稳定"
        case (.chinese, .fair, true):
            return "机身偏热"
        case (.chinese, .serious, true):
            return "温度较高"
        case (.chinese, .critical, true):
            return "温度过高"
        case (.english, .nominal, false):
            return "Stable for \(compactDuration(duration))"
        case (.english, .fair, false):
            return "Warm for \(compactDuration(duration))"
        case (.english, .serious, false):
            return "Hot for \(compactDuration(duration))"
        case (.english, .critical, false):
            return "Very hot for \(compactDuration(duration))"
        case (.chinese, .nominal, false):
            return "持续稳定 \(compactDuration(duration))"
        case (.chinese, .fair, false):
            return "持续偏热 \(compactDuration(duration))"
        case (.chinese, .serious, false):
            return "持续高温 \(compactDuration(duration))"
        case (.chinese, .critical, false):
            return "持续严重高温 \(compactDuration(duration))"
        }
    }

    func thermalExplanation(_ thermal: ThermalUsage) -> String {
        switch language {
        case .english:
            return "\(self.thermal(thermal.condition)): \(thermalDetail(thermal))."
        case .chinese:
            return "\(self.thermal(thermal.condition))：\(thermalDetail(thermal))。"
        }
    }

    func powerTitle(_ power: PowerUsage) -> String {
        guard power.hasBattery else {
            return text(.noBattery)
        }

        if let batteryPercentage = power.batteryPercentage {
            return ResourceFormatters.percentage(batteryPercentage)
        }

        return text(.battery)
    }

    func powerDetail(_ power: PowerUsage) -> String {
        guard power.hasBattery else {
            return text(.desktopPower)
        }

        if power.isCharging {
            return text(.charging)
        }

        if !power.isPluggedIn, let timeRemaining = power.timeRemaining {
            return remainingPowerTime(timeRemaining)
        }

        return power.isPluggedIn ? text(.pluggedIn) : text(.onBattery)
    }

    func powerExplanation(_ power: PowerUsage) -> String {
        guard power.hasBattery else {
            switch language {
            case .english:
                return "Desktop power: this Mac has no internal battery."
            case .chinese:
                return "桌面电源：这台 Mac 没有内置电池。"
            }
        }

        let percentage = power.batteryPercentage.map(ResourceFormatters.percentage)

        switch (language, power.isPluggedIn, power.isCharging, percentage, power.timeRemaining) {
        case (.english, true, true, let percentage?, _):
            return "Charging: battery \(percentage), external power connected."
        case (.english, true, true, nil, _):
            return "Charging: external power connected."
        case (.english, true, false, let percentage?, _):
            return "External power: battery \(percentage), not charging."
        case (.english, true, false, nil, _):
            return "External power connected."
        case (.english, false, _, let percentage?, let timeRemaining?):
            return "On battery: \(percentage), \(remainingPowerTime(timeRemaining))."
        case (.english, false, _, let percentage?, nil):
            return "On battery: \(percentage) remaining."
        case (.english, false, _, nil, _):
            return "On battery: remaining time unavailable."
        case (.chinese, true, true, let percentage?, _):
            return "充电中：电量 \(percentage)，已连接外接电源。"
        case (.chinese, true, true, nil, _):
            return "充电中：已连接外接电源。"
        case (.chinese, true, false, let percentage?, _):
            return "外接电源：电量 \(percentage)，当前未充电。"
        case (.chinese, true, false, nil, _):
            return "外接电源：已连接外接电源。"
        case (.chinese, false, _, let percentage?, let timeRemaining?):
            return "使用电池：电量 \(percentage)，\(remainingPowerTime(timeRemaining))。"
        case (.chinese, false, _, let percentage?, nil):
            return "使用电池：剩余电量 \(percentage)。"
        case (.chinese, false, _, nil, _):
            return "使用电池：系统暂未提供剩余电量或时间。"
        }
    }

    func diskIOExplanation(_ diskIO: DiskIOUsage) -> String {
        let read = ResourceFormatters.byteRate(bytesPerSecond: diskIO.readBytesPerSecond)
        let write = ResourceFormatters.byteRate(bytesPerSecond: diskIO.writeBytesPerSecond)

        switch language {
        case .english:
            return "Disk I/O: read \(read), write \(write)."
        case .chinese:
            return "磁盘 I/O：读取 \(read)，写入 \(write)。"
        }
    }

    func runtimeSummary(_ runtime: SystemRuntimeUsage) -> String {
        let duration = longDuration(runtime.elapsedTime)

        guard let bootedAt = runtime.bootedAt else {
            switch language {
            case .english:
                return "Runtime unavailable"
            case .chinese:
                return "开机时长暂不可用"
            }
        }

        switch language {
        case .english:
            return "Running \(duration) · Last boot: \(formattedBootDate(bootedAt))"
        case .chinese:
            return "持续运行：\(duration) · 上次开机：\(formattedBootDate(bootedAt))"
        }
    }

    func loginItemStatus(_ status: PulseLoginItemStatus) -> String {
        switch (language, status) {
        case (.english, .enabled):
            "Enabled"
        case (.english, .notRegistered):
            "Not registered"
        case (.english, .notFound):
            "Not found"
        case (.english, .requiresApproval):
            "Requires approval"
        case (.english, .unknown):
            "Unknown"
        case (.chinese, .enabled):
            "已开启"
        case (.chinese, .notRegistered):
            "未注册"
        case (.chinese, .notFound):
            "未找到"
        case (.chinese, .requiresApproval):
            "需要系统批准"
        case (.chinese, .unknown):
            "未知"
        }
    }

    func loginItemError(_ error: PulseLoginItemError) -> String {
        switch (language, error) {
        case (.english, .requiresInstalledApplication):
            "Install Pulse in /Applications or ~/Applications before enabling launch at login."
        case (.chinese, .requiresInstalledApplication):
            "请先将 Pulse 安装到 /Applications 或 ~/Applications，再开启开机启动。"
        case (_, .serviceError(let message)):
            message
        }
    }

    func updateButtonTitle() -> String {
        switch language {
        case .english:
            "Update"
        case .chinese:
            "更新"
        }
    }

    func updateButtonHelp(version: String) -> String {
        switch language {
        case .english:
            "Install Pulse \(version)"
        case .chinese:
            "安装 Pulse \(version)"
        }
    }

    private func remainingPowerTime(_ timeRemaining: TimeInterval) -> String {
        let totalMinutes = max(Int(timeRemaining.rounded(.down)) / 60, 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch language {
        case .english:
            if hours > 0 {
                return "\(hours)h \(minutes)m left"
            }

            return "\(minutes)m left"
        case .chinese:
            if hours > 0 {
                return "剩余 \(hours) 小时 \(minutes) 分"
            }

            return "剩余 \(minutes) 分"
        }
    }

    private func compactDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded(.down)), 0)

        if totalSeconds < 60 {
            switch language {
            case .english:
                return "\(totalSeconds) sec"
            case .chinese:
                return "\(totalSeconds) 秒"
            }
        }

        let totalMinutes = totalSeconds / 60
        if totalMinutes < 60 {
            switch language {
            case .english:
                return "\(totalMinutes) min"
            case .chinese:
                return "\(totalMinutes) 分钟"
            }
        }

        let hours = totalMinutes / 60
        switch language {
        case .english:
            return "\(hours) hr"
        case .chinese:
            return "\(hours) 小时"
        }
    }

    private func longDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration.rounded(.down)) / 60, 0)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        switch language {
        case .english:
            if days > 0 {
                return "\(days)d \(hours)h"
            }

            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }

            return "\(max(minutes, 1))m"
        case .chinese:
            if days > 0 {
                return "\(days)天\(hours)小时"
            }

            if hours > 0 {
                return "\(hours)小时\(minutes)分"
            }

            return "\(max(minutes, 1))分钟"
        }
    }

    private func formattedBootDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .english ? "en_US" : "zh_CN")
        formatter.dateFormat = language == .english ? "MMM d, HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

extension PulseStrings {
    enum Key: Sendable {
        case cpu
        case memory
        case network
        case disk
        case thisMac
        case monitorOnly
        case pinPanel
        case unpinPanel
        case minimalPanel
        case expandPanel
        case settings
        case settingsHelp
        case quit
        case quitHelp
        case memoryPressure
        case swap
        case compressed
        case thermal
        case power
        case battery
        case noBattery
        case desktopPower
        case charging
        case pluggedIn
        case onBattery
        case diskIO
        case read
        case write
        case systemRuntime
        case topCPUProcesses
        case topMemoryProcesses
        case collecting
        case language
        case languageDescription
        case appearance
        case lightMode
        case darkMode
        case contactUs
        case pulseWebsite
        case startup
        case launchAtLogin
        case launchAtLoginDescription
        case loginItemStatus
        case followSystem
        case english
        case chinese
        case appVersion
        case pulseSettings
    }
}

private extension PulseStrings {
    nonisolated func englishText(for key: Key) -> String {
        switch key {
        case .cpu:
            "CPU"
        case .memory:
            "Memory"
        case .network:
            "Network"
        case .disk:
            "Disk"
        case .thisMac:
            "This Mac"
        case .monitorOnly:
            "Monitoring only"
        case .pinPanel:
            "Pin panel"
        case .unpinPanel:
            "Unpin panel"
        case .minimalPanel:
            "Minimal panel"
        case .expandPanel:
            "Expand panel"
        case .settings:
            "Settings"
        case .settingsHelp:
            "Open Pulse settings"
        case .quit:
            "Quit"
        case .quitHelp:
            "Quit Pulse"
        case .memoryPressure:
            "Memory Pressure"
        case .swap:
            "Swap"
        case .compressed:
            "Compressed"
        case .thermal:
            "Thermal"
        case .power:
            "Power"
        case .battery:
            "Battery"
        case .noBattery:
            "No battery"
        case .desktopPower:
            "Desktop power"
        case .charging:
            "Charging"
        case .pluggedIn:
            "External power"
        case .onBattery:
            "On battery"
        case .diskIO:
            "Disk I/O"
        case .read:
            "Read"
        case .write:
            "Write"
        case .systemRuntime:
            "System Runtime"
        case .topCPUProcesses:
            "CPU Usage (Multi-core)"
        case .topMemoryProcesses:
            "Memory Usage"
        case .collecting:
            "Collecting"
        case .language:
            "Language"
        case .languageDescription:
            "Choose the language Pulse uses in its menu and settings."
        case .appearance:
            "Appearance"
        case .lightMode:
            "Light"
        case .darkMode:
            "Dark"
        case .contactUs:
            "Contact"
        case .pulseWebsite:
            "Pulse Website"
        case .startup:
            "Startup"
        case .launchAtLogin:
            "Open at login"
        case .launchAtLoginDescription:
            "Keep Pulse available after you sign in to macOS."
        case .loginItemStatus:
            "Login item"
        case .followSystem:
            "System"
        case .english:
            "English"
        case .chinese:
            "中文"
        case .appVersion:
            "Version"
        case .pulseSettings:
            "Pulse Settings"
        }
    }

    nonisolated func chineseText(for key: Key) -> String {
        switch key {
        case .cpu:
            "CPU"
        case .memory:
            "内存"
        case .network:
            "网络"
        case .disk:
            "磁盘"
        case .thisMac:
            "这台 Mac"
        case .monitorOnly:
            "仅监控"
        case .pinPanel:
            "固定面板"
        case .unpinPanel:
            "取消固定面板"
        case .minimalPanel:
            "极简面板"
        case .expandPanel:
            "展开面板"
        case .settings:
            "设置"
        case .settingsHelp:
            "打开 Pulse 设置"
        case .quit:
            "退出"
        case .quitHelp:
            "退出 Pulse"
        case .memoryPressure:
            "内存压力"
        case .swap:
            "Swap"
        case .compressed:
            "压缩"
        case .thermal:
            "温度"
        case .power:
            "电源"
        case .battery:
            "电池"
        case .noBattery:
            "无电池"
        case .desktopPower:
            "桌面电源"
        case .charging:
            "充电中"
        case .pluggedIn:
            "外接电源"
        case .onBattery:
            "使用电池"
        case .diskIO:
            "磁盘 I/O"
        case .read:
            "读取"
        case .write:
            "写入"
        case .systemRuntime:
            "开机时长"
        case .topCPUProcesses:
            "CPU 占用（多核）"
        case .topMemoryProcesses:
            "内存占用"
        case .collecting:
            "采集中"
        case .language:
            "语言"
        case .languageDescription:
            "选择 Pulse 菜单和设置使用的语言。"
        case .appearance:
            "外观"
        case .lightMode:
            "浅色模式"
        case .darkMode:
            "深色模式"
        case .contactUs:
            "联系我们"
        case .pulseWebsite:
            "Pulse 官网"
        case .startup:
            "启动"
        case .launchAtLogin:
            "开机启动"
        case .launchAtLoginDescription:
            "登录 macOS 后自动保持 Pulse 可用。"
        case .loginItemStatus:
            "登录项"
        case .followSystem:
            "跟随系统"
        case .english:
            "English"
        case .chinese:
            "中文"
        case .appVersion:
            "版本"
        case .pulseSettings:
            "Pulse 设置"
        }
    }
}
