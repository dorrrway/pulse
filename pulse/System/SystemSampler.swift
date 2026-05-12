import Darwin
import Foundation
import IOKit
import IOKit.ps

actor SystemSampler {
    private var previousCPUTicks: [UInt64]?
    private var previousNetworkCounters: NetworkCounters?
    private var previousDiskIOCounters: DiskIOCounters?
    private var previousSampleDate: Date?
    private var previousThermalCondition: ThermalCondition?
    private var thermalConditionStartedAt: Date?

    func sample() -> ResourceSnapshot {
        let now = Date()
        let interval = previousSampleDate.map { now.timeIntervalSince($0) } ?? 0
        let networkCounters = currentNetworkCounters()
        let diskIOCounters = currentDiskIOCounters()
        let network = networkCounters.usage(since: previousNetworkCounters, interval: interval)
        let diskIO = diskIOCounters.usage(since: previousDiskIOCounters, interval: interval)

        previousNetworkCounters = networkCounters
        previousDiskIOCounters = diskIOCounters
        previousSampleDate = now

        return ResourceSnapshot(
            capturedAt: now,
            cpu: currentCPUUsage(),
            memory: currentMemoryUsage(),
            network: network,
            disk: currentDiskUsage(),
            thermal: currentThermalUsage(at: now),
            power: currentPowerUsage(),
            diskIO: diskIO
        )
    }

    private func currentCPUUsage() -> CPUUsage {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return .empty
        }

        let ticks = withUnsafeBytes(of: info.cpu_ticks) { buffer in
            Array(buffer.bindMemory(to: natural_t.self)).map(UInt64.init)
        }

        defer {
            previousCPUTicks = ticks
        }

        guard
            ticks.count > CPU_STATE_IDLE,
            let previousCPUTicks,
            previousCPUTicks.count == ticks.count
        else {
            return CPUUsage(percentage: 0, coreCount: ProcessInfo.processInfo.processorCount)
        }

        let deltas = zip(ticks, previousCPUTicks).map { current, previous in
            current >= previous ? current - previous : 0
        }
        let total = deltas.reduce(0, +)

        guard total > 0 else {
            return CPUUsage(percentage: 0, coreCount: ProcessInfo.processInfo.processorCount)
        }

        let idle = deltas[Int(CPU_STATE_IDLE)]
        let busy = total > idle ? total - idle : 0

        return CPUUsage(
            percentage: Double(busy) / Double(total),
            coreCount: ProcessInfo.processInfo.processorCount
        )
    }

    private func currentMemoryUsage() -> MemoryUsage {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return .empty
        }

        var pageSize = vm_size_t()
        host_page_size(mach_host_self(), &pageSize)

        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        let pageBytes = Int64(pageSize)
        let wired = Int64(stats.wire_count) * pageBytes
        let active = Int64(stats.active_count) * pageBytes
        let compressed = Int64(stats.compressor_page_count) * pageBytes
        let used = min(max(wired + active + compressed, 0), total)
        let swap = currentSwapUsage()

        return MemoryUsage(
            totalBytes: total,
            usedBytes: used,
            availableBytes: max(total - used, 0),
            compressedBytes: max(compressed, 0),
            swapUsedBytes: swap.usedBytes,
            swapTotalBytes: swap.totalBytes
        )
    }

    private func currentNetworkCounters() -> NetworkCounters {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
            return .empty
        }

        defer {
            freeifaddrs(interfaceAddresses)
        }

        var received: UInt64 = 0
        var sent: UInt64 = 0

        for pointer in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee

            guard
                let address = interface.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                (interface.ifa_flags & UInt32(IFF_UP)) != 0,
                (interface.ifa_flags & UInt32(IFF_LOOPBACK)) == 0,
                let dataPointer = interface.ifa_data
            else {
                continue
            }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(data.ifi_ibytes)
            sent += UInt64(data.ifi_obytes)
        }

        return NetworkCounters(receivedBytes: received, sentBytes: sent)
    }

    private func currentDiskUsage() -> DiskUsage {
        let rootURL = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]

        guard let values = try? rootURL.resourceValues(forKeys: keys) else {
            return .empty
        }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)

        return DiskUsage(totalBytes: total, availableBytes: available)
    }

    private func currentThermalUsage(at date: Date) -> ThermalUsage {
        let condition: ThermalCondition

        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            condition = .nominal
        case .fair:
            condition = .fair
        case .serious:
            condition = .serious
        case .critical:
            condition = .critical
        @unknown default:
            condition = .nominal
        }

        if previousThermalCondition != condition || thermalConditionStartedAt == nil {
            previousThermalCondition = condition
            thermalConditionStartedAt = date
        }

        return ThermalUsage(
            condition: condition,
            stateDuration: date.timeIntervalSince(thermalConditionStartedAt ?? date)
        )
    }

    private func currentPowerUsage() -> PowerUsage {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
            !sources.isEmpty
        else {
            return .empty
        }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else {
                continue
            }

            let currentCapacity = description[kIOPSCurrentCapacityKey] as? Double
                ?? (description[kIOPSCurrentCapacityKey] as? Int).map(Double.init)
            let maxCapacity = description[kIOPSMaxCapacityKey] as? Double
                ?? (description[kIOPSMaxCapacityKey] as? Int).map(Double.init)
            let percentage = if let currentCapacity, let maxCapacity, maxCapacity > 0 {
                min(max(currentCapacity / maxCapacity, 0), 1)
            } else {
                Optional<Double>.none
            }
            let state = description[kIOPSPowerSourceStateKey] as? String
            let minutesRemaining = description[kIOPSTimeToEmptyKey] as? Double
                ?? (description[kIOPSTimeToEmptyKey] as? Int).map(Double.init)
            let timeRemaining: TimeInterval? = if let minutesRemaining, minutesRemaining > 0 {
                minutesRemaining * 60
            } else {
                nil
            }

            return PowerUsage(
                hasBattery: true,
                batteryPercentage: percentage,
                isPluggedIn: state == kIOPSACPowerValue,
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                timeRemaining: timeRemaining
            )
        }

        return .empty
    }

    private func currentDiskIOCounters() -> DiskIOCounters {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            return .empty
        }

        var iterator = io_iterator_t()

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .empty
        }

        defer {
            IOObjectRelease(iterator)
        }

        var readBytes: UInt64 = 0
        var writtenBytes: UInt64 = 0
        var service = IOIteratorNext(iterator)

        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard
                let retained = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0),
                let statistics = retained.takeRetainedValue() as? [String: Any]
            else {
                continue
            }

            readBytes += uint64Value(statistics["Bytes (Read)"])
            writtenBytes += uint64Value(statistics["Bytes (Write)"])
        }

        return DiskIOCounters(readBytes: readBytes, writtenBytes: writtenBytes)
    }

    private func currentSwapUsage() -> (usedBytes: Int64, totalBytes: Int64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride

        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else {
            return (0, 0)
        }

        return (Int64(usage.xsu_used), Int64(usage.xsu_total))
    }

    private func uint64Value(_ value: Any?) -> UInt64 {
        switch value {
        case let number as UInt64:
            number
        case let number as Int64:
            UInt64(max(number, 0))
        case let number as Int:
            UInt64(max(number, 0))
        case let number as NSNumber:
            number.uint64Value
        default:
            0
        }
    }
}
