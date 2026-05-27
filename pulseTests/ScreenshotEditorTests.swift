import AppKit
import XCTest
@testable import pulse

final class ScreenshotEditorTests: XCTestCase {
    @MainActor
    func testEditorDefaultsToNoSelectedToolSoImageDragMovesWindow() {
        XCTAssertNil(PulseScreenshotEditInteractionPolicy.defaultSelectedTool)
        XCTAssertTrue(
            PulseScreenshotEditInteractionPolicy.allowsImageWindowDragging(
                selectedTool: PulseScreenshotEditInteractionPolicy.defaultSelectedTool
            )
        )
    }

    @MainActor
    func testEditorToolSelectionLocksImageWindowDraggingUntilDeselected() {
        let selectedTool = PulseScreenshotEditInteractionPolicy.selectedTool(
            afterTapping: .arrow,
            currentSelection: nil
        )

        XCTAssertEqual(selectedTool, .arrow)
        XCTAssertFalse(PulseScreenshotEditInteractionPolicy.allowsImageWindowDragging(selectedTool: selectedTool))

        let deselectedTool = PulseScreenshotEditInteractionPolicy.selectedTool(
            afterTapping: .arrow,
            currentSelection: selectedTool
        )

        XCTAssertNil(deselectedTool)
        XCTAssertTrue(PulseScreenshotEditInteractionPolicy.allowsImageWindowDragging(selectedTool: deselectedTool))
    }

    @MainActor
    func testScreenshotEditMarkNormalizesRectRegardlessOfDragDirection() {
        let mark = PulseScreenshotEditMark(
            tool: .rectangle,
            start: CGPoint(x: 0.82, y: 0.74),
            end: CGPoint(x: 0.18, y: 0.24)
        )

        XCTAssertEqual(mark.unitRect.minX, 0.18, accuracy: 0.001)
        XCTAssertEqual(mark.unitRect.minY, 0.24, accuracy: 0.001)
        XCTAssertEqual(mark.unitRect.width, 0.64, accuracy: 0.001)
        XCTAssertEqual(mark.unitRect.height, 0.50, accuracy: 0.001)
    }

    @MainActor
    func testScreenshotEditRendererKeepsImageSize() throws {
        let image = makeImage(color: .white, size: NSSize(width: 120, height: 80))
        let mark = PulseScreenshotEditMark(
            tool: .ellipse,
            start: CGPoint(x: 0.2, y: 0.2),
            end: CGPoint(x: 0.8, y: 0.8)
        )

        let rendered = try XCTUnwrap(PulseScreenshotEditRenderer.renderedImage(base: image, marks: [mark]))

        XCTAssertEqual(rendered.size.width, 120, accuracy: 0.001)
        XCTAssertEqual(rendered.size.height, 80, accuracy: 0.001)
    }

    @MainActor
    func testMosaicRendererObscuresCoveredPixels() throws {
        let image = makeImage(color: .white, size: NSSize(width: 80, height: 80))
        let mark = PulseScreenshotEditMark(
            tool: .mosaic,
            start: CGPoint(x: 0.2, y: 0.2),
            end: CGPoint(x: 0.8, y: 0.8)
        )

        let rendered = try XCTUnwrap(PulseScreenshotEditRenderer.renderedImage(base: image, marks: [mark]))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(rendered.tiffRepresentation)))
        let centerColor = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
            .usingColorSpace(.deviceRGB)

        XCTAssertLessThan(try XCTUnwrap(centerColor).redComponent, 0.90)
    }

    @MainActor
    func testEditorWindowReservesSeparateToolbarArea() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let imageSize = CGSize(width: 900, height: 500)
        let imageContentSize = PulseScreenshotEditorPanelLayout.imageContentSize(
            imageSize: imageSize,
            visibleFrame: visibleFrame
        )
        let windowSize = PulseScreenshotEditorPanelLayout.windowSize(
            imageSize: imageSize,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(
            windowSize.height,
            imageContentSize.height
                + PulseScreenshotEditorPanelLayout.toolbarGap
                + PulseScreenshotEditorPanelLayout.toolbarHeight,
            accuracy: 0.001
        )
        XCTAssertGreaterThanOrEqual(windowSize.width, PulseScreenshotEditorPanelLayout.minimumToolbarWidth)
    }

    @MainActor
    private func makeImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
