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
        let languageCode = Locale.autoupdatingCurrent.language.languageCode?.identifier.lowercased()

        return languageCode == "zh" ? .chinese : .english
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
            "注意"
        case (.chinese, .high):
            "偏高"
        }
    }

    func pressureDetail(_ memory: MemoryUsage) -> String {
        let swap = ResourceFormatters.byteString(bytes: memory.swapUsedBytes)
        let compressed = ResourceFormatters.byteString(bytes: memory.compressedBytes)

        switch language {
        case .english:
            return "\(text(.swap)) \(swap) · \(text(.compressed)) \(compressed)"
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
            return "注意：已用 \(usage)，Swap \(swap)，压缩 \(compressed)。"
        case (.chinese, .high):
            return "偏高：已用 \(usage)，Swap \(swap)，压缩 \(compressed)。"
        }
    }

    func thermal(_ condition: ThermalCondition) -> String {
        switch (language, condition) {
        case (.english, .nominal):
            "Cool"
        case (.english, .fair):
            "Warm"
        case (.english, .serious):
            "Limited"
        case (.english, .critical):
            "Critical"
        case (.chinese, .nominal):
            "正常"
        case (.chinese, .fair):
            "变热"
        case (.chinese, .serious):
            "受限"
        case (.chinese, .critical):
            "严重"
        }
    }

    func thermalDetail(_ thermal: ThermalUsage) -> String {
        let duration = max(thermal.stateDuration, 0)

        switch (language, thermal.condition, duration < 10) {
        case (.english, .nominal, true):
            return "Just stable"
        case (.english, .fair, true):
            return "Just warm"
        case (.english, .serious, true):
            return "Just limited"
        case (.english, .critical, true):
            return "Just critically limited"
        case (.chinese, .nominal, true):
            return "稳定中"
        case (.chinese, .fair, true):
            return "变热中"
        case (.chinese, .serious, true):
            return "受限中"
        case (.chinese, .critical, true):
            return "严重受限中"
        case (.english, .nominal, false):
            return "Stable for \(compactDuration(duration))"
        case (.english, .fair, false):
            return "Warm for \(compactDuration(duration))"
        case (.english, .serious, false):
            return "Limited for \(compactDuration(duration))"
        case (.english, .critical, false):
            return "Critically limited for \(compactDuration(duration))"
        case (.chinese, .nominal, false):
            return "持续稳定 \(compactDuration(duration))"
        case (.chinese, .fair, false):
            return "持续变热 \(compactDuration(duration))"
        case (.chinese, .serious, false):
            return "持续受限 \(compactDuration(duration))"
        case (.chinese, .critical, false):
            return "严重受限 \(compactDuration(duration))"
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
            "请先将 Pulse 安装到 /Applications 或 ~/Applications，再开启登录时打开。"
        case (_, .serviceError(let message)):
            message
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
}

extension PulseStrings {
    enum Key: Sendable {
        case cpu
        case memory
        case network
        case disk
        case thisMac
        case monitorOnly
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
        case topCPUProcesses
        case topMemoryProcesses
        case collecting
        case language
        case languageDescription
        case startup
        case launchAtLogin
        case launchAtLoginDescription
        case loginItemStatus
        case followSystem
        case english
        case chinese
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
            "Plugged in"
        case .onBattery:
            "On battery"
        case .diskIO:
            "Disk I/O"
        case .read:
            "Read"
        case .write:
            "Write"
        case .topCPUProcesses:
            "CPU Usage"
        case .topMemoryProcesses:
            "Memory Usage"
        case .collecting:
            "Collecting"
        case .language:
            "Language"
        case .languageDescription:
            "Choose the language Pulse uses in its menu and settings."
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
            "已接电"
        case .onBattery:
            "使用电池"
        case .diskIO:
            "磁盘 I/O"
        case .read:
            "读取"
        case .write:
            "写入"
        case .topCPUProcesses:
            "CPU 占用"
        case .topMemoryProcesses:
            "内存占用"
        case .collecting:
            "采集中"
        case .language:
            "语言"
        case .languageDescription:
            "选择 Pulse 菜单和设置使用的语言。"
        case .startup:
            "启动"
        case .launchAtLogin:
            "登录时打开"
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
        case .pulseSettings:
            "Pulse 设置"
        }
    }
}
