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

}
