import Darwin
import Foundation
import IOKit
import IOKit.ps

actor SystemSampler {
    private let processPathBufferSize = 4096
    private let processSampleInterval: TimeInterval = 6
    private let processCPUTimebase = ProcessCPUTimebase.current

    private var previousCPUTicks: [UInt64]?
    private var previousNetworkCounters: NetworkCounters?
    private var previousDiskIOCounters: DiskIOCounters?
    private var previousSampleDate: Date?
    private var previousProcessSampleDate: Date?
    private var previousProcessCPUTime: [ProcessIdentity: UInt64] = [:]
    private var processAppIdentityCache: [ProcessIdentity: ProcessAppIdentity] = [:]
    private var latestProcessSnapshot: ProcessResourceSnapshot = .empty
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
        let processes = currentProcessUsageIfNeeded(at: now)

        return ResourceSnapshot(
            capturedAt: now,
            cpu: currentCPUUsage(),
            memory: currentMemoryUsage(),
            network: network,
            disk: currentDiskUsage(),
            thermal: currentThermalUsage(at: now),
            power: currentPowerUsage(),
            diskIO: diskIO,
            processes: processes
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

    private func currentProcessUsageIfNeeded(at date: Date) -> ProcessResourceSnapshot {
        guard let previousDate = previousProcessSampleDate else {
            previousProcessSampleDate = date
            primeProcessCPUTime()
            return latestProcessSnapshot
        }

        let interval = date.timeIntervalSince(previousDate)
        guard interval >= processSampleInterval else {
            return latestProcessSnapshot
        }

        previousProcessSampleDate = date
        latestProcessSnapshot = currentProcessUsage(interval: interval)
        return latestProcessSnapshot
    }

    private func primeProcessCPUTime() {
        let samples = currentProcessSamples()
        previousProcessCPUTime = samples.reduce(into: [ProcessIdentity: UInt64]()) { cpuTimes, sample in
            cpuTimes[sample.identity] = sample.cpuTime
        }
        let liveIdentities = Set(previousProcessCPUTime.keys)
        processAppIdentityCache = processAppIdentityCache.filter { identity, _ in
            liveIdentities.contains(identity)
        }
        latestProcessSnapshot = ProcessResourceSnapshot(
            topCPU: [],
            topMemory: processUsages(samples: samples, previousCPUTime: [:], interval: 0).topMemory
        )
    }

    private func currentProcessUsage(interval: TimeInterval) -> ProcessResourceSnapshot {
        let samples = currentProcessSamples()
        let previousCPUTime = previousProcessCPUTime

        previousProcessCPUTime = samples.reduce(into: [ProcessIdentity: UInt64]()) { cpuTimes, sample in
            cpuTimes[sample.identity] = sample.cpuTime
        }
        let liveIdentities = Set(previousProcessCPUTime.keys)
        processAppIdentityCache = processAppIdentityCache.filter { identity, _ in
            liveIdentities.contains(identity)
        }

        return processUsages(samples: samples, previousCPUTime: previousCPUTime, interval: interval)
    }

    private func processUsages(
        samples: [ProcessSample],
        previousCPUTime: [ProcessIdentity: UInt64],
        interval: TimeInterval
    ) -> ProcessResourceSnapshot {
        let usages = samples
            .reduce(into: [String: ProcessResourceAccumulator]()) { accumulators, sample in
                let cpuPercentage: Double
                if
                    interval > 0,
                    let previous = previousCPUTime[sample.identity],
                    sample.cpuTime >= previous
                {
                    let usedSeconds = processCPUTimebase.seconds(fromMachAbsoluteTime: sample.cpuTime - previous)
                    cpuPercentage = max(usedSeconds / interval, 0)
                } else {
                    cpuPercentage = 0
                }

                accumulators[sample.groupIdentifier, default: ProcessResourceAccumulator(
                    identifier: sample.groupIdentifier,
                    name: sample.displayName,
                    appBundlePath: sample.appBundlePath
                )].add(cpuPercentage: cpuPercentage, memoryBytes: sample.residentBytes)
            }
            .values
            .map(\.usage)

        return ProcessResourceSnapshot(usages: usages)
    }

    private func currentProcessSamples() -> [ProcessSample] {
        processIdentifiers().compactMap(processSample(pid:))
    }

    private func processIdentifiers() -> [pid_t] {
        var capacity = max(Int(proc_listallpids(nil, 0)), 512)

        for _ in 0..<3 {
            var pids = [pid_t](repeating: 0, count: capacity)
            let count = pids.withUnsafeMutableBufferPointer { buffer in
                proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.stride))
            }

            guard count > 0 else {
                return []
            }

            if count < capacity {
                return Array(pids.prefix(Int(count))).filter { $0 > 0 }
            }

            capacity *= 2
        }

        return []
    }

    private func processSample(pid: pid_t) -> ProcessSample? {
        var taskInfo = proc_taskinfo()
        let taskInfoSize = MemoryLayout<proc_taskinfo>.stride
        let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(taskInfoSize))

        guard taskResult == taskInfoSize else {
            return nil
        }

        var bsdInfo = proc_bsdinfo()
        let bsdInfoSize = MemoryLayout<proc_bsdinfo>.stride
        let bsdResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(bsdInfoSize))

        guard bsdResult == bsdInfoSize else {
            return nil
        }

        let fallbackName = processName(pid: pid) ?? "Process \(pid)"
        let identity = ProcessIdentity(
            pid: pid,
            startSeconds: bsdInfo.pbi_start_tvsec,
            startMicroseconds: bsdInfo.pbi_start_tvusec
        )
        let appIdentity: ProcessAppIdentity

        if let cachedIdentity = processAppIdentityCache[identity] {
            appIdentity = cachedIdentity
        } else {
            appIdentity = processAppIdentity(path: processPath(pid: pid), fallbackName: fallbackName)
            processAppIdentityCache[identity] = appIdentity
        }

        let cpuTime = taskInfo.pti_total_user.addingReportingOverflow(taskInfo.pti_total_system)

        return ProcessSample(
            identity: identity,
            groupIdentifier: appIdentity.identifier,
            displayName: appIdentity.name,
            appBundlePath: appIdentity.appBundlePath,
            cpuTime: cpuTime.overflow ? taskInfo.pti_total_user : cpuTime.partialValue,
            residentBytes: Int64(clamping: taskInfo.pti_resident_size)
        )
    }

    private func processName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: processPathBufferSize)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_name(pid, pointer.baseAddress, UInt32(pointer.count))
        }

        guard length > 0 else {
            return nil
        }

        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private func processPath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: processPathBufferSize)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_pidpath(pid, pointer.baseAddress, UInt32(pointer.count))
        }

        guard length > 0 else {
            return nil
        }

        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private func processAppIdentity(path: String?, fallbackName: String) -> ProcessAppIdentity {
        guard
            let path,
            let appURL = appBundleURL(containing: path),
            let bundle = Bundle(url: appURL)
        else {
            return ProcessAppIdentity(identifier: "process:\(fallbackName)", name: fallbackName, appBundlePath: nil)
        }

        let identifier = bundle.bundleIdentifier ?? appURL.path
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.nonEmpty
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?.nonEmpty
            ?? appURL.deletingPathExtension().lastPathComponent

        return ProcessAppIdentity(
            identifier: "bundle:\(identifier)",
            name: name,
            appBundlePath: appURL.standardizedFileURL.path
        )
    }

    private func appBundleURL(containing processPath: String) -> URL? {
        let components = URL(fileURLWithPath: processPath).pathComponents

        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }

        let bundlePath = NSString.path(withComponents: Array(components.prefix(through: appIndex)))
        return URL(fileURLWithPath: bundlePath)
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

private nonisolated struct ProcessIdentity: Hashable {
    var pid: pid_t
    var startSeconds: UInt64
    var startMicroseconds: UInt64
}

private nonisolated struct ProcessAppIdentity {
    var identifier: String
    var name: String
    var appBundlePath: String?
}

private nonisolated struct ProcessSample {
    var identity: ProcessIdentity
    var groupIdentifier: String
    var displayName: String
    var appBundlePath: String?
    var cpuTime: UInt64
    var residentBytes: Int64
}

nonisolated struct ProcessCPUTimebase: Equatable, Sendable {
    var numer: UInt32
    var denom: UInt32

    static var current: ProcessCPUTimebase {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)

        return ProcessCPUTimebase(numer: info.numer, denom: info.denom)
    }

    func seconds(fromMachAbsoluteTime ticks: UInt64) -> Double {
        guard denom > 0 else {
            return 0
        }

        return Double(ticks) * Double(numer) / Double(denom) / Double(NSEC_PER_SEC)
    }
}

private nonisolated struct ProcessResourceAccumulator {
    var identifier: String
    var name: String
    var appBundlePath: String?
    var cpuPercentage: Double = 0
    var memoryBytes: Int64 = 0

    mutating func add(cpuPercentage: Double, memoryBytes: Int64) {
        self.cpuPercentage += cpuPercentage
        self.memoryBytes += max(memoryBytes, 0)
    }

    var usage: ProcessResourceUsage {
        ProcessResourceUsage(
            identifier: identifier,
            name: name,
            appBundlePath: appBundlePath,
            cpuPercentage: cpuPercentage,
            memoryBytes: memoryBytes
        )
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
