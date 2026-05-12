import XCTest
@testable import pulse

final class ResourceFormattingTests: XCTestCase {
    func testFormatsPercentagesWithClamping() {
        XCTAssertEqual(ResourceFormatters.percentage(0.427), "43%")
        XCTAssertEqual(ResourceFormatters.percentage(2), "100%")
        XCTAssertEqual(ResourceFormatters.percentage(-1), "0%")
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

}
