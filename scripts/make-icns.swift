// SPDX-License-Identifier: 0BSD
import AppKit
import Foundation

// Rasterize the existing website favicon geometry with system AppKit; no downloaded art/toolchain.
// A changed source mark requires updating the renderer rather than silently shipping a different logo.
let source = try String(contentsOfFile: "docs/assets/favicon.svg", encoding: .utf8)
let expected = ["M24 24C16.5 19.5 15.5 9 24 4.5C32.5 9 31.5 19.5 24 24Z", "#8e5ba1", "#5a3169", "#fdf3f9", "#f2a3cf", "#c2408a"]
guard expected.allSatisfy({ source.contains($0) }), CommandLine.arguments.count == 2 else {
  fatalError("Usage: swift scripts/make-icns.swift output.iconset; review renderer when favicon.svg changes")
}
let directory = URL(filePath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
  NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: 1)
}
func render(_ size: Int, to url: URL) throws {
  guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: size * 4, bitsPerPixel: 32), let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else { fatalError("Cannot create icon bitmap") }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  let transform = NSAffineTransform()
  transform.translateX(by: 0, yBy: CGFloat(size))
  transform.scaleX(by: CGFloat(size)/48, yBy: -CGFloat(size)/48)
  transform.concat()
  let tile = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 48, height: 48), xRadius: 11, yRadius: 11)
  NSGradient(starting: color(142, 91, 161), ending: color(90, 49, 105))!.draw(in: tile, angle: 90)
  let inset = NSAffineTransform()
  inset.translateX(by: 24, yBy: 24); inset.scale(by: 0.78); inset.translateX(by: -24, yBy: -24)
  inset.concat()
  for index in 0..<5 {
    NSGraphicsContext.saveGraphicsState()
    let rotation = NSAffineTransform()
    rotation.translateX(by: 24, yBy: 24); rotation.rotate(byDegrees: CGFloat(index) * 72)
    rotation.translateX(by: -24, yBy: -24); rotation.concat()
    let petal = NSBezierPath()
    petal.move(to: NSPoint(x: 24, y: 24))
    petal.curve(to: NSPoint(x: 24, y: 4.5), controlPoint1: NSPoint(x: 16.5, y: 19.5), controlPoint2: NSPoint(x: 15.5, y: 9))
    petal.curve(to: NSPoint(x: 24, y: 24), controlPoint1: NSPoint(x: 32.5, y: 9), controlPoint2: NSPoint(x: 31.5, y: 19.5))
    petal.close(); color(253, 243, 249).setFill(); petal.fill()
    NSGraphicsContext.restoreGraphicsState()
  }
  color(242, 163, 207).setFill()
  NSBezierPath(ovalIn: NSRect(x: 19, y: 19, width: 10, height: 10)).fill()
  color(194, 64, 138).setFill()
  NSBezierPath(ovalIn: NSRect(x: 21.8, y: 21.8, width: 4.4, height: 4.4)).fill()
  context.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()
  guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
  try png.write(to: url)
}
for points in [16, 32, 128, 256, 512] {
  try render(points, to: directory.appendingPathComponent("icon_\(points)x\(points).png"))
  try render(points * 2, to: directory.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
