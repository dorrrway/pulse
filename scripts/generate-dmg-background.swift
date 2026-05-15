#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate-dmg-background.swift <output.png>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let width = 720
let height = 420
let size = NSSize(width: width, height: height)

guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    fputs("error: failed to create bitmap context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor(calibratedWhite: 0.985, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

func drawCentered(_ text: String, font: NSFont, color: NSColor, top: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]

    let lineHeight = ceil(font.ascender - font.descender + font.leading)
    let rect = NSRect(
        x: 80,
        y: CGFloat(height) - top - lineHeight,
        width: CGFloat(width - 160),
        height: lineHeight + 4
    )
    text.draw(in: rect, withAttributes: attributes)
}

let primaryText = NSColor(calibratedWhite: 0.17, alpha: 1)
let secondaryText = NSColor(calibratedWhite: 0.43, alpha: 1)
let accent = NSColor(calibratedRed: 0.34, green: 0.29, blue: 0.60, alpha: 1)

drawCentered(
    "Drag Pulse to Applications",
    font: .systemFont(ofSize: 24, weight: .semibold),
    color: primaryText,
    top: 62
)
drawCentered(
    "将 Pulse 拖到“应用程序”",
    font: .systemFont(ofSize: 18, weight: .regular),
    color: secondaryText,
    top: 98
)

let arrowY: CGFloat = 214
let arrowStart = CGPoint(x: 296, y: arrowY)
let arrowEnd = CGPoint(x: 424, y: arrowY)
let arrow = NSBezierPath()
arrow.move(to: arrowStart)
arrow.line(to: arrowEnd)
arrow.lineWidth = 3
arrow.lineCapStyle = .round
accent.setStroke()
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: arrowEnd)
arrowHead.line(to: CGPoint(x: arrowEnd.x - 16, y: arrowEnd.y + 11))
arrowHead.move(to: arrowEnd)
arrowHead.line(to: CGPoint(x: arrowEnd.x - 16, y: arrowEnd.y - 11))
arrowHead.lineWidth = 3
arrowHead.lineCapStyle = .round
accent.setStroke()
arrowHead.stroke()

drawCentered(
    "Open from Applications after copying.",
    font: .systemFont(ofSize: 13, weight: .regular),
    color: NSColor(calibratedWhite: 0.55, alpha: 1),
    top: 332
)
drawCentered(
    "复制完成后，请从“应用程序”启动。",
    font: .systemFont(ofSize: 13, weight: .regular),
    color: NSColor(calibratedWhite: 0.55, alpha: 1),
    top: 354
)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("error: failed to encode PNG\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
