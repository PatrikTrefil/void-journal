// Renders the app icon (a dark void inside a glowing ring on bright violet)
// and writes <output-dir>/AppIcon.icns. Usage: swift scripts/make-icon.swift Resources
import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources")
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [red, green, blue, alpha])!
}

func makeContext(_ size: Int) -> CGContext {
    CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func circle(_ center: CGPoint, _ radius: CGFloat) -> CGPath {
    CGPath(
        ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
        transform: nil)
}

func verticalGradient(_ ctx: CGContext, top: CGColor, bottom: CGColor, in rect: CGRect) {
    let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
}

func drawIcon(_ ctx: CGContext) {
    // macOS icon grid: 824 px body centered in 1024 with ~185 px corner radius.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let center = CGPoint(x: 512, y: 512)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.clip()
    verticalGradient(ctx, top: color(0.52, 0.30, 0.98), bottom: color(0.13, 0.05, 0.38), in: body)

    let hole = circle(center, 250)
    let ring = circle(center, 300).subtracting(hole)
    let ringTop = color(1, 0.97, 1)
    let ringBottom = color(0.62, 0.42, 1.0)

    // Soft drop shadow under the ring.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: color(0.05, 0.0, 0.15, 0.45))
    ctx.addPath(ring)
    ctx.setFillColor(ringBottom)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(ring)
    ctx.clip()
    verticalGradient(ctx, top: ringTop, bottom: ringBottom, in: ring.boundingBoxOfPath)
    ctx.restoreGState()

    ctx.addPath(hole)
    ctx.setFillColor(color(0.06, 0.02, 0.14))
    ctx.fillPath()
}

let master = makeContext(1024)
drawIcon(master)
let image = master.makeImage()!

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let scaled = makeContext(pixels)
        scaled.interpolationQuality = .high
        scaled.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let rep = NSBitmapImageRep(cgImage: scaled.makeImage()!)
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try! rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}

let output = outputDirectory.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try! iconutil.run()
iconutil.waitUntilExit()
print("Wrote \(output.path)")
