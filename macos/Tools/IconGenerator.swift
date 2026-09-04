#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: IconGenerator.swift <iconset-directory>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let icons: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = CGFloat(size) * 0.065
    let radius = CGFloat(size) * 0.22
    let background = NSBezierPath(
        roundedRect: canvas.insetBy(dx: inset, dy: inset),
        xRadius: radius,
        yRadius: radius
    )
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.09, green: 0.42, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.31, green: 0.13, blue: 0.85, alpha: 1)
        ]
    )
    gradient?.draw(in: background, angle: -55)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = CGFloat(size) * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.015)
    shadow.set()

    let white = NSColor.white
    white.setStroke()
    let stroke = CGFloat(size) * 0.055
    let line = NSBezierPath()
    line.lineWidth = stroke
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.move(to: NSPoint(x: CGFloat(size) * 0.39, y: CGFloat(size) * 0.68))
    line.line(to: NSPoint(x: CGFloat(size) * 0.23, y: CGFloat(size) * 0.50))
    line.line(to: NSPoint(x: CGFloat(size) * 0.39, y: CGFloat(size) * 0.32))
    line.move(to: NSPoint(x: CGFloat(size) * 0.61, y: CGFloat(size) * 0.68))
    line.line(to: NSPoint(x: CGFloat(size) * 0.77, y: CGFloat(size) * 0.50))
    line.line(to: NSPoint(x: CGFloat(size) * 0.61, y: CGFloat(size) * 0.32))
    line.stroke()

    let slash = NSBezierPath()
    slash.lineWidth = stroke * 0.82
    slash.lineCapStyle = .round
    slash.move(to: NSPoint(x: CGFloat(size) * 0.57, y: CGFloat(size) * 0.73))
    slash.line(to: NSPoint(x: CGFloat(size) * 0.43, y: CGFloat(size) * 0.27))
    slash.stroke()

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 2)
    }
    return data
}

for (name, size) in icons {
    try drawIcon(size: size).write(to: outputDirectory.appendingPathComponent(name))
}
