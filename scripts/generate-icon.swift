import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: swift scripts/generate-icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let size = NSSize(width: 1024, height: 1024)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let cardRect = NSRect(x: 64, y: 64, width: 896, height: 896)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 216, yRadius: 216)
cardPath.addClip()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.23, alpha: 1),
    NSColor(calibratedRed: 0.10, green: 0.36, blue: 0.48, alpha: 1),
    NSColor(calibratedRed: 0.16, green: 0.70, blue: 0.47, alpha: 1)
])!
gradient.draw(in: cardRect, angle: -38)

let glow = NSBezierPath(ovalIn: NSRect(x: 500, y: 470, width: 620, height: 620))
NSColor.white.withAlphaComponent(0.08).setFill()
glow.fill()

let gauge = NSBezierPath()
gauge.appendArc(
    withCenter: NSPoint(x: 512, y: 500),
    radius: 292,
    startAngle: 205,
    endAngle: -25,
    clockwise: true
)
gauge.lineWidth = 62
gauge.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.28).setStroke()
gauge.stroke()

let activeGauge = NSBezierPath()
activeGauge.appendArc(
    withCenter: NSPoint(x: 512, y: 500),
    radius: 292,
    startAngle: 205,
    endAngle: 82,
    clockwise: true
)
activeGauge.lineWidth = 62
activeGauge.lineCapStyle = .round
NSColor.white.setStroke()
activeGauge.stroke()

let needle = NSBezierPath()
needle.move(to: NSPoint(x: 512, y: 500))
needle.line(to: NSPoint(x: 684, y: 622))
needle.lineWidth = 44
needle.lineCapStyle = .round
NSColor.white.setStroke()
needle.stroke()

let hub = NSBezierPath(ovalIn: NSRect(x: 470, y: 458, width: 84, height: 84))
NSColor.white.setFill()
hub.fill()

let terminal = NSBezierPath()
terminal.move(to: NSPoint(x: 292, y: 292))
terminal.line(to: NSPoint(x: 394, y: 366))
terminal.line(to: NSPoint(x: 292, y: 440))
terminal.lineWidth = 42
terminal.lineCapStyle = .round
terminal.lineJoinStyle = .round
NSColor.white.setStroke()
terminal.stroke()

let cursor = NSBezierPath()
cursor.move(to: NSPoint(x: 430, y: 300))
cursor.line(to: NSPoint(x: 585, y: 300))
cursor.lineWidth = 42
cursor.lineCapStyle = .round
cursor.stroke()

let highlight = NSBezierPath(roundedRect: cardRect.insetBy(dx: 18, dy: 18), xRadius: 198, yRadius: 198)
highlight.lineWidth = 8
NSColor.white.withAlphaComponent(0.12).setStroke()
highlight.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try png.write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
