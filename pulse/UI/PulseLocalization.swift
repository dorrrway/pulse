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

    func screenshotModeTitle(_ mode: PulseScreenshotMode) -> String {
        switch mode {
        case .fullScreen:
            text(.screenshotFullScreen)
        case .window:
            text(.screenshotWindow)
        case .selection:
            text(.screenshotSelection)
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

    func islandBatteryLevelTitle() -> String {
        switch language {
        case .english:
            return "Battery"
        case .chinese:
            return "电量"
        }
    }

    func applicationCount(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "1 application" : "\(count) applications"
        case .chinese:
            return "\(count) 个应用程序"
        }
    }

    func clipboardEntryCount(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "1 item" : "\(count) items"
        case .chinese:
            return "\(count) 条记录"
        }
    }

    func clipboardKind(_ kind: ClipboardContentKind) -> String {
        switch (language, kind) {
        case (.english, .text):
            "Text"
        case (.english, .url):
            "Link"
        case (.english, .file):
            "File"
        case (.english, .image):
            "Image"
        case (.english, .mixed):
            "Mixed"
        case (.english, .data):
            "Data"
        case (.chinese, .text):
            "文本"
        case (.chinese, .url):
            "链接"
        case (.chinese, .file):
            "文件"
        case (.chinese, .image):
            "图片"
        case (.chinese, .mixed):
            "混合"
        case (.chinese, .data):
            "数据"
        }
    }

    func clipboardContentFilter(_ filter: ClipboardContentFilter) -> String {
        switch (language, filter) {
        case (.english, .all):
            "All"
        case (.english, .text):
            "Text"
        case (.english, .image):
            "Images"
        case (.english, .url):
            "Links"
        case (.english, .file):
            "Files"
        case (.chinese, .all):
            "全部"
        case (.chinese, .text):
            "文本"
        case (.chinese, .image):
            "图片"
        case (.chinese, .url):
            "链接"
        case (.chinese, .file):
            "文件"
        }
    }

    func clipboardRetentionLimitLabel(_ limit: Int) -> String {
        if limit == ClipboardHistoryStore.unlimitedRetentionLimit {
            switch language {
            case .english:
                return "Unlimited"
            case .chinese:
                return "无限制"
            }
        }

        switch language {
        case .english:
            return "\(limit) items"
        case .chinese:
            return "\(limit) 条"
        }
    }

    func clipboardRetentionDaysLabel(_ days: Int) -> String {
        if days == ClipboardHistoryStore.unlimitedRetentionDays {
            switch language {
            case .english:
                return "Unlimited"
            case .chinese:
                return "无限制"
            }
        }

        switch language {
        case .english:
            return "\(days) days"
        case .chinese:
            return "\(days) 天"
        }
    }

    func installedApplicationSource(_ source: InstalledApplicationSource) -> String {
        switch (language, source) {
        case (.english, .user):
            return "User"
        case (.english, .local):
            return "Applications"
        case (.english, .system):
            return "System"
        case (.chinese, .user):
            return "用户"
        case (.chinese, .local):
            return "应用程序"
        case (.chinese, .system):
            return "系统"
        }
    }

    func openApplicationHelp(_ name: String) -> String {
        switch language {
        case .english:
            return "Open \(name)"
        case .chinese:
            return "打开 \(name)"
        }
    }

    func addFavoriteApplicationHelp(_ name: String) -> String {
        switch language {
        case .english:
            return "Add \(name) to Favorite Apps"
        case .chinese:
            return "将 \(name) 加入常用应用"
        }
    }

    func removeFavoriteApplicationHelp(_ name: String) -> String {
        switch language {
        case .english:
            return "Remove \(name) from Favorite Apps"
        case .chinese:
            return "从常用应用移除 \(name)"
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

    func criticalPowerIslandDetail(_ power: PowerUsage) -> String {
        guard let timeRemaining = power.timeRemaining else {
            return connectPowerSoonText()
        }

        switch language {
        case .english:
            return "About \(compactPowerAlertDuration(timeRemaining)) left · \(connectPowerSoonText())"
        case .chinese:
            return "约剩余 \(compactPowerAlertDuration(timeRemaining)) · \(connectPowerSoonText())"
        }
    }

    func criticalThermalIslandDetail(_ thermal: ThermalUsage) -> String {
        switch language {
        case .english:
            return "Reduce load or improve cooling"
        case .chinese:
            return "建议降低负载或加强散热"
        }
    }

    func criticalDiskIslandDetail(_ disk: DiskUsage) -> String {
        let available = ResourceFormatters.storageByteString(bytes: disk.availableBytes)

        switch language {
        case .english:
            return "\(available) free · Free up storage soon"
        case .chinese:
            return "剩余 \(available) · 请尽快清理空间"
        }
    }

    func criticalMemoryIslandDetail(_ memory: MemoryUsage) -> String {
        switch language {
        case .english:
            return "Close some apps or browser tabs"
        case .chinese:
            return "建议关闭部分 App 或浏览器标签"
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

    private func connectPowerSoonText() -> String {
        switch language {
        case .english:
            return "Connect power soon"
        case .chinese:
            return "请尽快接入电源"
        }
    }

    private func compactPowerAlertDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration.rounded(.down)) / 60, 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch language {
        case .english:
            if hours > 0, minutes > 0 {
                return "\(hours)h \(minutes)m"
            }

            if hours > 0 {
                return "\(hours)h"
            }

            return "\(minutes)m"
        case .chinese:
            if hours > 0, minutes > 0 {
                return "\(hours) 小时 \(minutes) 分钟"
            }

            if hours > 0 {
                return "\(hours) 小时"
            }

            return "\(minutes) 分钟"
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
        case pinPanel
        case unpinPanel
        case minimalPanel
        case expandPanel
        case resourceMonitoring
        case applications
        case clipboard
        case screenshots
        case screenshotCaptured
        case screenshotSaveAction
        case screenshotShareAction
        case screenshotPinAction
        case screenshotUnpinAction
        case screenshotRecognizeTextAction
        case screenshotRecognizingText
        case screenshotNoRecognizedText
        case screenshotRecognizedTextTitle
        case screenshotRecognizedTextDetail
        case screenshotCopyRecognizedText
        case screenshotCloseRecognizedText
        case screenshotTextCopied
        case translation
        case applicationsListView
        case applicationsIconView
        case favoriteApplications
        case favoriteApplicationsEmptyHint
        case applicationRunning
        case refreshApplications
        case noApplicationsFound
        case switchIslandModule
        case topIsland
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
        case clipboardSearchAction
        case clipboardSearchPlaceholder
        case closeClipboardSearch
        case clipboardPermissionTitle
        case clipboardPermissionDetail
        case clipboardEmptyTitle
        case clipboardEmptyDetail
        case clipboardUnknownSource
        case clipboardMaskedValue
        case clipboardOCREnabled
        case clipboardOCRDisabled
        case clearClipboard
        case clearClipboardConfirmation
        case confirmClearClipboard
        case cancelClearClipboard
        case copyClipboardItem
        case pasteClipboardItem
        case revealClipboardItem
        case hideClipboardItem
        case deleteClipboardItem
        case copied
        case clipboardRecorded
        case clipboardPastePermissionTitle
        case clipboardPastePermissionDetail
        case openSystemSettings
        case clipboardSettings
        case clipboardOCR
        case clipboardRetentionLimit
        case clipboardRetentionDays
        case clipboardMarkerConcealed
        case clipboardMarkerTransient
        case clipboardMarkerAutoGenerated
        case clipboardMarkerRemote
        case clipboardMarkerSource
        case clipboardMarkerTemporary
        case translationSourceLanguage
        case translationAutomaticLanguage
        case translationSwapLanguages
        case translationTargetLanguage
        case translationSourceText
        case translationClearText
        case translationInputPlaceholder
        case translationResult
        case translationCopyResult
        case translationOutputPlaceholder
        case translationTranslateAction
        case translationSameLanguage
        case translationReady
        case translationCheckingAvailability
        case translationPreparing
        case translationTranslating
        case translationUnableToDetectLanguage
        case translationUnsupportedLanguagePair
        case shortcutsSettings
        case wakeClipboardShortcut
        case wakeApplicationsShortcut
        case captureFullScreenShortcut
        case captureWindowShortcut
        case captureSelectionShortcut
        case screenshotFullScreen
        case screenshotWindow
        case screenshotSelection
        case shortcutNotSet
        case shortcutRecording
        case clearShortcut
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

#if DEBUG
extension PulseStrings {
    nonisolated func translationLanguageName(_ language: PulseTranslationLanguage) -> String {
        switch language {
        case .chineseSimplified:
            return self.language == .chinese ? "简体中文" : "Chinese (Simplified)"
        case .english:
            return self.language == .chinese ? "英语" : "English"
        case .japanese:
            return self.language == .chinese ? "日语" : "Japanese"
        case .korean:
            return self.language == .chinese ? "韩语" : "Korean"
        case .french:
            return self.language == .chinese ? "法语" : "French"
        case .german:
            return self.language == .chinese ? "德语" : "German"
        case .spanish:
            return self.language == .chinese ? "西班牙语" : "Spanish"
        }
    }

    nonisolated func translationDetectedLanguage(_ identifier: String) -> String {
        switch language {
        case .english:
            "Detected \(identifier)"
        case .chinese:
            "检测到 \(identifier)"
        }
    }

    nonisolated func translationFailureMessage(_ message: String) -> String {
        switch language {
        case .english:
            "Translation failed: \(message)"
        case .chinese:
            "翻译失败：\(message)"
        }
    }
}
#endif

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
        case .pinPanel:
            "Pin panel"
        case .unpinPanel:
            "Unpin panel"
        case .minimalPanel:
            "Minimal panel"
        case .expandPanel:
            "Expand panel"
        case .resourceMonitoring:
            "Resource Monitor"
        case .applications:
            "Applications"
        case .clipboard:
            "Clipboard"
        case .screenshots:
            "Screenshots"
        case .screenshotCaptured:
            "Screenshot"
        case .screenshotSaveAction:
            "Save"
        case .screenshotShareAction:
            "Share"
        case .screenshotPinAction:
            "Pin"
        case .screenshotUnpinAction:
            "Close pinned screenshot"
        case .screenshotRecognizeTextAction:
            "Recognize Text"
        case .screenshotRecognizingText:
            "Recognizing"
        case .screenshotNoRecognizedText:
            "No text"
        case .screenshotRecognizedTextTitle:
            "Recognized Text"
        case .screenshotRecognizedTextDetail:
            "Review the text before copying it to the clipboard."
        case .screenshotCopyRecognizedText:
            "Copy Text"
        case .screenshotCloseRecognizedText:
            "Close"
        case .screenshotTextCopied:
            "Text copied"
        case .translation:
            "Translate"
        case .applicationsListView:
            "List view"
        case .applicationsIconView:
            "Icon view"
        case .favoriteApplications:
            "Favorite Apps"
        case .favoriteApplicationsEmptyHint:
            "Add or drag favorite apps here"
        case .applicationRunning:
            "Running"
        case .refreshApplications:
            "Refresh applications"
        case .noApplicationsFound:
            "No applications found"
        case .switchIslandModule:
            "Switch view"
        case .topIsland:
            "Pulse Dynamic Island-style entry"
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
        case .clipboardSearchAction:
            "Search"
        case .clipboardSearchPlaceholder:
            "Search clipboard"
        case .closeClipboardSearch:
            "Close search"
        case .clipboardPermissionTitle:
            "Clipboard access needed"
        case .clipboardPermissionDetail:
            "Allow Pulse to read the clipboard in macOS privacy settings."
        case .clipboardEmptyTitle:
            "No clipboard items yet"
        case .clipboardEmptyDetail:
            "Copy text, links, files, or images, and they will appear here automatically."
        case .clipboardUnknownSource:
            "Unknown app"
        case .clipboardMaskedValue:
            "Sensitive item hidden"
        case .clipboardOCREnabled:
            "OCR on"
        case .clipboardOCRDisabled:
            "OCR off"
        case .clearClipboard:
            "Clear all"
        case .clearClipboardConfirmation:
            "Clear all clipboard records?"
        case .confirmClearClipboard:
            "Clear"
        case .cancelClearClipboard:
            "Cancel"
        case .copyClipboardItem:
            "Copy item"
        case .pasteClipboardItem:
            "Paste into focused field"
        case .revealClipboardItem:
            "Reveal item"
        case .hideClipboardItem:
            "Hide item"
        case .deleteClipboardItem:
            "Delete item"
        case .copied:
            "Copied"
        case .clipboardRecorded:
            "Saved to clipboard history"
        case .clipboardPastePermissionTitle:
            "Accessibility access needed"
        case .clipboardPastePermissionDetail:
            "Allow Pulse in macOS Accessibility settings to paste into the focused field."
        case .openSystemSettings:
            "Open System Settings"
        case .clipboardSettings:
            "Clipboard"
        case .clipboardOCR:
            "Image OCR"
        case .clipboardRetentionLimit:
            "Entry limit"
        case .clipboardRetentionDays:
            "Keep history"
        case .clipboardMarkerConcealed:
            "Sensitive"
        case .clipboardMarkerTransient:
            "Temporary"
        case .clipboardMarkerAutoGenerated:
            "Generated"
        case .clipboardMarkerRemote:
            "Remote"
        case .clipboardMarkerSource:
            "Source"
        case .clipboardMarkerTemporary:
            "Temporary"
        case .translationSourceLanguage:
            "Source"
        case .translationAutomaticLanguage:
            "Automatic"
        case .translationSwapLanguages:
            "Swap languages"
        case .translationTargetLanguage:
            "Target"
        case .translationSourceText:
            "Source text"
        case .translationClearText:
            "Clear text"
        case .translationInputPlaceholder:
            "Type or paste text to translate"
        case .translationResult:
            "Result"
        case .translationCopyResult:
            "Copy result"
        case .translationOutputPlaceholder:
            "Translation appears here"
        case .translationTranslateAction:
            "Translate"
        case .translationSameLanguage:
            "Choose different languages"
        case .translationReady:
            "Ready"
        case .translationCheckingAvailability:
            "Checking availability"
        case .translationPreparing:
            "Preparing translation"
        case .translationTranslating:
            "Translating"
        case .translationUnableToDetectLanguage:
            "Unable to detect the source language"
        case .translationUnsupportedLanguagePair:
            "This language pair is not supported"
        case .shortcutsSettings:
            "Shortcuts"
        case .wakeClipboardShortcut:
            "Wake Clipboard"
        case .wakeApplicationsShortcut:
            "Wake Applications"
        case .captureFullScreenShortcut:
            "Capture Full Screen"
        case .captureWindowShortcut:
            "Capture Window"
        case .captureSelectionShortcut:
            "Capture Selection"
        case .screenshotFullScreen:
            "Full Screen"
        case .screenshotWindow:
            "Window"
        case .screenshotSelection:
            "Selection"
        case .shortcutNotSet:
            "Not set"
        case .shortcutRecording:
            "Type shortcut"
        case .clearShortcut:
            "Clear shortcut"
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
        case .pinPanel:
            "固定面板"
        case .unpinPanel:
            "取消固定面板"
        case .minimalPanel:
            "极简面板"
        case .expandPanel:
            "展开面板"
        case .resourceMonitoring:
            "资源监控"
        case .applications:
            "应用程序"
        case .clipboard:
            "剪贴板"
        case .screenshots:
            "截图"
        case .screenshotCaptured:
            "截图"
        case .screenshotSaveAction:
            "保存"
        case .screenshotShareAction:
            "分享"
        case .screenshotPinAction:
            "图钉"
        case .screenshotUnpinAction:
            "关闭钉图"
        case .screenshotRecognizeTextAction:
            "识别文字"
        case .screenshotRecognizingText:
            "识别中"
        case .screenshotNoRecognizedText:
            "无文字"
        case .screenshotRecognizedTextTitle:
            "已识别文字"
        case .screenshotRecognizedTextDetail:
            "确认内容后，可选择复制到剪贴板。"
        case .screenshotCopyRecognizedText:
            "复制文字"
        case .screenshotCloseRecognizedText:
            "关闭"
        case .screenshotTextCopied:
            "文字已复制"
        case .translation:
            "翻译"
        case .applicationsListView:
            "列表视图"
        case .applicationsIconView:
            "图标视图"
        case .favoriteApplications:
            "常用应用"
        case .favoriteApplicationsEmptyHint:
            "添加、拖拽常用软件到此处"
        case .applicationRunning:
            "正在运行"
        case .refreshApplications:
            "刷新应用程序"
        case .noApplicationsFound:
            "未找到应用程序"
        case .switchIslandModule:
            "切换功能"
        case .topIsland:
            "Pulse 灵动岛入口"
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
        case .clipboardSearchAction:
            "搜索"
        case .clipboardSearchPlaceholder:
            "搜索剪贴板"
        case .closeClipboardSearch:
            "关闭搜索"
        case .clipboardPermissionTitle:
            "需要剪贴板访问权限"
        case .clipboardPermissionDetail:
            "请在 macOS 隐私设置中允许 Pulse 读取剪贴板。"
        case .clipboardEmptyTitle:
            "还没有剪贴板记录"
        case .clipboardEmptyDetail:
            "复制文本、链接、文件或图片后，记录会自动出现在这里。"
        case .clipboardUnknownSource:
            "未知 App"
        case .clipboardMaskedValue:
            "敏感内容已隐藏"
        case .clipboardOCREnabled:
            "OCR 已开"
        case .clipboardOCRDisabled:
            "OCR 未开"
        case .clearClipboard:
            "全部清空"
        case .clearClipboardConfirmation:
            "确定清空所有剪贴板记录吗？"
        case .confirmClearClipboard:
            "确定"
        case .cancelClearClipboard:
            "取消"
        case .copyClipboardItem:
            "复制记录"
        case .pasteClipboardItem:
            "粘贴到当前焦点"
        case .revealClipboardItem:
            "显示内容"
        case .hideClipboardItem:
            "隐藏内容"
        case .deleteClipboardItem:
            "删除记录"
        case .copied:
            "已复制"
        case .clipboardRecorded:
            "已记录到剪贴板历史"
        case .clipboardPastePermissionTitle:
            "需要辅助功能权限"
        case .clipboardPastePermissionDetail:
            "请在 macOS 辅助功能设置中允许 Pulse，才能粘贴到当前聚焦位置。"
        case .openSystemSettings:
            "打开系统设置"
        case .clipboardSettings:
            "剪贴板"
        case .clipboardOCR:
            "图片 OCR"
        case .clipboardRetentionLimit:
            "保留条数"
        case .clipboardRetentionDays:
            "保留时间"
        case .clipboardMarkerConcealed:
            "敏感"
        case .clipboardMarkerTransient:
            "临时"
        case .clipboardMarkerAutoGenerated:
            "自动生成"
        case .clipboardMarkerRemote:
            "跨设备"
        case .clipboardMarkerSource:
            "来源"
        case .clipboardMarkerTemporary:
            "临时"
        case .translationSourceLanguage:
            "源语言"
        case .translationAutomaticLanguage:
            "自动"
        case .translationSwapLanguages:
            "交换语言"
        case .translationTargetLanguage:
            "目标语言"
        case .translationSourceText:
            "原文"
        case .translationClearText:
            "清空文本"
        case .translationInputPlaceholder:
            "输入或粘贴要翻译的文本"
        case .translationResult:
            "译文"
        case .translationCopyResult:
            "复制译文"
        case .translationOutputPlaceholder:
            "翻译结果会显示在这里"
        case .translationTranslateAction:
            "翻译"
        case .translationSameLanguage:
            "请选择不同的语言"
        case .translationReady:
            "已就绪"
        case .translationCheckingAvailability:
            "正在检查可用性"
        case .translationPreparing:
            "正在准备翻译"
        case .translationTranslating:
            "正在翻译"
        case .translationUnableToDetectLanguage:
            "无法识别源语言"
        case .translationUnsupportedLanguagePair:
            "当前语言组合暂不支持"
        case .shortcutsSettings:
            "快捷键"
        case .wakeClipboardShortcut:
            "唤醒剪贴板"
        case .wakeApplicationsShortcut:
            "唤醒应用程序"
        case .captureFullScreenShortcut:
            "全屏截图"
        case .captureWindowShortcut:
            "窗口截图"
        case .captureSelectionShortcut:
            "区域截图"
        case .screenshotFullScreen:
            "全屏"
        case .screenshotWindow:
            "窗口"
        case .screenshotSelection:
            "自定义区域"
        case .shortcutNotSet:
            "未设置"
        case .shortcutRecording:
            "输入快捷键"
        case .clearShortcut:
            "清除快捷键"
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
