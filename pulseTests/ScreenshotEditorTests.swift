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
    func testScreenshotEditorToolOrderMatchesToolbarContract() {
        XCTAssertEqual(
            PulseScreenshotEditTool.allCases,
            [.rectangle, .ellipse, .arrow, .pen, .mosaic, .text]
        )
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
        let image = makeMosaicSourceImage(size: NSSize(width: 80, height: 80))
        let mark = PulseScreenshotEditMark(
            tool: .mosaic,
            start: CGPoint(x: 0.2, y: 0.2),
            end: CGPoint(x: 0.8, y: 0.8)
        )

        let rendered = try XCTUnwrap(PulseScreenshotEditRenderer.renderedImage(base: image, marks: [mark]))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(rendered.tiffRepresentation)))
        let centerColor = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
            .usingColorSpace(.deviceRGB)

        let color = try XCTUnwrap(centerColor)
        XCTAssertLessThan(color.greenComponent, 0.90)
        XCTAssertGreaterThan(color.redComponent - color.greenComponent, 0.05)
    }

    @MainActor
    func testMosaicStrokeRendererObscuresBrushPathWithoutCoveringOutsidePixels() throws {
        let image = makeMosaicSourceImage(size: NSSize(width: 100, height: 100))
        let mark = PulseScreenshotEditMark.mosaicStroke(
            points: [
                CGPoint(x: 0.20, y: 0.50),
                CGPoint(x: 0.50, y: 0.50),
                CGPoint(x: 0.80, y: 0.50)
            ],
            brushDiameter: 0.24
        )

        let rendered = try XCTUnwrap(PulseScreenshotEditRenderer.renderedImage(base: image, marks: [mark]))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(rendered.tiffRepresentation)))
        let coveredColor = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
            .usingColorSpace(.deviceRGB)
        let outsideColor = try XCTUnwrap(bitmap.colorAt(x: 10, y: 10))
            .usingColorSpace(.deviceRGB)

        let covered = try XCTUnwrap(coveredColor)
        let outside = try XCTUnwrap(outsideColor)
        XCTAssertLessThan(covered.greenComponent, 0.90)
        XCTAssertGreaterThan(covered.redComponent - covered.greenComponent, 0.05)
        XCTAssertGreaterThan(outside.redComponent, 0.95)
        XCTAssertGreaterThan(outside.greenComponent, 0.95)
        XCTAssertGreaterThan(outside.blueComponent, 0.95)
    }

    @MainActor
    func testPenStrokeRendererDrawsBrushPathWithoutCoveringOutsidePixels() throws {
        let image = makeImage(color: .white, size: NSSize(width: 100, height: 100))
        let mark = PulseScreenshotEditMark.penStroke(
            points: [
                CGPoint(x: 0.20, y: 0.50),
                CGPoint(x: 0.50, y: 0.50),
                CGPoint(x: 0.80, y: 0.50)
            ],
            brushDiameter: 0.08
        )

        let rendered = try XCTUnwrap(PulseScreenshotEditRenderer.renderedImage(base: image, marks: [mark]))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(rendered.tiffRepresentation)))
        let coveredColor = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
            .usingColorSpace(.deviceRGB)
        let outsideColor = try XCTUnwrap(bitmap.colorAt(x: 10, y: 10))
            .usingColorSpace(.deviceRGB)

        let covered = try XCTUnwrap(coveredColor)
        let outside = try XCTUnwrap(outsideColor)
        XCTAssertGreaterThan(covered.redComponent, 0.85)
        XCTAssertGreaterThan(covered.greenComponent, 0.35)
        XCTAssertLessThan(covered.blueComponent, 0.30)
        XCTAssertGreaterThan(outside.redComponent, 0.95)
        XCTAssertGreaterThan(outside.greenComponent, 0.95)
        XCTAssertGreaterThan(outside.blueComponent, 0.95)
    }

    @MainActor
    func testTextRendererDrawsLabel() throws {
        let image = makeImage(color: .white, size: NSSize(width: 180, height: 100))
        let mark = PulseScreenshotEditMark.text("Pulse", at: CGPoint(x: 0.5, y: 0.5))

        let rendered = try XCTUnwrap(PulseScreenshotEditRenderer.renderedImage(base: image, marks: [mark]))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(rendered.tiffRepresentation)))

        XCTAssertTrue(containsAccentPixel(in: bitmap))
    }

    @MainActor
    func testMovingTextMarkPreservesIdentityAndClampsPosition() {
        let id = UUID()
        let mark = PulseScreenshotEditMark.text(id: id, "Pulse", at: CGPoint(x: 0.5, y: 0.5))

        let moved = mark.movingText(to: CGPoint(x: 1.2, y: -0.2))

        XCTAssertEqual(moved.id, id)
        XCTAssertEqual(moved.tool, .text)
        XCTAssertEqual(moved.textValue, "Pulse")
        XCTAssertEqual(moved.start.x, 1, accuracy: 0.001)
        XCTAssertEqual(moved.start.y, 0, accuracy: 0.001)
        XCTAssertEqual(moved.end.x, 1, accuracy: 0.001)
        XCTAssertEqual(moved.end.y, 0, accuracy: 0.001)
    }

    @MainActor
    func testMovingTextMarkIgnoresNonTextMarks() {
        let mark = PulseScreenshotEditMark(
            tool: .rectangle,
            start: CGPoint(x: 0.2, y: 0.2),
            end: CGPoint(x: 0.8, y: 0.8)
        )

        XCTAssertEqual(mark.movingText(to: CGPoint(x: 0.4, y: 0.4)), mark)
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

    @MainActor
    private func makeMosaicSourceImage(size: NSSize) -> NSImage {
        let image = makeImage(color: .white, size: size)
        image.lockFocus()
        NSColor(calibratedRed: 1, green: 0.05, blue: 0.02, alpha: 1).setFill()
        NSRect(x: size.width / 2 - 2, y: 0, width: 4, height: size.height).fill()
        image.unlockFocus()
        return image
    }

    private func containsAccentPixel(in bitmap: NSBitmapImageRep) -> Bool {
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
                else {
                    continue
                }

                if color.redComponent > 0.80, color.greenComponent > 0.30, color.blueComponent < 0.35 {
                    return true
                }
            }
        }

        return false
    }
}
