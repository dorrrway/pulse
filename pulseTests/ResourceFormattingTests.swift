import XCTest
@testable import pulse

final class ResourceFormattingTests: XCTestCase {
    func testFormatsPercentagesWithClamping() {
        XCTAssertEqual(ResourceFormatters.percentage(0.427), "43%")
        XCTAssertEqual(ResourceFormatters.percentage(2), "100%")
        XCTAssertEqual(ResourceFormatters.percentage(-1), "0%")
    }

    func testFormatsProcessPercentagesWithLowUsagePrecision() {
        XCTAssertEqual(ResourceFormatters.processPercentage(0.004), "0.4%")
        XCTAssertEqual(ResourceFormatters.processPercentage(0.083), "8.3%")
        XCTAssertEqual(ResourceFormatters.processPercentage(1.25), "125%")
        XCTAssertEqual(ResourceFormatters.processPercentage(-1), "0.0%")
    }

    func testFormatsByteValues() {
        XCTAssertEqual(ResourceFormatters.byteString(bytes: 0), "0 B")
        XCTAssertEqual(ResourceFormatters.byteString(bytes: 512), "512 B")
        XCTAssertEqual(ResourceFormatters.byteString(bytes: 1_536), "1.5 KB")
        XCTAssertEqual(ResourceFormatters.byteString(bytes: 10 * 1024 * 1024), "10 MB")
    }

    func testFormatsStorageValuesWithDecimalUnits() {
        XCTAssertEqual(ResourceFormatters.storageByteString(bytes: 188_100_000_000), "188 GB")
        XCTAssertEqual(ResourceFormatters.storageByteString(bytes: 494_380_000_000), "494 GB")
    }

    func testNetworkCounterDeltaUsesElapsedInterval() {
        let previous = NetworkCounters(receivedBytes: 1_000, sentBytes: 2_000)
        let current = NetworkCounters(receivedBytes: 2_000, sentBytes: 2_500)

        let usage = current.usage(since: previous, interval: 2)

        XCTAssertEqual(usage.incomingBytesPerSecond, 500)
        XCTAssertEqual(usage.outgoingBytesPerSecond, 250)
        XCTAssertEqual(usage.totalReceivedBytes, 2_000)
        XCTAssertEqual(usage.totalSentBytes, 2_500)
    }

    func testNetworkActivityProgressUsesLogarithmicScale() {
        XCTAssertEqual(ResourceScales.networkActivityProgress(bytesPerSecond: -1), 0)
        XCTAssertEqual(ResourceScales.networkActivityProgress(bytesPerSecond: 0), 0)

        let fiveMegabytes = ResourceScales.networkActivityProgress(bytesPerSecond: 5 * 1024 * 1024)
        let fiftyMegabytes = ResourceScales.networkActivityProgress(bytesPerSecond: 50 * 1024 * 1024)
        let maximum = ResourceScales.networkActivityProgress(bytesPerSecond: 100 * 1024 * 1024)
        let beyondMaximum = ResourceScales.networkActivityProgress(bytesPerSecond: 250 * 1024 * 1024)

        XCTAssertEqual(fiveMegabytes, 0.51, accuracy: 0.01)
        XCTAssertEqual(fiftyMegabytes, 0.88, accuracy: 0.01)
        XCTAssertEqual(maximum, 1, accuracy: 0.0001)
        XCTAssertEqual(beyondMaximum, 1, accuracy: 0.0001)
    }

    func testDiskIOCounterDeltaUsesElapsedInterval() {
        let previous = DiskIOCounters(readBytes: 10_000, writtenBytes: 20_000)
        let current = DiskIOCounters(readBytes: 14_000, writtenBytes: 21_000)

        let usage = current.usage(since: previous, interval: 2)

        XCTAssertEqual(usage.readBytesPerSecond, 2_000)
        XCTAssertEqual(usage.writeBytesPerSecond, 500)
        XCTAssertEqual(usage.totalReadBytes, 14_000)
        XCTAssertEqual(usage.totalWrittenBytes, 21_000)
    }

    func testDiskUsageDerivesUsedBytesAndPercentage() {
        let usage = DiskUsage(totalBytes: 1_000, availableBytes: 250)

        XCTAssertEqual(usage.usedBytes, 750)
        XCTAssertEqual(usage.percentage, 0.75)
    }

    func testMemoryPressureUsesSwapAndCompressionSignals() {
        let nominal = MemoryUsage(
            totalBytes: 10_000,
            usedBytes: 4_000,
            availableBytes: 6_000,
            compressedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: 0
        )
        let elevated = MemoryUsage(
            totalBytes: 10_000,
            usedBytes: 5_000,
            availableBytes: 5_000,
            compressedBytes: 1_000,
            swapUsedBytes: 0,
            swapTotalBytes: 0
        )
        let high = MemoryUsage(
            totalBytes: 10_000,
            usedBytes: 5_000,
            availableBytes: 5_000,
            compressedBytes: 2_500,
            swapUsedBytes: 0,
            swapTotalBytes: 0
        )

        XCTAssertEqual(nominal.pressureLevel, .nominal)
        XCTAssertEqual(elevated.pressureLevel, .elevated)
        XCTAssertEqual(high.pressureLevel, .high)
    }

    func testProcessSnapshotKeepsTopFiveByCPUAndMemory() {
        let snapshot = ProcessResourceSnapshot(usages: [
            ProcessResourceUsage(identifier: "a", name: "Alpha", cpuPercentage: 0.04, memoryBytes: 400),
            ProcessResourceUsage(identifier: "b", name: "Beta", cpuPercentage: 0.08, memoryBytes: 200),
            ProcessResourceUsage(identifier: "c", name: "Charlie", cpuPercentage: 0.02, memoryBytes: 900),
            ProcessResourceUsage(identifier: "d", name: "Delta", cpuPercentage: 0.12, memoryBytes: 100),
            ProcessResourceUsage(identifier: "e", name: "Echo", cpuPercentage: 0, memoryBytes: 700),
            ProcessResourceUsage(identifier: "f", name: "Foxtrot", cpuPercentage: 0.03, memoryBytes: 500),
        ])

        XCTAssertEqual(snapshot.topCPU.map(\.name), ["Delta", "Beta", "Alpha", "Foxtrot", "Charlie"])
        XCTAssertEqual(snapshot.topMemory.map(\.name), ["Charlie", "Echo", "Foxtrot", "Alpha", "Beta"])
    }

    func testProcessCPUTimebaseConvertsMachTimeToSeconds() {
        let timebase = ProcessCPUTimebase(numer: 125, denom: 3)

        XCTAssertEqual(timebase.seconds(fromMachAbsoluteTime: 24_000_000), 1, accuracy: 0.0001)
    }

    func testProcessSnapshotResolvesAppIdentityOnlyForTopCandidates() {
        let samples = [
            ProcessSample(
                identity: ProcessIdentity(pid: 101, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "App Main",
                cpuTime: 6_000_000_000,
                residentBytes: 400
            ),
            ProcessSample(
                identity: ProcessIdentity(pid: 102, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "App Helper",
                cpuTime: 3_000_000_000,
                residentBytes: 500
            ),
            ProcessSample(
                identity: ProcessIdentity(pid: 103, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "Background 1",
                cpuTime: 1_000_000_000,
                residentBytes: 100
            ),
            ProcessSample(
                identity: ProcessIdentity(pid: 104, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "Background 2",
                cpuTime: 900_000_000,
                residentBytes: 90
            ),
            ProcessSample(
                identity: ProcessIdentity(pid: 105, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "Background 3",
                cpuTime: 800_000_000,
                residentBytes: 80
            ),
            ProcessSample(
                identity: ProcessIdentity(pid: 106, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "Background 4",
                cpuTime: 700_000_000,
                residentBytes: 70
            ),
            ProcessSample(
                identity: ProcessIdentity(pid: 107, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "Background 5",
                cpuTime: 600_000_000,
                residentBytes: 60
            ),
            ProcessSample(
                identity: ProcessIdentity(pid: 108, startSeconds: 1, startMicroseconds: 0),
                fallbackName: "Background 6",
                cpuTime: 500_000_000,
                residentBytes: 50
            ),
        ]
        let previousCPUTime = samples.reduce(into: [ProcessIdentity: UInt64]()) { result, sample in
            result[sample.identity] = 0
        }
        var resolvedPIDs: [pid_t] = []

        let snapshot = SystemSampler.processResourceSnapshot(
            samples: samples,
            previousCPUTime: previousCPUTime,
            interval: 6,
            timebase: ProcessCPUTimebase(numer: 1, denom: 1),
            candidateLimit: 5
        ) { sample in
            resolvedPIDs.append(sample.identity.pid)

            if sample.identity.pid == 101 || sample.identity.pid == 102 {
                return ProcessAppIdentity(
                    identifier: "bundle:com.example.app",
                    name: "Example App",
                    appBundlePath: "/Applications/Example.app"
                )
            }

            return ProcessAppIdentity(
                identifier: "process:\(sample.fallbackName)",
                name: sample.fallbackName,
                appBundlePath: nil
            )
        }

        XCTAssertEqual(resolvedPIDs.sorted(), [101, 102, 103, 104, 105])
        XCTAssertEqual(snapshot.topCPU.first?.identifier, "bundle:com.example.app")
        XCTAssertEqual(snapshot.topCPU.first?.name, "Example App")
        XCTAssertEqual(snapshot.topCPU.first?.appBundlePath, "/Applications/Example.app")
        XCTAssertEqual(snapshot.topCPU.first?.cpuPercentage ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.topMemory.first?.memoryBytes, 900)
    }

    func testStoreSkipsPublishingCoreMetricsWhenVisibleValuesDoNotChange() {
        let previous = CoreMetricsSnapshot(
            cpu: CPUUsage(percentage: 0.421, coreCount: 10),
            memory: MemoryUsage(
                totalBytes: 10_000,
                usedBytes: 4_210,
                availableBytes: 5_790,
                compressedBytes: 0,
                swapUsedBytes: 0,
                swapTotalBytes: 0
            ),
            network: NetworkUsage(
                incomingBytesPerSecond: 1_000.2,
                outgoingBytesPerSecond: 2_000.2,
                totalReceivedBytes: 0,
                totalSentBytes: 0
            ),
            disk: DiskUsage(totalBytes: 100_000_000_000, availableBytes: 51_000_000_000)
        )
        let next = CoreMetricsSnapshot(
            cpu: CPUUsage(percentage: 0.424, coreCount: 10),
            memory: MemoryUsage(
                totalBytes: 10_000,
                usedBytes: 4_240,
                availableBytes: 5_760,
                compressedBytes: 0,
                swapUsedBytes: 0,
                swapTotalBytes: 0
            ),
            network: NetworkUsage(
                incomingBytesPerSecond: 1_000.8,
                outgoingBytesPerSecond: 2_000.8,
                totalReceivedBytes: 0,
                totalSentBytes: 0
            ),
            disk: DiskUsage(totalBytes: 100_000_000_000, availableBytes: 51_000_000_000)
        )

        XCTAssertFalse(PulseStore.shouldPublishCoreMetrics(previous: previous, next: next))
    }

    func testStorePublishesCoreMetricsWhenVisibleValuesChange() {
        let previous = CoreMetricsSnapshot(
            cpu: CPUUsage(percentage: 0.421, coreCount: 10),
            memory: .empty,
            network: .empty,
            disk: .empty
        )
        let next = CoreMetricsSnapshot(
            cpu: CPUUsage(percentage: 0.435, coreCount: 10),
            memory: .empty,
            network: .empty,
            disk: .empty
        )

        XCTAssertTrue(PulseStore.shouldPublishCoreMetrics(previous: previous, next: next))
    }

    func testStoreSkipsPublishingSignalMetricsWhenVisibleValuesDoNotChange() {
        let previous = SignalMetricsSnapshot(
            memory: MemoryUsage(
                totalBytes: 10_000,
                usedBytes: 4_210,
                availableBytes: 5_790,
                compressedBytes: 200,
                swapUsedBytes: 100,
                swapTotalBytes: 1_000
            ),
            thermal: ThermalUsage(condition: .nominal, stateDuration: 65),
            power: PowerUsage(
                hasBattery: true,
                batteryPercentage: 0.821,
                isPluggedIn: false,
                isCharging: false,
                timeRemaining: 3_630
            ),
            diskIO: DiskIOUsage(
                readBytesPerSecond: 1_000.2,
                writeBytesPerSecond: 2_000.2,
                totalReadBytes: 0,
                totalWrittenBytes: 0
            ),
            runtime: SystemRuntimeUsage(
                bootedAt: Date(timeIntervalSince1970: 1_777_777_777),
                elapsedTime: 3_600
            )
        )
        let next = SignalMetricsSnapshot(
            memory: MemoryUsage(
                totalBytes: 10_000,
                usedBytes: 4_240,
                availableBytes: 5_760,
                compressedBytes: 200,
                swapUsedBytes: 100,
                swapTotalBytes: 1_000
            ),
            thermal: ThermalUsage(condition: .nominal, stateDuration: 80),
            power: PowerUsage(
                hasBattery: true,
                batteryPercentage: 0.824,
                isPluggedIn: false,
                isCharging: false,
                timeRemaining: 3_650
            ),
            diskIO: DiskIOUsage(
                readBytesPerSecond: 1_000.8,
                writeBytesPerSecond: 2_000.8,
                totalReadBytes: 0,
                totalWrittenBytes: 0
            ),
            runtime: SystemRuntimeUsage(
                bootedAt: Date(timeIntervalSince1970: 1_777_777_777),
                elapsedTime: 3_630
            )
        )

        XCTAssertFalse(PulseStore.shouldPublishSignalMetrics(previous: previous, next: next))
    }

    func testStorePublishesCapturedAtOnlyWhenDisplayedMinuteChanges() {
        let previous = Date(timeIntervalSince1970: 120)
        let sameMinute = Date(timeIntervalSince1970: 179)
        let nextMinute = Date(timeIntervalSince1970: 180)

        XCTAssertFalse(PulseStore.shouldPublishCapturedAt(previous: previous, next: sameMinute))
        XCTAssertTrue(PulseStore.shouldPublishCapturedAt(previous: previous, next: nextMinute))
    }

}
