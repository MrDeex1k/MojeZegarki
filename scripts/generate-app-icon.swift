// Run from the repository root: swift scripts/generate-app-icon.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let bitmap = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let context = NSGraphicsContext(cgContext: bitmap, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(calibratedRed: 0.035, green: 0.16, blue: 0.18, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let strap = NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.29, alpha: 1)
strap.setFill()
NSBezierPath(roundedRect: NSRect(x: 390, y: 86, width: 244, height: 852), xRadius: 65, yRadius: 65).fill()
let ivory = NSColor(calibratedRed: 0.94, green: 0.9, blue: 0.79, alpha: 1)
ivory.setFill()
NSBezierPath(roundedRect: NSRect(x: 795, y: 478, width: 43, height: 68), xRadius: 14, yRadius: 14).fill()
ivory.setStroke()
let bezel = NSBezierPath(ovalIn: NSRect(x: 213, y: 213, width: 598, height: 598))
bezel.lineWidth = 23
bezel.stroke()
NSColor(calibratedRed: 0.025, green: 0.12, blue: 0.14, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 233, y: 233, width: 558, height: 558)).fill()
for hour in 0..<12 {
    let angle = Double(hour) * .pi / 6
    let outer = 253.0
    let inner = hour % 3 == 0 ? 215.0 : 231.0
    let tick = NSBezierPath()
    tick.move(to: NSPoint(x: 512 + sin(angle) * inner, y: 512 + cos(angle) * inner))
    tick.line(to: NSPoint(x: 512 + sin(angle) * outer, y: 512 + cos(angle) * outer))
    tick.lineWidth = hour % 3 == 0 ? 14 : 8
    tick.lineCapStyle = .round
    ivory.setStroke(); tick.stroke()
}
let hands = NSBezierPath()
hands.move(to: NSPoint(x: 388, y: 590))
hands.line(to: NSPoint(x: 512, y: 512))
hands.line(to: NSPoint(x: 667, y: 652))
hands.lineWidth = 24
hands.lineCapStyle = .round
hands.lineJoinStyle = .round
ivory.setStroke(); hands.stroke()
NSColor(calibratedRed: 0.91, green: 0.49, blue: 0.29, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 494, y: 494, width: 36, height: 36)).fill()
NSGraphicsContext.restoreGraphicsState()
let folder = URL(fileURLWithPath: "MojeZegarki/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let output = CGImageDestinationCreateWithURL(folder.appendingPathComponent("AppIcon.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, bitmap.makeImage()!, nil)
precondition(CGImageDestinationFinalize(output))
let contents = """
{
  "images": [{ "filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" }],
  "info": { "author": "xcode", "version": 1 }
}
"""
try contents.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
