import AppKit
import LauncherCore

public enum CompassIcon {
    public static func color(_ hex: String) -> NSColor {
        let rgb = UInt32(hex, radix: 16) ?? 0x007AFF
        return NSColor(srgbRed: CGFloat((rgb >> 16) & 255)/255, green: CGFloat((rgb >> 8) & 255)/255, blue: CGFloat(rgb & 255)/255, alpha: 1)
    }
    public static func image(hex: String, size: Int = 256, quadrants: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let s = CGFloat(size)
        NSAffineTransform(scale: s / 1024).concat()
        let base = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 205, yRadius: 205)
        let c = color(hex)
        NSColor(white: 0.96, alpha: 1).setFill(); base.fill()
        let dial = NSBezierPath(ovalIn: NSRect(x: 135, y: 135, width: 754, height: 754))
        if quadrants {
            let quarters: [(String, NSRect)] = [
                ("EC4899", NSRect(x: 0, y: 512, width: 512, height: 512)),
                ("22A06B", NSRect(x: 512, y: 512, width: 512, height: 512)),
                ("8B5CF6", NSRect(x: 0, y: 0, width: 512, height: 512)),
                ("F59E0B", NSRect(x: 512, y: 0, width: 512, height: 512))
            ]
            NSGraphicsContext.saveGraphicsState(); base.addClip()
            for (hex, rect) in quarters {
                color(hex).blended(withFraction: 0.92, of: .white)!.setFill()
                NSBezierPath(rect: rect).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState(); dial.addClip()
            for (hex, rect) in quarters {
                let quarterColor = color(hex)
                NSGradient(starting: quarterColor.blended(withFraction: 0.12, of: .white)!, ending: quarterColor.blended(withFraction: 0.16, of: .black)!)!
                    .draw(in: NSBezierPath(rect: rect), angle: -90)
            }
            NSGraphicsContext.restoreGraphicsState()
        } else {
            NSGradient(starting: c.blended(withFraction: 0.16, of: .white)!, ending: c.blended(withFraction: 0.22, of: .black)!)!.draw(in: dial, angle: -70)
        }
        NSColor.white.withAlphaComponent(0.85).setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: 206, y: 206, width: 612, height: 612)); ring.lineWidth = 15; ring.stroke()
        for i in 0..<32 {
            let a = CGFloat(i) * .pi / 16
            let r: CGFloat = i % 4 == 0 ? 248 : 266
            let p = NSBezierPath(); p.move(to: NSPoint(x: 512 + r * sin(a), y: 512 + r * cos(a)))
            p.line(to: NSPoint(x: 512 + 286 * sin(a), y: 512 + 286 * cos(a))); p.lineWidth = i % 4 == 0 ? 10 : 5; p.stroke()
        }
        let lower = NSBezierPath(); lower.move(to: NSPoint(x: 685,y: 764)); lower.line(to: NSPoint(x: 557,y: 469)); lower.line(to: NSPoint(x: 339,y: 260)); lower.line(to: NSPoint(x: 467,y: 555)); lower.close()
        NSColor.white.setFill(); lower.fill()
        let needle = NSBezierPath(); needle.move(to: NSPoint(x: 685,y: 764)); needle.line(to: NSPoint(x: 557,y: 469)); needle.line(to: NSPoint(x: 467,y: 555)); needle.close()
        NSColor(srgbRed: 1, green: 0.23, blue: 0.27, alpha: 1).setFill(); needle.fill()
        NSBezierPath(ovalIn: NSRect(x: 494,y: 494,width: 36,height: 36)).fill()
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(bitmap); return image
    }
    public static func writeICNS(hex: String, to url: URL, quadrants: Bool = false) throws {
        // ICNS supports PNG payloads for these standard Retina/large icon representations.
        var body = Data()
        for (kind, size) in [("icp4",16),("icp5",32),("icp6",64),("ic07",128),("ic08",256),("ic09",512),("ic10",1024)] {
            guard let tiff = image(hex: hex, size: size, quadrants: quadrants).tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
                throw LauncherError("Could not render the launcher icon.")
            }
            body.append(contentsOf: kind.utf8); appendSize(UInt32(png.count + 8), to: &body); body.append(png)
        }
        var result = Data("icns".utf8); appendSize(UInt32(body.count + 8), to: &result); result.append(body)
        try result.write(to: url)
    }
    private static func appendSize(_ size: UInt32, to data: inout Data) {
        var big = size.bigEndian; withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }
}
private extension NSAffineTransform {
    convenience init(scale: CGFloat) { self.init(); scaleX(by: scale, yBy: scale) }
}
