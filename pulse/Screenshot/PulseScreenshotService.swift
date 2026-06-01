import AppKit
import AVFoundation
import CoreGraphics
import CoreMedia
import Darwin
import Foundation
import ScreenCaptureKit

nonisolated enum PulseScreenshotMode: CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case fullScreen
    case window
    case selection

    var id: Self {
        self
    }

    var shortcutAction: PulseShortcutAction {
        switch self {
        case .fullScreen:
            .captureFullScreen
        case .window:
            .captureWindow
        case .selection:
            .captureSelection
        }
    }

    var screenRecordingShortcutAction: PulseShortcutAction {
        switch self {
        case .fullScreen:
            .recordFullScreen
        case .window:
            .recordWindow
        case .selection:
            .recordSelection
        }
    }

    nonisolated var iconAssetName: String {
        switch self {
        case .fullScreen:
            "ScreenshotFullScreenIcon"
        case .window:
            "ScreenshotWindowIcon"
        case .selection:
            "ScreenshotSelectionIcon"
        }
    }

    nonisolated var screenRecordingIconAssetName: String {
        switch self {
        case .fullScreen:
            "ScreenRecordingFullScreenIcon"
        case .window:
            "ScreenRecordingWindowIcon"
        case .selection:
            "ScreenRecordingSelectionIcon"
        }
    }
}

nonisolated enum PulseScreenshotCaptureResult: Equatable, Sendable {
    case copiedToClipboard
    case permissionDenied
    case cancelled
    case failed
}

struct PulseScreenshotService: Sendable {
    var preflightAccess: @Sendable () -> Bool
    var requestAccess: @Sendable () -> Bool
    var openScreenCaptureSettings: @MainActor @Sendable () -> Void
    var capture: @Sendable (PulseScreenshotMode) async -> PulseScreenshotCaptureResult

    static let live = PulseScreenshotService(
        preflightAccess: {
            CGPreflightScreenCaptureAccess()
        },
        requestAccess: {
            CGRequestScreenCaptureAccess()
        },
        openScreenCaptureSettings: {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
                return
            }

            NSWorkspace.shared.open(url)
        },
        capture: { mode in
            await runScreencapture(arguments: arguments(for: mode))
        }
    )

    nonisolated static func arguments(for mode: PulseScreenshotMode) -> [String] {
        switch mode {
        case .fullScreen:
            ["-c", "-i", "-w", "-S", "-x"]
        case .window:
            ["-c", "-i", "-w", "-o", "-x"]
        case .selection:
            ["-c", "-i", "-s", "-x"]
        }
    }

    nonisolated static func captureResult(
        exitCode: Int32,
        standardError: String
    ) -> PulseScreenshotCaptureResult {
        guard exitCode == 0 else {
            let normalizedError = standardError.lowercased()
            if normalizedError.contains("tcc")
                || normalizedError.contains("permission")
                || normalizedError.contains("not authorized")
                || normalizedError.contains("could not create image from display") {
                return .permissionDenied
            }

            return .cancelled
        }

        return .copiedToClipboard
    }

    private nonisolated static func runScreencapture(arguments: [String]) async -> PulseScreenshotCaptureResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let standardError = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            process.standardError = standardError

            do {
                try process.run()
                process.waitUntilExit()

                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
                return captureResult(exitCode: process.terminationStatus, standardError: errorMessage)
            } catch {
                return .failed
            }
        }.value
    }
}

nonisolated struct PulseScreenRecordingOptions: Equatable, Sendable {
    var hidesPulse: Bool
    var hidesCursor: Bool
}

nonisolated enum PulseScreenRecordingStartResult: Sendable {
    case started(PulseScreenRecordingSession)
    case permissionDenied
    case cancelled
    case failed
}

nonisolated enum PulseScreenRecordingStopResult: Sendable {
    case saved(URL)
    case cancelled
    case failed
}

nonisolated struct PulseScreenRecordingSession: Equatable, Identifiable, Sendable {
    var id: UUID
    var mode: PulseScreenshotMode
    var startedAt: Date
    var outputURL: URL
}

@MainActor
final class PulseScreenRecordingService {
    private var activeRecording: ActiveRecording?
    var externalStopHandler: ((PulseScreenRecordingStopResult) -> Void)?

    var isRecording: Bool {
        activeRecording != nil
    }

    func start(
        mode: PulseScreenshotMode,
        options: PulseScreenRecordingOptions,
        sourceScreen: NSScreen?
    ) async -> PulseScreenRecordingStartResult {
        guard !isRecording else {
            return .failed
        }

        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            return .permissionDenied
        }

        do {
            let target = try await selectedTarget(for: mode, sourceScreen: sourceScreen)
            let outputURL = try Self.temporaryRecordingURL()
            let session = PulseScreenRecordingSession(
                id: UUID(),
                mode: mode,
                startedAt: Date(),
                outputURL: outputURL
            )
            let recorder = ScreenCaptureKitRecordingEngine(outputURL: outputURL)
            let regionOverlayController = Self.regionOverlayController(for: target)

            activeRecording = ActiveRecording(
                session: session,
                recorder: recorder,
                regionOverlayController: regionOverlayController
            )

            do {
                try await recorder.start(
                    target: target,
                    hidesPulse: options.hidesPulse,
                    hidesCursor: options.hidesCursor,
                    excludedWindowIDs: regionOverlayController?.windowIDs ?? [],
                    externalStopHandler: { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.handleExternalRecordingStop()
                        }
                    }
                )
            } catch {
                finishActiveRecording(with: .failed)
                return .failed
            }

            return .started(session)
        } catch NativeScreenRecordingError.permissionDenied {
            return .permissionDenied
        } catch NativeScreenRecordingError.cancelled {
            return .cancelled
        } catch {
            return .failed
        }
    }

    func stop() async -> PulseScreenRecordingStopResult {
        guard let recording = activeRecording else {
            return .cancelled
        }

        let result = await recording.recorder.stop()
        finishActiveRecording(with: result)
        return result
    }

    private func selectedTarget(
        for mode: PulseScreenshotMode,
        sourceScreen: NSScreen?
    ) async throws -> NativeRecordingTarget {
        if mode == .selection {
            let selectionController = PulseScreenRecordingSelectionController()
            guard let selectedRect = await selectionController.selectRegion() else {
                throw NativeScreenRecordingError.cancelled
            }

            return .rect(selectedRect)
        }

        let selectionURL = try Self.temporarySelectionURL()
        defer {
            try? FileManager.default.removeItem(at: selectionURL)
        }

        let result = await Self.runScreencapture(
            arguments: Self.selectionArguments(for: mode, outputURL: selectionURL)
        )
        try Self.validateSelection(result)

        let selectedRect = try Self.screenCaptureGlobalRect(from: selectionURL)
        switch mode {
        case .fullScreen:
            return .display(try Self.displayID(containing: selectedRect, fallbackScreen: sourceScreen))
        case .window:
            return .window(try Self.windowID(matching: selectedRect))
        case .selection:
            return .rect(selectedRect.roundedForScreencapture)
        }
    }

    private func handleExternalRecordingStop() {
        guard let recorder = activeRecording?.recorder else {
            return
        }

        Task { @MainActor [weak self] in
            let result = await recorder.stopAfterSystemStop()
            self?.finishActiveRecording(with: result, notifyExternal: true)
        }
    }

    private func finishActiveRecording(
        with result: PulseScreenRecordingStopResult,
        notifyExternal: Bool = false
    ) {
        guard activeRecording != nil else {
            return
        }

        let regionOverlayController = activeRecording?.regionOverlayController
        activeRecording = nil
        regionOverlayController?.hide()

        if notifyExternal {
            externalStopHandler?(result)
        }
    }

    private static func regionOverlayController(
        for target: NativeRecordingTarget
    ) -> PulseScreenRecordingRegionOverlayController? {
        guard case .rect(let rect) = target else {
            return nil
        }

        let controller = PulseScreenRecordingRegionOverlayController()
        controller.show(selectionRect: rect)
        return controller
    }

    nonisolated static func selectionArguments(
        for mode: PulseScreenshotMode,
        outputURL: URL
    ) -> [String] {
        switch mode {
        case .fullScreen:
            ["-i", "-w", "-S", "-x", outputURL.path]
        case .window:
            ["-i", "-w", "-o", "-x", outputURL.path]
        case .selection:
            ["-i", "-s", "-x", outputURL.path]
        }
    }

    static func temporaryRecordingURL(
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("PulseScreenRecordings", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent(suggestedRecordingFileName(now: now), isDirectory: false)
    }

    static func suggestedRecordingFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Pulse Recording \(formatter.string(from: now)).mov"
    }

    static func cleanupTemporaryRecordings(
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws {
        let directories = [
            fileManager.temporaryDirectory
                .appendingPathComponent("PulseScreenRecordings", isDirectory: true),
            fileManager.temporaryDirectory
                .appendingPathComponent("PulseScreenRecordingSelections", isDirectory: true)
        ]

        for directory in directories where fileManager.fileExists(atPath: directory.path) {
            try cleanupTemporaryFiles(in: directory, fileManager: fileManager, now: now)
        }
    }

    private static func temporarySelectionURL(fileManager: FileManager = .default) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("PulseScreenRecordingSelections", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent("selection-\(UUID().uuidString).png", isDirectory: false)
    }

    private nonisolated static func runScreencapture(arguments: [String]) async -> ProcessResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let standardError = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            process.standardError = standardError

            do {
                try process.run()
                process.waitUntilExit()

                return ProcessResult(
                    terminationStatus: process.terminationStatus,
                    standardError: standardErrorText(from: standardError)
                )
            } catch {
                return ProcessResult(
                    terminationStatus: -1,
                    standardError: "",
                    didFailToLaunch: true
                )
            }
        }.value
    }

    private nonisolated static func validateSelection(_ result: ProcessResult) throws {
        if result.didFailToLaunch {
            throw NativeScreenRecordingError.failed
        }

        guard result.terminationStatus == 0 else {
            if isPermissionDeniedError(result.standardError) {
                throw NativeScreenRecordingError.permissionDenied
            }

            throw NativeScreenRecordingError.cancelled
        }
    }

    private nonisolated static func recordingFileExists(at url: URL) -> Bool {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let fileSize = attributes[.size] as? NSNumber
        else {
            return false
        }

        return fileSize.int64Value > 0
    }

    private static func cleanupTemporaryFiles(
        in directory: URL,
        fileManager: FileManager,
        now: Date
    ) throws {
        let staleThreshold = now.addingTimeInterval(-24 * 60 * 60)
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        for url in urls {
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard modifiedAt.map({ $0 < staleThreshold }) == true else {
                continue
            }

            try? fileManager.removeItem(at: url)
        }
    }

    private nonisolated static func isPermissionDeniedError(_ standardError: String) -> Bool {
        let normalizedError = standardError.lowercased()
        return normalizedError.contains("tcc")
            || normalizedError.contains("permission")
            || normalizedError.contains("not authorized")
            || normalizedError.contains("could not create image from display")
    }

    private nonisolated static func standardErrorText(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private nonisolated static func screenCaptureGlobalRect(from url: URL) throws -> CGRect {
        let attributeData = try extendedAttributeData(
            named: "com.apple.metadata:kMDItemScreenCaptureGlobalRect",
            from: url
        )
        let propertyList = try PropertyListSerialization.propertyList(
            from: attributeData,
            options: [],
            format: nil
        )
        guard
            let values = propertyList as? [NSNumber],
            values.count == 4
        else {
            throw NativeScreenRecordingError.failed
        }

        let rect = CGRect(
            x: values[0].doubleValue,
            y: values[1].doubleValue,
            width: values[2].doubleValue,
            height: values[3].doubleValue
        )
        .standardized
        guard rect.isValidForScreenRecording else {
            throw NativeScreenRecordingError.failed
        }

        return rect
    }

    private nonisolated static func extendedAttributeData(
        named name: String,
        from url: URL
    ) throws -> Data {
        try url.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                throw NativeScreenRecordingError.failed
            }

            let length = getxattr(path, name, nil, 0, 0, 0)
            guard length > 0 else {
                throw NativeScreenRecordingError.failed
            }

            var data = Data(count: length)
            let result = data.withUnsafeMutableBytes {
                getxattr(path, name, $0.baseAddress, length, 0, 0)
            }
            guard result > 0 else {
                throw NativeScreenRecordingError.failed
            }

            if result < data.count {
                data.removeSubrange(result..<data.count)
            }

            return data
        }
    }

    private nonisolated static func displayID(
        containing rect: CGRect,
        fallbackScreen: NSScreen?
    ) throws -> CGDirectDisplayID {
        let displayCenter = rect.center
        let displays = try activeDisplays()
        if let index = displays.firstIndex(where: { CGDisplayBounds($0).contains(displayCenter) }) {
            return displays[index]
        }

        if
            let fallbackScreen,
            let screenNumber = fallbackScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let index = displays.firstIndex(of: screenNumber.uint32Value)
        {
            return displays[index]
        }

        if let index = displays.largestIntersectionIndex(with: rect) {
            return displays[index]
        }

        throw NativeScreenRecordingError.failed
    }

    private nonisolated static func activeDisplays() throws -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            throw NativeScreenRecordingError.failed
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            throw NativeScreenRecordingError.failed
        }

        let activeDisplays = Array(displays.prefix(Int(count)))
        let mainDisplay = CGMainDisplayID()
        guard let mainDisplayIndex = activeDisplays.firstIndex(of: mainDisplay) else {
            return activeDisplays
        }

        var orderedDisplays = [mainDisplay]
        orderedDisplays.append(contentsOf: activeDisplays[..<mainDisplayIndex])
        orderedDisplays.append(contentsOf: activeDisplays[activeDisplays.index(after: mainDisplayIndex)...])
        return orderedDisplays
    }

    private nonisolated static func windowID(matching rect: CGRect) throws -> CGWindowID {
        guard
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            throw NativeScreenRecordingError.failed
        }

        for item in windowInfo {
            guard
                let number = item[kCGWindowNumber as String] as? NSNumber,
                let bounds = windowBounds(from: item),
                bounds.isCloseEnoughToSelectedWindow(rect)
            else {
                continue
            }

            return CGWindowID(number.uint32Value)
        }

        throw NativeScreenRecordingError.failed
    }

    private nonisolated static func windowBounds(from item: [String: Any]) -> CGRect? {
        guard let bounds = item[kCGWindowBounds as String] as? NSDictionary else {
            return nil
        }

        return CGRect(dictionaryRepresentation: bounds)
    }

    nonisolated private final class ScreenCaptureKitRecordingEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
        private let outputURL: URL
        private let sampleQueue = DispatchQueue(label: "pulse.screen-recording.samples")
        private var stream: SCStream?
        private var assetWriter: AVAssetWriter?
        private var videoInput: AVAssetWriterInput?
        private var firstSampleTime: CMTime?
        private var lastSampleBuffer: CMSampleBuffer?
        private var lastPresentationTime: CMTime = .zero
        private var lastFrameDuration = CMTime(value: 1, timescale: 60)
        private var isFinishing = false
        private var didNotifyExternalStop = false
        private var externalStopHandler: (@Sendable () -> Void)?

        init(outputURL: URL) {
            self.outputURL = outputURL
        }

        func start(
            target: NativeRecordingTarget,
            hidesPulse: Bool,
            hidesCursor: Bool,
            excludedWindowIDs: Set<CGWindowID>,
            externalStopHandler: @escaping @Sendable () -> Void
        ) async throws {
            self.externalStopHandler = externalStopHandler

            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let pulseApplication = Self.currentApplication(in: content)
            let prepared = try Self.preparedCapture(
                for: target,
                content: content,
                excludedApplication: hidesPulse ? pulseApplication : nil,
                excludedWindowIDs: excludedWindowIDs
            )
            let streamConfig = SCStreamConfiguration()
            streamConfig.width = prepared.outputSize.width
            streamConfig.height = prepared.outputSize.height
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            streamConfig.queueDepth = 6
            streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
            streamConfig.showsCursor = !hidesCursor
            streamConfig.capturesAudio = false
            if let sourceRect = prepared.sourceRect {
                streamConfig.sourceRect = sourceRect
            }
            if #available(macOS 14.0, *), prepared.isWindowCapture {
                streamConfig.ignoreShadowsSingleWindow = true
            }

            let writer = try AVAssetWriter(url: outputURL, fileType: .mov)
            let videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: Self.videoOutputSettings(size: prepared.outputSize)
            )
            videoInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(videoInput) else {
                throw NativeScreenRecordingError.failed
            }

            writer.add(videoInput)
            guard writer.startWriting() else {
                throw writer.error ?? NativeScreenRecordingError.failed
            }

            let stream = SCStream(filter: prepared.filter, configuration: streamConfig, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)

            self.assetWriter = writer
            self.videoInput = videoInput
            self.stream = stream

            try await stream.startCapture()
        }

        func stop() async -> PulseScreenRecordingStopResult {
            await finish(shouldStopStream: true)
        }

        func stopAfterSystemStop() async -> PulseScreenRecordingStopResult {
            await finish(shouldStopStream: false)
        }

        nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
            guard outputType == .screen, sampleBuffer.isValid else {
                return
            }

            appendScreenSample(sampleBuffer)
        }

        nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
            sampleQueue.async { [weak self] in
                guard let self, !didNotifyExternalStop, !isFinishing else {
                    return
                }

                didNotifyExternalStop = true
                externalStopHandler?()
            }
        }

        private func appendScreenSample(_ sampleBuffer: CMSampleBuffer) {
            guard
                !isFinishing,
                let videoInput,
                videoInput.isReadyForMoreMediaData,
                isCompleteFrame(sampleBuffer)
            else {
                return
            }

            let sampleTime = sampleBuffer.presentationTimeStamp
            if firstSampleTime == nil {
                firstSampleTime = sampleTime
                assetWriter?.startSession(atSourceTime: .zero)
            }

            guard let firstSampleTime else {
                return
            }

            let presentationTime = sampleTime - firstSampleTime
            let duration = frameDuration(for: sampleBuffer)
            let timing = CMSampleTimingInfo(
                duration: duration,
                presentationTimeStamp: presentationTime,
                decodeTimeStamp: .invalid
            )
            guard let retimedSampleBuffer = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) else {
                return
            }

            if videoInput.append(retimedSampleBuffer) {
                lastSampleBuffer = sampleBuffer
                lastPresentationTime = presentationTime
                lastFrameDuration = duration
            }
        }

        private func finish(shouldStopStream: Bool) async -> PulseScreenRecordingStopResult {
            guard await beginFinishing() else {
                return .cancelled
            }

            let streamToStop = stream
            if shouldStopStream, let streamToStop {
                try? await streamToStop.stopCapture()
            }

            return await withCheckedContinuation { continuation in
                sampleQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume(returning: .cancelled)
                        return
                    }

                    appendFinalFrameIfNeeded()
                    videoInput?.markAsFinished()

                    let finalURL = outputURL
                    let writer = assetWriter
                    stream = nil
                    videoInput = nil
                    assetWriter = nil
                    firstSampleTime = nil
                    lastSampleBuffer = nil

                    guard let writer else {
                        continuation.resume(returning: .failed)
                        return
                    }

                    let completionContext = AssetWriterCompletionContext(
                        writer: writer,
                        outputURL: finalURL
                    )
                    writer.finishWriting {
                        let result: PulseScreenRecordingStopResult
                        if
                            completionContext.writer.status == .completed,
                            Self.recordingFileExists(at: completionContext.outputURL)
                        {
                            result = .saved(completionContext.outputURL)
                        } else {
                            try? FileManager.default.removeItem(at: completionContext.outputURL)
                            result = .failed
                        }

                        continuation.resume(returning: result)
                    }
                }
            }
        }

        private func beginFinishing() async -> Bool {
            await withCheckedContinuation { continuation in
                sampleQueue.async { [weak self] in
                    guard let self, !isFinishing else {
                        continuation.resume(returning: false)
                        return
                    }

                    isFinishing = true
                    continuation.resume(returning: true)
                }
            }
        }

        private func appendFinalFrameIfNeeded() {
            guard
                let lastSampleBuffer,
                let videoInput,
                videoInput.isReadyForMoreMediaData
            else {
                return
            }

            let timing = CMSampleTimingInfo(
                duration: lastFrameDuration,
                presentationTimeStamp: lastPresentationTime + lastFrameDuration,
                decodeTimeStamp: .invalid
            )
            if let retimedSampleBuffer = try? CMSampleBuffer(copying: lastSampleBuffer, withNewTiming: [timing]) {
                videoInput.append(retimedSampleBuffer)
            }
        }

        private func frameDuration(for sampleBuffer: CMSampleBuffer) -> CMTime {
            if sampleBuffer.duration.isValid, sampleBuffer.duration > .zero {
                return sampleBuffer.duration
            }

            return lastFrameDuration
        }

        private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
            guard
                let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                let attachment = attachments.first,
                let statusRawValue = attachment[.status] as? Int,
                let status = SCFrameStatus(rawValue: statusRawValue)
            else {
                return false
            }

            return status == .complete
        }

        private static func preparedCapture(
            for target: NativeRecordingTarget,
            content: SCShareableContent,
            excludedApplication: SCRunningApplication?,
            excludedWindowIDs: Set<CGWindowID>
        ) throws -> PreparedCapture {
            let excludedWindows = content.windows.filter { window in
                excludedWindowIDs.contains(CGWindowID(window.windowID))
            }

            switch target {
            case .display(let displayID):
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    throw NativeScreenRecordingError.failed
                }

                let filter = SCContentFilter(
                    display: display,
                    excludingApplications: excludedApplication.map { [$0] } ?? [],
                    exceptingWindows: excludedWindows
                )
                return PreparedCapture(
                    filter: filter,
                    sourceRect: nil,
                    outputSize: outputSize(for: filter, fallbackDisplay: display),
                    isWindowCapture: false
                )
            case .window(let windowID):
                guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                    throw NativeScreenRecordingError.failed
                }

                let filter = SCContentFilter(desktopIndependentWindow: window)
                return PreparedCapture(
                    filter: filter,
                    sourceRect: nil,
                    outputSize: outputSize(for: filter, fallbackRect: window.frame),
                    isWindowCapture: true
                )
            case .rect(let rect):
                guard let display = content.displays.largestIntersection(with: rect) else {
                    throw NativeScreenRecordingError.failed
                }

                let filter = SCContentFilter(
                    display: display,
                    excludingApplications: excludedApplication.map { [$0] } ?? [],
                    exceptingWindows: excludedWindows
                )
                let sourceRect = rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY).standardized.integral
                return PreparedCapture(
                    filter: filter,
                    sourceRect: sourceRect,
                    outputSize: outputSize(for: filter, sourceRect: sourceRect, fallbackDisplay: display),
                    isWindowCapture: false
                )
            }
        }

        private static func outputSize(
            for filter: SCContentFilter,
            sourceRect: CGRect? = nil,
            fallbackDisplay: SCDisplay
        ) -> RecordingPixelSize {
            let rect = sourceRect ?? filter.contentRect
            let scale = filterPointPixelScale(filter, displayID: fallbackDisplay.displayID)
            return RecordingPixelSize(
                width: max(2, Int(rect.width * scale)),
                height: max(2, Int(rect.height * scale))
            )
        }

        private static func outputSize(
            for filter: SCContentFilter,
            fallbackRect: CGRect
        ) -> RecordingPixelSize {
            let scale = filterPointPixelScale(filter, displayID: CGMainDisplayID())
            return RecordingPixelSize(
                width: max(2, Int(fallbackRect.width * scale)),
                height: max(2, Int(fallbackRect.height * scale))
            )
        }

        private static func filterPointPixelScale(_ filter: SCContentFilter, displayID: CGDirectDisplayID) -> CGFloat {
            if #available(macOS 14.0, *) {
                return CGFloat(filter.pointPixelScale)
            }

            guard let displayMode = CGDisplayCopyDisplayMode(displayID) else {
                return NSScreen.main?.backingScaleFactor ?? 1
            }

            return CGFloat(displayMode.pixelWidth) / CGFloat(max(1, displayMode.width))
        }

        private static func videoOutputSettings(size: RecordingPixelSize) -> [String: Any] {
            [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: max(4_000_000, size.width * size.height * 4),
                    AVVideoMaxKeyFrameIntervalKey: 60
                ]
            ]
        }

        private static func currentApplication(in content: SCShareableContent) -> SCRunningApplication? {
            let processID = ProcessInfo.processInfo.processIdentifier
            let bundleIdentifier = Bundle.main.bundleIdentifier
            return content.applications.first { application in
                application.processID == processID
                    || (bundleIdentifier != nil && application.bundleIdentifier == bundleIdentifier)
            }
        }

        private static func recordingFileExists(at url: URL) -> Bool {
            guard
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                let fileSize = attributes[.size] as? NSNumber
            else {
                return false
            }

            return fileSize.int64Value > 0
        }

        private struct PreparedCapture {
            var filter: SCContentFilter
            var sourceRect: CGRect?
            var outputSize: RecordingPixelSize
            var isWindowCapture: Bool
        }

        private struct AssetWriterCompletionContext: @unchecked Sendable {
            var writer: AVAssetWriter
            var outputURL: URL
        }

        private struct RecordingPixelSize {
            var width: Int
            var height: Int
        }
    }

    private struct ActiveRecording {
        var session: PulseScreenRecordingSession
        var recorder: ScreenCaptureKitRecordingEngine
        var regionOverlayController: PulseScreenRecordingRegionOverlayController?
    }

    private struct ProcessResult {
        var terminationStatus: Int32
        var standardError: String
        var didFailToLaunch = false
    }

    private enum NativeRecordingTarget {
        case display(CGDirectDisplayID)
        case window(CGWindowID)
        case rect(CGRect)
    }

    private enum NativeScreenRecordingError: Error {
        case permissionDenied
        case cancelled
        case failed
    }
}

private extension CGRect {
    nonisolated var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    nonisolated var roundedForScreencapture: CGRect {
        standardized.integral
    }

    nonisolated var isValidForScreenRecording: Bool {
        guard
            minX.isFinite,
            minY.isFinite,
            width.isFinite,
            height.isFinite,
            width > 0,
            height > 0
        else {
            return false
        }

        return true
    }

    nonisolated func isCloseEnoughToSelectedWindow(_ other: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}

private extension Array where Element == CGDirectDisplayID {
    nonisolated func largestIntersectionIndex(with rect: CGRect) -> Int? {
        enumerated()
            .map { index, display in
                (index: index, area: CGDisplayBounds(display).intersection(rect).area)
            }
            .filter { $0.area > 0 }
            .max { $0.area < $1.area }?
            .index
    }
}

private extension Array where Element == SCDisplay {
    nonisolated func largestIntersection(with rect: CGRect) -> SCDisplay? {
        map { display in
            (display: display, area: display.frame.intersection(rect).area)
        }
        .filter { $0.area > 0 }
        .max { $0.area < $1.area }?
        .display
    }
}

private extension CGRect {
    nonisolated var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}
