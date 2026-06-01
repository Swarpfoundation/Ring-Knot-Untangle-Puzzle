#!/usr/bin/env swift
// generate_assets.swift
// Deterministic procedural asset generator for Ring Knot.
// No third-party packages, no network access.
// Run: swift tools/generate_assets.swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - PRNG (deterministic)

struct DeterministicRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(1 << 53)
    }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        a + (b - a) * unit()
    }
}

// MARK: - Color helpers

struct RGB {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat = 1
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    func with(alpha: CGFloat) -> RGB { RGB(r: r, g: g, b: b, a: alpha) }
}

enum Palette {
    static let obsidian       = RGB(r: 0.055, g: 0.062, b: 0.085)
    static let obsidianTint   = RGB(r: 0.090, g: 0.100, b: 0.135)
    static let obsidianDeep   = RGB(r: 0.020, g: 0.025, b: 0.040)

    static let silverHi   = RGB(r: 0.94, g: 0.95, b: 0.99)
    static let silverMid  = RGB(r: 0.74, g: 0.78, b: 0.84)
    static let silverLow  = RGB(r: 0.34, g: 0.38, b: 0.45)
    static let silverDeep = RGB(r: 0.12, g: 0.14, b: 0.18)

    static let copperHi   = RGB(r: 1.00, g: 0.90, b: 0.70)
    static let copperMid  = RGB(r: 0.86, g: 0.55, b: 0.30)
    static let copperLow  = RGB(r: 0.46, g: 0.22, b: 0.10)
    static let copperDeep = RGB(r: 0.18, g: 0.07, b: 0.03)

    static let selectionGlow = RGB(r: 0.50, g: 0.85, b: 1.00)
    static let hintGlow      = RGB(r: 1.00, g: 0.78, b: 0.35)
    static let invalidRed    = RGB(r: 1.00, g: 0.35, b: 0.30)
}

// MARK: - PNG output

func saveCGImage(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { fatalError("destination") }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) { fatalError("finalize \(url.path)") }
}

func makeContext(_ size: CGSize, opaque: Bool) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo: UInt32 = opaque
        ? CGImageAlphaInfo.noneSkipLast.rawValue
        : CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: bitmapInfo
    ) else { fatalError("ctx") }
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    return ctx
}

// MARK: - Drawing helpers

func fillBackground(_ ctx: CGContext, size: CGSize, color: RGB) {
    ctx.setFillColor(color.cg)
    ctx.fill(CGRect(origin: .zero, size: size))
}

func radialGradient(
    _ ctx: CGContext,
    rect: CGRect,
    inner: RGB,
    outer: RGB,
    centerOffset: CGPoint = .zero,
    radiusScale: CGFloat = 0.7
) {
    let colors = [inner.cg, outer.cg] as CFArray
    guard let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 1]
    ) else { return }
    let center = CGPoint(x: rect.midX + centerOffset.x, y: rect.midY + centerOffset.y)
    let radius = max(rect.width, rect.height) * radiusScale
    ctx.drawRadialGradient(
        grad,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

func linearGradient(
    _ ctx: CGContext,
    rect: CGRect,
    stops: [(RGB, CGFloat)],
    start: CGPoint,
    end: CGPoint
) {
    let colors = stops.map { $0.0.cg } as CFArray
    let locs = stops.map { $0.1 }
    guard let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: locs
    ) else { return }
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.drawLinearGradient(grad, start: start, end: end, options: [])
    ctx.restoreGState()
}

// Brushed metal: horizontal streaks + per-row gradient.
func drawBrushedMetal(
    _ ctx: CGContext,
    rect: CGRect,
    base: RGB,
    highlight: RGB,
    shadow: RGB,
    seed: UInt64
) {
    var rng = DeterministicRNG(seed: seed)
    linearGradient(ctx, rect: rect, stops: [
        (highlight.with(alpha: 1), 0),
        (base.with(alpha: 1), 0.5),
        (shadow.with(alpha: 1), 1)
    ], start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY))

    let stripeCount = 480
    for _ in 0..<stripeCount {
        let y = rect.minY + rng.unit() * rect.height
        let len = rng.range(rect.width * 0.25, rect.width * 1.05)
        let x = rect.minX + rng.unit() * rect.width - len / 2
        let alpha = rng.range(0.02, 0.10)
        let bright = rng.unit() < 0.55
        let color = bright ? highlight.with(alpha: alpha) : shadow.with(alpha: alpha)
        ctx.setStrokeColor(color.cg)
        ctx.setLineWidth(rng.range(0.6, 1.6))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + len, y: y + rng.range(-0.6, 0.6)))
        ctx.strokePath()
    }

    let specks = 240
    for _ in 0..<specks {
        let x = rect.minX + rng.unit() * rect.width
        let y = rect.minY + rng.unit() * rect.height
        let r = rng.range(0.4, 1.8)
        let alpha = rng.range(0.04, 0.14)
        ctx.setFillColor(shadow.with(alpha: alpha).cg)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }
}

// MARK: - Geometry helpers

func ringCPath(
    center: CGPoint,
    outerRadius: CGFloat,
    tubeWidth: CGFloat,
    gapDegrees: CGFloat,
    rotationDegrees: CGFloat
) -> CGMutablePath {
    let rot = rotationDegrees * .pi / 180
    let halfGap = (gapDegrees * .pi / 180) / 2
    let start = rot + halfGap
    let end = rot + 2 * .pi - halfGap
    let mid = outerRadius - tubeWidth / 2
    let path = CGMutablePath()
    path.addArc(center: center, radius: mid, startAngle: start, endAngle: end, clockwise: false)
    return path
}

func drawRingC(
    _ ctx: CGContext,
    center: CGPoint,
    outerRadius: CGFloat,
    tubeWidth: CGFloat,
    gapDegrees: CGFloat,
    rotationDegrees: CGFloat,
    palette: (hi: RGB, mid: RGB, low: RGB, deep: RGB),
    tab: (Bool, CGFloat) = (false, 0)
) {
    // Shadow under the ring
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -outerRadius * 0.06),
        blur: outerRadius * 0.12,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6)
    )
    ctx.setLineWidth(tubeWidth)
    ctx.setLineCap(.round)
    let arcPath = ringCPath(
        center: center,
        outerRadius: outerRadius,
        tubeWidth: tubeWidth,
        gapDegrees: gapDegrees,
        rotationDegrees: rotationDegrees
    )
    ctx.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.0))
    ctx.addPath(arcPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Base coat
    ctx.saveGState()
    ctx.setLineWidth(tubeWidth)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(palette.mid.cg)
    ctx.addPath(arcPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Gradient overlay clipped to the stroked tube
    ctx.saveGState()
    let clipPath = arcPath.copy(
        strokingWithWidth: tubeWidth,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 1
    )
    ctx.addPath(clipPath)
    ctx.clip()
    let colors = [palette.hi.cg, palette.mid.cg, palette.low.cg, palette.deep.cg] as CFArray
    if let g = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.45, 0.78, 1]
    ) {
        ctx.drawLinearGradient(
            g,
            start: CGPoint(x: center.x, y: center.y + outerRadius),
            end: CGPoint(x: center.x, y: center.y - outerRadius),
            options: []
        )
    }
    ctx.restoreGState()

    // Brushed grain
    var rng = DeterministicRNG(seed: UInt64(bitPattern: Int64(center.x.bitPattern)) ^ UInt64(bitPattern: Int64(center.y.bitPattern)) ^ UInt64(outerRadius.bitPattern))
    ctx.saveGState()
    ctx.addPath(clipPath)
    ctx.clip()
    for _ in 0..<260 {
        let angle = rng.range(rotationDegrees * .pi / 180 + gapDegrees * .pi / 360,
                              rotationDegrees * .pi / 180 + 2 * .pi - gapDegrees * .pi / 360)
        let r = outerRadius - tubeWidth * rng.range(0.05, 0.95)
        let x1 = center.x + cos(angle) * r
        let y1 = center.y + sin(angle) * r
        let len = rng.range(tubeWidth * 0.3, tubeWidth * 0.9)
        let nx = cos(angle + .pi / 2)
        let ny = sin(angle + .pi / 2)
        let x2 = x1 + nx * len
        let y2 = y1 + ny * len
        let alpha = rng.range(0.03, 0.12)
        let bright = rng.unit() < 0.5
        ctx.setStrokeColor((bright ? palette.hi : palette.deep).with(alpha: alpha).cg)
        ctx.setLineWidth(rng.range(0.5, 1.2))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addLine(to: CGPoint(x: x2, y: y2))
        ctx.strokePath()
    }
    ctx.restoreGState()

    // Highlight rim
    ctx.saveGState()
    ctx.setLineWidth(tubeWidth * 0.18)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(palette.hi.with(alpha: 0.55).cg)
    let highlightPath = ringCPath(
        center: CGPoint(x: center.x, y: center.y + tubeWidth * 0.18),
        outerRadius: outerRadius - tubeWidth * 0.18,
        tubeWidth: tubeWidth * 0.18,
        gapDegrees: gapDegrees + 8,
        rotationDegrees: rotationDegrees
    )
    ctx.addPath(highlightPath)
    ctx.strokePath()
    ctx.restoreGState()

    if tab.0 {
        let angle = tab.1 * .pi / 180
        let tabCenter = CGPoint(
            x: center.x + cos(angle) * (outerRadius - tubeWidth / 2),
            y: center.y + sin(angle) * (outerRadius - tubeWidth / 2)
        )
        drawTab(
            ctx,
            center: tabCenter,
            angleRadians: angle,
            length: tubeWidth * 1.3,
            width: tubeWidth * 0.6,
            palette: palette
        )
    }
}

func drawTab(
    _ ctx: CGContext,
    center: CGPoint,
    angleRadians: CGFloat,
    length: CGFloat,
    width: CGFloat,
    palette: (hi: RGB, mid: RGB, low: RGB, deep: RGB)
) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angleRadians)
    let rect = CGRect(x: 0, y: -width / 2, width: length, height: width)
    let path = CGPath(roundedRect: rect, cornerWidth: width * 0.25, cornerHeight: width * 0.25, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -length * 0.1), blur: length * 0.18,
                  color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55))
    ctx.addPath(path)
    ctx.setFillColor(palette.mid.cg)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    ctx.addPath(path)
    ctx.clip()
    let colors = [palette.hi.cg, palette.mid.cg, palette.low.cg] as CFArray
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
        ctx.drawLinearGradient(g,
            start: CGPoint(x: 0, y: -width / 2),
            end: CGPoint(x: 0, y: width / 2),
            options: [])
    }
    ctx.restoreGState()
}

// Approximation of a trefoil knot in 2D using parametric path + bevel.
func drawCopperTrefoil(
    _ ctx: CGContext,
    center: CGPoint,
    radius: CGFloat,
    tubeWidth: CGFloat
) {
    let pal: (hi: RGB, mid: RGB, low: RGB, deep: RGB) = (
        Palette.copperHi, Palette.copperMid, Palette.copperLow, Palette.copperDeep
    )

    let path = CGMutablePath()
    let steps = 720
    var first = true
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        // 2D trefoil-knot projection
        let x = center.x + radius * (sin(t) + 2 * sin(2 * t)) / 3.0
        let y = center.y + radius * (cos(t) - 2 * cos(2 * t)) / 3.0
        if first { path.move(to: CGPoint(x: x, y: y)); first = false }
        else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()

    // Shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -tubeWidth * 0.6),
        blur: tubeWidth * 1.4,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.65)
    )
    ctx.setLineWidth(tubeWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setStrokeColor(pal.deep.cg)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    // Base
    ctx.saveGState()
    ctx.setLineWidth(tubeWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setStrokeColor(pal.mid.cg)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    // Gradient overlay
    ctx.saveGState()
    let stroked = path.copy(strokingWithWidth: tubeWidth, lineCap: .round, lineJoin: .round, miterLimit: 2)
    ctx.addPath(stroked)
    ctx.clip()
    let colors = [pal.hi.cg, pal.mid.cg, pal.low.cg, pal.deep.cg] as CFArray
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                          locations: [0, 0.45, 0.78, 1]) {
        ctx.drawLinearGradient(g,
            start: CGPoint(x: center.x, y: center.y + radius),
            end: CGPoint(x: center.x, y: center.y - radius),
            options: [])
    }
    ctx.restoreGState()

    // Brushed grain inside
    var rng = DeterministicRNG(seed: 0xCAFE_BABE_0F01)
    ctx.saveGState()
    ctx.addPath(stroked)
    ctx.clip()
    for _ in 0..<600 {
        let x = center.x - radius * 1.3 + rng.unit() * radius * 2.6
        let y = center.y - radius * 1.3 + rng.unit() * radius * 2.6
        let len = rng.range(tubeWidth * 0.2, tubeWidth * 0.9)
        let alpha = rng.range(0.03, 0.10)
        let bright = rng.unit() < 0.5
        ctx.setStrokeColor((bright ? pal.hi : pal.deep).with(alpha: alpha).cg)
        ctx.setLineWidth(rng.range(0.5, 1.4))
        let angle = rng.range(0, 2 * .pi)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + cos(angle) * len, y: y + sin(angle) * len))
        ctx.strokePath()
    }
    ctx.restoreGState()
}

// MARK: - Asset implementations

func drawAppIcon(path: URL) {
    let size = CGSize(width: 1024, height: 1024)
    let ctx = makeContext(size, opaque: true)
    let rect = CGRect(origin: .zero, size: size)
    fillBackground(ctx, size: size, color: Palette.obsidian)
    radialGradient(ctx, rect: rect, inner: Palette.obsidianTint, outer: Palette.obsidian,
                   centerOffset: CGPoint(x: 0, y: 60), radiusScale: 0.75)
    // Soft warm glow
    let warmGlow = RGB(r: 0.55, g: 0.30, b: 0.15, a: 0.55)
    radialGradient(ctx, rect: rect, inner: warmGlow, outer: Palette.obsidian.with(alpha: 0),
                   centerOffset: .zero, radiusScale: 0.55)

    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let ringR: CGFloat = 220
    let tube: CGFloat = 64
    // Two silver C rings interlocked, copper trefoil center
    drawRingC(ctx, center: CGPoint(x: center.x - 145, y: center.y - 20),
              outerRadius: ringR, tubeWidth: tube, gapDegrees: 80,
              rotationDegrees: -10,
              palette: (Palette.silverHi, Palette.silverMid, Palette.silverLow, Palette.silverDeep))
    drawRingC(ctx, center: CGPoint(x: center.x + 145, y: center.y - 20),
              outerRadius: ringR, tubeWidth: tube, gapDegrees: 80,
              rotationDegrees: 170,
              palette: (Palette.silverHi, Palette.silverMid, Palette.silverLow, Palette.silverDeep))
    drawCopperTrefoil(ctx,
                      center: CGPoint(x: center.x, y: center.y + 30),
                      radius: 175,
                      tubeWidth: 70)

    guard let image = ctx.makeImage() else { fatalError("icon image") }
    saveCGImage(image, to: path)
}

func drawBrandMark(path: URL, size: CGFloat = 2048) {
    let s = CGSize(width: size, height: size)
    let ctx = makeContext(s, opaque: false)
    let center = CGPoint(x: size / 2, y: size / 2)
    let ringR = size * 0.22
    let tube = ringR * 0.30
    drawRingC(ctx, center: CGPoint(x: center.x - size * 0.14, y: center.y - size * 0.02),
              outerRadius: ringR, tubeWidth: tube, gapDegrees: 80, rotationDegrees: -10,
              palette: (Palette.silverHi, Palette.silverMid, Palette.silverLow, Palette.silverDeep))
    drawRingC(ctx, center: CGPoint(x: center.x + size * 0.14, y: center.y - size * 0.02),
              outerRadius: ringR, tubeWidth: tube, gapDegrees: 80, rotationDegrees: 170,
              palette: (Palette.silverHi, Palette.silverMid, Palette.silverLow, Palette.silverDeep))
    drawCopperTrefoil(ctx, center: CGPoint(x: center.x, y: center.y + size * 0.03),
                      radius: size * 0.175, tubeWidth: size * 0.07)
    guard let image = ctx.makeImage() else { fatalError("brand mark") }
    saveCGImage(image, to: path)
}

func drawHomeHero(path: URL) {
    let size = CGSize(width: 2048, height: 2048)
    let ctx = makeContext(size, opaque: false)
    let center = CGPoint(x: size.width / 2, y: size.height / 2)

    // Cluster of silver C-rings + copper trefoil in centre
    let outer = CGFloat(360)
    let tube = CGFloat(110)
    let ringPositions: [(CGFloat, CGFloat, CGFloat)] = [
        (-1.0, -0.7, -45),
        ( 1.0, -0.7,  225),
        (-1.0,  0.7, -135),
        ( 1.0,  0.7,  135),
        ( 0.0, -1.25, 0),
        ( 0.0,  1.25, 180)
    ]
    let radius = CGFloat(520)
    for entry in ringPositions {
        let cx = center.x + entry.0 * radius
        let cy = center.y + entry.1 * radius
        drawRingC(ctx,
                  center: CGPoint(x: cx, y: cy),
                  outerRadius: outer,
                  tubeWidth: tube,
                  gapDegrees: 80,
                  rotationDegrees: entry.2,
                  palette: (Palette.silverHi, Palette.silverMid, Palette.silverLow, Palette.silverDeep))
    }
    drawCopperTrefoil(ctx, center: center, radius: 360, tubeWidth: 140)
    guard let image = ctx.makeImage() else { fatalError("home hero") }
    saveCGImage(image, to: path)
}

func drawLevelCompleteEmblem(path: URL) {
    let size = CGSize(width: 1024, height: 1024)
    let ctx = makeContext(size, opaque: false)
    let center = CGPoint(x: size.width / 2, y: size.height / 2)

    // Soft burst behind
    var rng = DeterministicRNG(seed: 0xC0FFEE_BEAD_0001)
    for _ in 0..<48 {
        let angle = rng.range(0, .pi * 2)
        let len = rng.range(240, 460)
        let width = rng.range(3, 9)
        let x1 = center.x + cos(angle) * 80
        let y1 = center.y + sin(angle) * 80
        let x2 = center.x + cos(angle) * len
        let y2 = center.y + sin(angle) * len
        ctx.setStrokeColor(Palette.copperHi.with(alpha: rng.range(0.10, 0.30)).cg)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addLine(to: CGPoint(x: x2, y: y2))
        ctx.strokePath()
    }

    // Center trefoil emblem
    drawCopperTrefoil(ctx, center: center, radius: 200, tubeWidth: 78)
    guard let image = ctx.makeImage() else { fatalError("emblem") }
    saveCGImage(image, to: path)
}

// Materials

func drawBrushedTile(path: URL, base: RGB, hi: RGB, lo: RGB, seed: UInt64) {
    let size = CGSize(width: 1024, height: 1024)
    let ctx = makeContext(size, opaque: true)
    let rect = CGRect(origin: .zero, size: size)
    drawBrushedMetal(ctx, rect: rect, base: base, highlight: hi, shadow: lo, seed: seed)
    guard let image = ctx.makeImage() else { fatalError("material \(path.path)") }
    saveCGImage(image, to: path)
}

func drawObsidianTile(path: URL) {
    let size = CGSize(width: 1024, height: 1024)
    let ctx = makeContext(size, opaque: true)
    let rect = CGRect(origin: .zero, size: size)
    fillBackground(ctx, size: size, color: Palette.obsidianDeep)
    var rng = DeterministicRNG(seed: 0xB1AC_70B5_1D1A_4001)
    for _ in 0..<3200 {
        let x = rng.unit() * size.width
        let y = rng.unit() * size.height
        let r = rng.range(0.3, 1.4)
        ctx.setFillColor(Palette.obsidianTint.with(alpha: rng.range(0.05, 0.2)).cg)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }
    // Subtle scratch streaks
    for _ in 0..<60 {
        let y = rng.unit() * size.height
        let len = rng.range(140, 360)
        let x = rng.unit() * size.width
        ctx.setStrokeColor(Palette.obsidianTint.with(alpha: rng.range(0.06, 0.18)).cg)
        ctx.setLineWidth(rng.range(0.8, 1.5))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + len, y: y + rng.range(-2, 2)))
        ctx.strokePath()
    }
    _ = rect
    guard let image = ctx.makeImage() else { fatalError("obsidian") }
    saveCGImage(image, to: path)
}

func drawConnectorClip(path: URL, copper: Bool) {
    let size = CGSize(width: 512, height: 512)
    let ctx = makeContext(size, opaque: false)
    let pal: (hi: RGB, mid: RGB, low: RGB, deep: RGB) = copper
        ? (Palette.copperHi, Palette.copperMid, Palette.copperLow, Palette.copperDeep)
        : (Palette.silverHi, Palette.silverMid, Palette.silverLow, Palette.silverDeep)
    drawTab(ctx,
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            angleRadians: 0,
            length: 280,
            width: 130,
            palette: pal)
    guard let image = ctx.makeImage() else { fatalError("clip") }
    saveCGImage(image, to: path)
}

// Backgrounds

func drawGameplayBackground(path: URL) {
    let size = CGSize(width: 2048, height: 3072)
    let ctx = makeContext(size, opaque: true)
    let rect = CGRect(origin: .zero, size: size)
    fillBackground(ctx, size: size, color: Palette.obsidianDeep)
    radialGradient(ctx, rect: rect, inner: Palette.obsidianTint, outer: Palette.obsidianDeep,
                   centerOffset: CGPoint(x: 0, y: -size.height * 0.05), radiusScale: 0.7)

    var rng = DeterministicRNG(seed: 0x6A8E_BEAD_1234_AA)
    // Subtle vertical streaks
    for _ in 0..<260 {
        let x = rng.unit() * size.width
        let h = rng.range(80, 380)
        let y = rng.unit() * size.height
        ctx.setStrokeColor(Palette.obsidianTint.with(alpha: rng.range(0.04, 0.10)).cg)
        ctx.setLineWidth(rng.range(0.6, 1.3))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + rng.range(-1, 1), y: y + h))
        ctx.strokePath()
    }
    // Specks
    for _ in 0..<2400 {
        let x = rng.unit() * size.width
        let y = rng.unit() * size.height
        let r = rng.range(0.4, 1.6)
        ctx.setFillColor(Palette.obsidianTint.with(alpha: rng.range(0.04, 0.18)).cg)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }
    // Soft vignette
    let vignette = RGB(r: 0, g: 0, b: 0, a: 0.65)
    radialGradient(ctx, rect: rect, inner: RGB(r: 0, g: 0, b: 0, a: 0), outer: vignette,
                   centerOffset: .zero, radiusScale: 0.95)
    guard let image = ctx.makeImage() else { fatalError("bg gameplay") }
    saveCGImage(image, to: path)
}

func drawMenuBackground(path: URL) {
    let size = CGSize(width: 2048, height: 3072)
    let ctx = makeContext(size, opaque: true)
    let rect = CGRect(origin: .zero, size: size)
    fillBackground(ctx, size: size, color: Palette.obsidianDeep)
    radialGradient(ctx, rect: rect, inner: Palette.obsidianTint, outer: Palette.obsidianDeep,
                   centerOffset: CGPoint(x: 0, y: -size.height * 0.2), radiusScale: 0.7)
    // Copper bottom glow
    let glow = RGB(r: 0.42, g: 0.22, b: 0.08, a: 0.55)
    radialGradient(ctx, rect: rect, inner: glow, outer: Palette.obsidianDeep.with(alpha: 0),
                   centerOffset: CGPoint(x: 0, y: -size.height * 0.42), radiusScale: 0.55)
    var rng = DeterministicRNG(seed: 0xDEC0_DEAD_BEEF_BB)
    for _ in 0..<2200 {
        let x = rng.unit() * size.width
        let y = rng.unit() * size.height
        let r = rng.range(0.4, 1.6)
        ctx.setFillColor(Palette.obsidianTint.with(alpha: rng.range(0.04, 0.18)).cg)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }
    let vignette = RGB(r: 0, g: 0, b: 0, a: 0.7)
    radialGradient(ctx, rect: rect, inner: RGB(r: 0, g: 0, b: 0, a: 0), outer: vignette,
                   centerOffset: .zero, radiusScale: 0.95)
    guard let image = ctx.makeImage() else { fatalError("bg menu") }
    saveCGImage(image, to: path)
}

func drawCompletionBackground(path: URL) {
    let size = CGSize(width: 2048, height: 3072)
    let ctx = makeContext(size, opaque: true)
    let rect = CGRect(origin: .zero, size: size)
    fillBackground(ctx, size: size, color: Palette.obsidianDeep)
    radialGradient(ctx, rect: rect,
                   inner: RGB(r: 0.55, g: 0.30, b: 0.12, a: 0.7),
                   outer: Palette.obsidianDeep,
                   centerOffset: .zero, radiusScale: 0.7)
    var rng = DeterministicRNG(seed: 0xFADE_C0DE_5555)
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    for _ in 0..<160 {
        let a = rng.range(0, .pi * 2)
        let r1 = rng.range(100, 240)
        let r2 = rng.range(640, 1480)
        let w = rng.range(2, 7)
        ctx.setStrokeColor(Palette.copperHi.with(alpha: rng.range(0.05, 0.25)).cg)
        ctx.setLineWidth(w)
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1))
        ctx.addLine(to: CGPoint(x: center.x + cos(a) * r2, y: center.y + sin(a) * r2))
        ctx.strokePath()
    }
    let vignette = RGB(r: 0, g: 0, b: 0, a: 0.7)
    radialGradient(ctx, rect: rect, inner: RGB(r: 0, g: 0, b: 0, a: 0), outer: vignette,
                   centerOffset: .zero, radiusScale: 1.0)
    guard let image = ctx.makeImage() else { fatalError("bg completion") }
    saveCGImage(image, to: path)
}

// FX

func drawSelectionGlow(path: URL) {
    let size = CGSize(width: 1024, height: 1024)
    let ctx = makeContext(size, opaque: false)
    let rect = CGRect(origin: .zero, size: size)
    radialGradient(ctx, rect: rect,
                   inner: Palette.selectionGlow.with(alpha: 0.95),
                   outer: Palette.selectionGlow.with(alpha: 0),
                   centerOffset: .zero, radiusScale: 0.55)
    radialGradient(ctx, rect: rect,
                   inner: RGB(r: 0.9, g: 0.98, b: 1.0, a: 1.0),
                   outer: Palette.selectionGlow.with(alpha: 0),
                   centerOffset: .zero, radiusScale: 0.25)
    guard let image = ctx.makeImage() else { fatalError("glow") }
    saveCGImage(image, to: path)
}

func drawReleaseStreak(path: URL) {
    let size = CGSize(width: 1024, height: 512)
    let ctx = makeContext(size, opaque: false)
    // Horizontal streak: faded both ends, bright center
    let stops: [(RGB, CGFloat)] = [
        (RGB(r: 1, g: 1, b: 1, a: 0), 0.0),
        (RGB(r: 1, g: 0.95, b: 0.85, a: 0.0), 0.05),
        (RGB(r: 1, g: 0.95, b: 0.85, a: 0.95), 0.5),
        (RGB(r: 1, g: 0.95, b: 0.85, a: 0.0), 0.95),
        (RGB(r: 1, g: 1, b: 1, a: 0), 1.0)
    ]
    let cs = CGColorSpaceCreateDeviceRGB()
    if let g = CGGradient(colorsSpace: cs, colors: stops.map { $0.0.cg } as CFArray,
                          locations: stops.map { $0.1 }) {
        ctx.saveGState()
        let path2 = CGMutablePath()
        path2.addRoundedRect(in: CGRect(x: 0, y: size.height * 0.30,
                                        width: size.width, height: size.height * 0.40),
                             cornerWidth: size.height * 0.20,
                             cornerHeight: size.height * 0.20)
        ctx.addPath(path2)
        ctx.clip()
        ctx.drawLinearGradient(g,
            start: CGPoint(x: 0, y: size.height / 2),
            end: CGPoint(x: size.width, y: size.height / 2),
            options: [])
        ctx.restoreGState()
    }
    guard let image = ctx.makeImage() else { fatalError("streak") }
    saveCGImage(image, to: path)
}

func drawMetalSpark(path: URL) {
    let size = CGSize(width: 512, height: 512)
    let ctx = makeContext(size, opaque: false)
    let rect = CGRect(origin: .zero, size: size)
    radialGradient(ctx, rect: rect,
                   inner: RGB(r: 1, g: 1, b: 1, a: 0.95),
                   outer: RGB(r: 1, g: 0.85, b: 0.45, a: 0),
                   centerOffset: .zero, radiusScale: 0.45)
    // Cross flare
    ctx.saveGState()
    ctx.translateBy(x: size.width / 2, y: size.height / 2)
    for angle in stride(from: 0.0, to: .pi, by: .pi / 4) {
        ctx.saveGState()
        ctx.rotate(by: CGFloat(angle))
        let rect2 = CGRect(x: -size.width * 0.5, y: -2.5, width: size.width, height: 5)
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [
                                RGB(r: 1, g: 1, b: 1, a: 0).cg,
                                RGB(r: 1, g: 0.95, b: 0.7, a: 0.8).cg,
                                RGB(r: 1, g: 1, b: 1, a: 0).cg
                              ] as CFArray,
                              locations: [0, 0.5, 1]) {
            ctx.addRect(rect2)
            ctx.clip()
            ctx.drawLinearGradient(g, start: CGPoint(x: rect2.minX, y: 0),
                                      end: CGPoint(x: rect2.maxX, y: 0), options: [])
        }
        ctx.restoreGState()
    }
    ctx.restoreGState()
    guard let image = ctx.makeImage() else { fatalError("spark") }
    saveCGImage(image, to: path)
}

func drawInvalidShockwave(path: URL) {
    let size = CGSize(width: 1024, height: 1024)
    let ctx = makeContext(size, opaque: false)
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    for i in 0..<5 {
        let r = CGFloat(i + 1) * 70 + 60
        let alpha = 0.35 - CGFloat(i) * 0.06
        ctx.setStrokeColor(Palette.invalidRed.with(alpha: alpha).cg)
        ctx.setLineWidth(CGFloat(10 - i * 2))
        ctx.beginPath()
        ctx.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()
    }
    guard let image = ctx.makeImage() else { fatalError("shock") }
    saveCGImage(image, to: path)
}

// UI icons

func drawArrow(path: URL) {
    let size = CGSize(width: 512, height: 512)
    let ctx = makeContext(size, opaque: false)
    // Arrow body pointing right
    let stem = CGRect(x: 60, y: 232, width: 320, height: 48)
    let stemPath = CGPath(roundedRect: stem, cornerWidth: 24, cornerHeight: 24, transform: nil)
    ctx.addPath(stemPath)
    let cs = CGColorSpaceCreateDeviceRGB()
    if let g = CGGradient(colorsSpace: cs,
                          colors: [Palette.copperHi.cg, Palette.copperMid.cg] as CFArray,
                          locations: [0, 1]) {
        ctx.saveGState()
        ctx.clip()
        ctx.drawLinearGradient(g, start: CGPoint(x: 60, y: 232),
                               end: CGPoint(x: 380, y: 280), options: [])
        ctx.restoreGState()
    }

    let head = CGMutablePath()
    head.move(to: CGPoint(x: 460, y: 256))
    head.addLine(to: CGPoint(x: 320, y: 380))
    head.addLine(to: CGPoint(x: 320, y: 132))
    head.closeSubpath()
    ctx.addPath(head)
    if let g = CGGradient(colorsSpace: cs,
                          colors: [Palette.copperHi.cg, Palette.copperMid.cg, Palette.copperLow.cg] as CFArray,
                          locations: [0, 0.5, 1]) {
        ctx.saveGState()
        ctx.clip()
        ctx.drawLinearGradient(g, start: CGPoint(x: 320, y: 132),
                               end: CGPoint(x: 460, y: 380), options: [])
        ctx.restoreGState()
    }
    guard let image = ctx.makeImage() else { fatalError("arrow") }
    saveCGImage(image, to: path)
}

func drawHintPulse(path: URL) {
    let size = CGSize(width: 512, height: 512)
    let ctx = makeContext(size, opaque: false)
    let rect = CGRect(origin: .zero, size: size)
    radialGradient(ctx, rect: rect,
                   inner: Palette.hintGlow.with(alpha: 0.9),
                   outer: Palette.hintGlow.with(alpha: 0),
                   centerOffset: .zero, radiusScale: 0.45)
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    ctx.setStrokeColor(Palette.hintGlow.with(alpha: 0.85).cg)
    ctx.setLineWidth(6)
    ctx.beginPath()
    ctx.addArc(center: center, radius: 130, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    guard let image = ctx.makeImage() else { fatalError("hint") }
    saveCGImage(image, to: path)
}

func drawIconButton(path: URL, kind: String) {
    let size = CGSize(width: 512, height: 512)
    let ctx = makeContext(size, opaque: false)
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    // Background pill
    let bgPath = CGPath(ellipseIn: CGRect(x: 32, y: 32, width: 448, height: 448), transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
                  color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55))
    ctx.addPath(bgPath)
    ctx.setFillColor(Palette.obsidianTint.cg)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(bgPath)
    let cs = CGColorSpaceCreateDeviceRGB()
    if let g = CGGradient(colorsSpace: cs,
                          colors: [Palette.obsidianTint.cg, Palette.obsidianDeep.cg] as CFArray,
                          locations: [0, 1]) {
        ctx.saveGState()
        ctx.clip()
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0),
                               end: CGPoint(x: 0, y: size.height), options: [])
        ctx.restoreGState()
    }
    // Glyph
    let stroke = Palette.silverHi.with(alpha: 0.92).cg
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(28)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    switch kind {
    case "restart":
        let r: CGFloat = 130
        ctx.beginPath()
        ctx.addArc(center: center, radius: r, startAngle: .pi * 0.18, endAngle: .pi * 1.92, clockwise: false)
        ctx.strokePath()
        // Arrowhead
        let tipX = center.x + cos(.pi * 1.92) * r
        let tipY = center.y + sin(.pi * 1.92) * r
        let p = CGMutablePath()
        p.move(to: CGPoint(x: tipX + 12, y: tipY + 56))
        p.addLine(to: CGPoint(x: tipX - 50, y: tipY - 4))
        p.addLine(to: CGPoint(x: tipX + 70, y: tipY - 26))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(stroke)
        ctx.fillPath()
    case "back":
        let p = CGMutablePath()
        p.move(to: CGPoint(x: center.x + 60, y: center.y - 110))
        p.addLine(to: CGPoint(x: center.x - 60, y: center.y))
        p.addLine(to: CGPoint(x: center.x + 60, y: center.y + 110))
        ctx.addPath(p)
        ctx.strokePath()
    case "next":
        let p = CGMutablePath()
        p.move(to: CGPoint(x: center.x - 60, y: center.y - 110))
        p.addLine(to: CGPoint(x: center.x + 60, y: center.y))
        p.addLine(to: CGPoint(x: center.x - 60, y: center.y + 110))
        ctx.addPath(p)
        ctx.strokePath()
    case "hint":
        // Light bulb (geometric)
        let bulb = CGPath(ellipseIn: CGRect(x: center.x - 100, y: center.y - 130,
                                            width: 200, height: 200), transform: nil)
        ctx.addPath(bulb)
        ctx.strokePath()
        let base = CGRect(x: center.x - 60, y: center.y + 70, width: 120, height: 36)
        ctx.addPath(CGPath(roundedRect: base, cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.strokePath()
        let bottom = CGRect(x: center.x - 40, y: center.y + 110, width: 80, height: 30)
        ctx.addPath(CGPath(roundedRect: bottom, cornerWidth: 14, cornerHeight: 14, transform: nil))
        ctx.strokePath()
    default:
        break
    }
    guard let image = ctx.makeImage() else { fatalError("icon button") }
    saveCGImage(image, to: path)
}

// MARK: - Driver

func ensureDir(_ url: URL) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let root = cwd
let assetsRoot = root.appendingPathComponent("shared/assets")

let dirs = [
    "branding", "backgrounds", "materials", "fx", "ui"
].map { assetsRoot.appendingPathComponent($0) }
for d in dirs { ensureDir(d) }

print("Generating PNG assets to \(assetsRoot.path)")

drawAppIcon(path: assetsRoot.appendingPathComponent("branding/ring_knot_app_icon_master.png"))
drawBrandMark(path: assetsRoot.appendingPathComponent("branding/ring_knot_brand_mark.png"))
drawHomeHero(path: assetsRoot.appendingPathComponent("branding/ring_knot_home_hero.png"))
drawLevelCompleteEmblem(path: assetsRoot.appendingPathComponent("branding/ring_knot_level_complete_emblem.png"))

drawBrushedTile(
    path: assetsRoot.appendingPathComponent("materials/material_brushed_silver_tile.png"),
    base: Palette.silverMid, hi: Palette.silverHi, lo: Palette.silverDeep,
    seed: 0x5117_4E12_AB
)
drawBrushedTile(
    path: assetsRoot.appendingPathComponent("materials/material_brushed_copper_tile.png"),
    base: Palette.copperMid, hi: Palette.copperHi, lo: Palette.copperDeep,
    seed: 0xC07A_5511_BC
)
drawObsidianTile(path: assetsRoot.appendingPathComponent("materials/material_dark_obsidian_tile.png"))
drawConnectorClip(path: assetsRoot.appendingPathComponent("materials/material_connector_clip_silver.png"), copper: false)
drawConnectorClip(path: assetsRoot.appendingPathComponent("materials/material_connector_clip_copper.png"), copper: true)

drawGameplayBackground(path: assetsRoot.appendingPathComponent("backgrounds/bg_gameplay_obsidian_portrait.png"))
drawMenuBackground(path: assetsRoot.appendingPathComponent("backgrounds/bg_menu_obsidian_portrait.png"))
drawCompletionBackground(path: assetsRoot.appendingPathComponent("backgrounds/bg_completion_dark_burst.png"))

drawSelectionGlow(path: assetsRoot.appendingPathComponent("fx/fx_ring_selection_glow.png"))
drawReleaseStreak(path: assetsRoot.appendingPathComponent("fx/fx_ring_release_streak.png"))
drawMetalSpark(path: assetsRoot.appendingPathComponent("fx/fx_metal_spark.png"))
drawInvalidShockwave(path: assetsRoot.appendingPathComponent("fx/fx_invalid_shockwave.png"))

drawArrow(path: assetsRoot.appendingPathComponent("ui/ui_drag_arrow_master.png"))
drawHintPulse(path: assetsRoot.appendingPathComponent("ui/ui_hint_pulse.png"))
drawIconButton(path: assetsRoot.appendingPathComponent("ui/ui_button_restart.png"), kind: "restart")
drawIconButton(path: assetsRoot.appendingPathComponent("ui/ui_button_back.png"), kind: "back")
drawIconButton(path: assetsRoot.appendingPathComponent("ui/ui_button_next.png"), kind: "next")
drawIconButton(path: assetsRoot.appendingPathComponent("ui/ui_button_hint.png"), kind: "hint")

print("Done.")
