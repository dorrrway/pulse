import AppKit
import XCTest
@testable import pulse

@MainActor
final class ClipboardPasteboardClientTests: XCTestCase {
    func testReadsWeChatSourceFromAppSpecificPasteboardType() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("pulse.clipboard.tests.\(UUID().uuidString)"))
        defer { pasteboard.clearContents() }

        let item = NSPasteboardItem()
        item.setString("X", forType: NSPasteboard.PasteboardType("com.trolltech.anymime.WeChatScreenshotFormat"))
        item.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardKnownMarker.remoteClipboard.rawValue))
        XCTAssertTrue(pasteboard.writeObjects([item]))

        let client = AppKitClipboardPasteboardClient(pasteboard: pasteboard)
        let snapshot = try client.readSnapshot(capturedAt: Date(), inferredSource: nil)

        XCTAssertEqual(snapshot.declaredSource?.bundleIdentifier, "com.tencent.xinWeChat")
        XCTAssertEqual(snapshot.declaredSource?.rawValue, "com.trolltech.anymime.WeChatScreenshotFormat")
        XCTAssertNotNil(snapshot.declaredSource?.displayName)
    }

    func testStandardDeclaredSourceTakesPriorityOverAppSpecificPasteboardType() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("pulse.clipboard.tests.\(UUID().uuidString)"))
        defer { pasteboard.clearContents() }

        let item = NSPasteboardItem()
        item.setString("com.example.source", forType: NSPasteboard.PasteboardType(ClipboardKnownMarker.source.rawValue))
        item.setString("X", forType: NSPasteboard.PasteboardType("com.trolltech.anymime.WeChatScreenshotFormat"))
        XCTAssertTrue(pasteboard.writeObjects([item]))

        let client = AppKitClipboardPasteboardClient(pasteboard: pasteboard)
        let snapshot = try client.readSnapshot(capturedAt: Date(), inferredSource: nil)

        XCTAssertEqual(snapshot.declaredSource?.bundleIdentifier, "com.example.source")
        XCTAssertEqual(snapshot.declaredSource?.rawValue, "com.example.source")
    }
}
