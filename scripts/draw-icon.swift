import AppKit

guard CommandLine.arguments.count == 3,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("usage: draw-icon source.jpg output.png")
}

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let square = NSRect(x: 40, y: 40, width: 944, height: 944)
let shape = NSBezierPath(roundedRect: square, xRadius: 210, yRadius: 210)
NSColor.white.setFill()
shape.fill()
NSGraphicsContext.current?.saveGraphicsState()
shape.addClip()
// Crop only the supplied pineapple mark. The original artwork is not redrawn.
source.draw(in: NSRect(x: 245, y: 107, width: 534, height: 870),
            from: NSRect(x: 330, y: 290, width: 365, height: 595),
            operation: .sourceOver, fraction: 1)
NSGraphicsContext.current?.restoreGraphicsState()

let border = NSBezierPath(roundedRect: square.insetBy(dx: 2, dy: 2), xRadius: 208, yRadius: 208)
border.lineWidth = 3
NSColor(calibratedRed: 0.72, green: 0.61, blue: 0.37, alpha: 0.3).setStroke()
border.stroke()
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
