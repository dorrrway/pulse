import Foundation

nonisolated struct CPUUsage: Equatable, Sendable {
    var percentage: Double
    var coreCount: Int

    static let empty = CPUUsage(percentage: 0, coreCount: ProcessInfo.processInfo.processorCount)
}

nonisolated struct MemoryUsage: Equatable, Sendable {
    var totalBytes: Int64
    var usedBytes: Int64
    var availableBytes: Int64
    var compressedBytes: Int64
    var swapUsedBytes: Int64
    var swapTotalBytes: Int64

    var percentage: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    var pressureLevel: PressureLevel {
        let compressedRatio = totalBytes > 0 ? Double(compressedBytes) / Double(totalBytes) : 0

        if percentage >= 0.9 || swapUsedBytes >= 2_147_483_648 || compressedRatio >= 0.2 {
            return .high
        }

        if percentage >= 0.8 || swapUsedBytes >= 536_870_912 || compressedRatio >= 0.1 {
            return .elevated
        }

        return .nominal
    }

    static let empty = MemoryUsage(
        totalBytes: 0,
        usedBytes: 0,
        availableBytes: 0,
        compressedBytes: 0,
        swapUsedBytes: 0,
        swapTotalBytes: 0
    )
}

nonisolated struct NetworkUsage: Equatable, Sendable {
    var incomingBytesPerSecond: Double
    var outgoingBytesPerSecond: Double
    var totalReceivedBytes: UInt64
    var totalSentBytes: UInt64

    static let empty = NetworkUsage(
        incomingBytesPerSecond: 0,
        outgoingBytesPerSecond: 0,
        totalReceivedBytes: 0,
        totalSentBytes: 0
    )
}

nonisolated struct DiskUsage: Equatable, Sendable {
    var totalBytes: Int64
    var availableBytes: Int64

    var usedBytes: Int64 {
        max(totalBytes - availableBytes, 0)
    }

    var percentage: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    static let empty = DiskUsage(totalBytes: 0, availableBytes: 0)
}

nonisolated enum PressureLevel: Equatable, Sendable {
    case nominal
    case elevated
    case high
}

nonisolated enum ThermalCondition: Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

nonisolated struct ThermalUsage: Equatable, Sendable {
    var condition: ThermalCondition
    var stateDuration: TimeInterval

    static let empty = ThermalUsage(condition: .nominal, stateDuration: 0)
}

nonisolated struct PowerUsage: Equatable, Sendable {
    var hasBattery: Bool
    var batteryPercentage: Double?
    var isPluggedIn: Bool
    var isCharging: Bool
    var timeRemaining: TimeInterval?

    static let empty = PowerUsage(
        hasBattery: false,
        batteryPercentage: nil,
        isPluggedIn: true,
        isCharging: false,
        timeRemaining: nil
    )
}

nonisolated struct DiskIOUsage: Equatable, Sendable {
    var readBytesPerSecond: Double
    var writeBytesPerSecond: Double
    var totalReadBytes: UInt64
    var totalWrittenBytes: UInt64

    static let empty = DiskIOUsage(
        readBytesPerSecond: 0,
        writeBytesPerSecond: 0,
        totalReadBytes: 0,
        totalWrittenBytes: 0
    )
}

nonisolated struct ProcessResourceUsage: Equatable, Identifiable, Sendable {
    var identifier: String
    var name: String
    var appBundlePath: String?
    var cpuPercentage: Double
    var memoryBytes: Int64

    var id: String {
        identifier
    }
}

nonisolated struct ProcessResourceSnapshot: Equatable, Sendable {
    private static let processLimit = 5

    var topCPU: [ProcessResourceUsage]
    var topMemory: [ProcessResourceUsage]

    init(topCPU: [ProcessResourceUsage], topMemory: [ProcessResourceUsage]) {
        self.topCPU = topCPU
        self.topMemory = topMemory
    }

    init(usages: [ProcessResourceUsage]) {
        self.topCPU = usages
            .filter { $0.cpuPercentage > 0 }
            .sorted { lhs, rhs in
                if lhs.cpuPercentage == rhs.cpuPercentage {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

                return lhs.cpuPercentage > rhs.cpuPercentage
            }
            .prefix(Self.processLimit)
            .map(\.self)
        self.topMemory = usages
            .filter { $0.memoryBytes > 0 }
            .sorted { lhs, rhs in
                if lhs.memoryBytes == rhs.memoryBytes {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

                return lhs.memoryBytes > rhs.memoryBytes
            }
            .prefix(Self.processLimit)
            .map(\.self)
    }

    static let empty = ProcessResourceSnapshot(topCPU: [], topMemory: [])
}

nonisolated struct ResourceSnapshot: Equatable, Sendable {
    var capturedAt: Date
    var cpu: CPUUsage
    var memory: MemoryUsage
    var network: NetworkUsage
    var disk: DiskUsage
    var thermal: ThermalUsage
    var power: PowerUsage
    var diskIO: DiskIOUsage
    var processes: ProcessResourceSnapshot

    static let empty = ResourceSnapshot(
        capturedAt: .distantPast,
        cpu: .empty,
        memory: .empty,
        network: .empty,
        disk: .empty,
        thermal: .empty,
        power: .empty,
        diskIO: .empty,
        processes: .empty
    )
}

nonisolated struct NetworkCounters: Equatable, Sendable {
    var receivedBytes: UInt64
    var sentBytes: UInt64

    static let empty = NetworkCounters(receivedBytes: 0, sentBytes: 0)

    func usage(since previous: NetworkCounters?, interval: TimeInterval) -> NetworkUsage {
        guard
            let previous,
            interval > 0,
            receivedBytes >= previous.receivedBytes,
            sentBytes >= previous.sentBytes
        else {
            return NetworkUsage(
                incomingBytesPerSecond: 0,
                outgoingBytesPerSecond: 0,
                totalReceivedBytes: receivedBytes,
                totalSentBytes: sentBytes
            )
        }

        return NetworkUsage(
            incomingBytesPerSecond: Double(receivedBytes - previous.receivedBytes) / interval,
            outgoingBytesPerSecond: Double(sentBytes - previous.sentBytes) / interval,
            totalReceivedBytes: receivedBytes,
            totalSentBytes: sentBytes
        )
    }
}

nonisolated struct DiskIOCounters: Equatable, Sendable {
    var readBytes: UInt64
    var writtenBytes: UInt64

    static let empty = DiskIOCounters(readBytes: 0, writtenBytes: 0)

    func usage(since previous: DiskIOCounters?, interval: TimeInterval) -> DiskIOUsage {
        guard
            let previous,
            interval > 0,
            readBytes >= previous.readBytes,
            writtenBytes >= previous.writtenBytes
        else {
            return DiskIOUsage(
                readBytesPerSecond: 0,
                writeBytesPerSecond: 0,
                totalReadBytes: readBytes,
                totalWrittenBytes: writtenBytes
            )
        }

        return DiskIOUsage(
            readBytesPerSecond: Double(readBytes - previous.readBytes) / interval,
            writeBytesPerSecond: Double(writtenBytes - previous.writtenBytes) / interval,
            totalReadBytes: readBytes,
            totalWrittenBytes: writtenBytes
        )
    }
}

nonisolated enum ResourceFormatters {
    static func percentage(_ value: Double) -> String {
        String(format: "%.0f%%", min(max(value, 0), 1) * 100)
    }

    static func processPercentage(_ value: Double) -> String {
        let percentage = max(value, 0) * 100

        if percentage < 10 {
            return String(format: "%.1f%%", percentage)
        }

        return String(format: "%.0f%%", percentage)
    }

    static func byteString(bytes: Int64) -> String {
        formattedBytes(bytes: bytes, divisor: 1024)
    }

    static func storageByteString(bytes: Int64) -> String {
        formattedBytes(bytes: bytes, divisor: 1000)
    }

    private static func formattedBytes(bytes: Int64, divisor: Double) -> String {
        guard bytes > 0 else { return "0 B" }

        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= divisor, unitIndex < units.count - 1 {
            value /= divisor
            unitIndex += 1
        }

        if value >= 10 || unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    static func byteRate(bytesPerSecond: Double) -> String {
        byteString(bytes: Int64(max(bytesPerSecond, 0))) + "/s"
    }
}

nonisolated enum ResourceScales {
    private static let networkMaximumBytesPerSecond = 100.0 * 1024.0 * 1024.0
    private static let networkKneeBytesPerSecond = 256.0 * 1024.0

    static func networkActivityProgress(bytesPerSecond: Double) -> Double {
        let rate = min(max(bytesPerSecond, 0), networkMaximumBytesPerSecond)
        let numerator = log1p(rate / networkKneeBytesPerSecond)
        let denominator = log1p(networkMaximumBytesPerSecond / networkKneeBytesPerSecond)

        return numerator / denominator
    }
}
