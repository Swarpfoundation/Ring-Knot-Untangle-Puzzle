import CoreGraphics
import Foundation
import SpriteKit
import UIKit

enum RingPalette {
    static let silverHighlight = UIColor(red: 0.94, green: 0.96, blue: 1.00, alpha: 1.0)
    static let silverBase      = UIColor(red: 0.74, green: 0.78, blue: 0.86, alpha: 1.0)
    static let silverShadow    = UIColor(red: 0.32, green: 0.36, blue: 0.46, alpha: 1.0)
    static let silverDeep      = UIColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1.0)

    static let copperHighlight = UIColor(red: 1.00, green: 0.88, blue: 0.66, alpha: 1.0)
    static let copperBase      = UIColor(red: 0.86, green: 0.55, blue: 0.30, alpha: 1.0)
    static let copperShadow    = UIColor(red: 0.46, green: 0.22, blue: 0.10, alpha: 1.0)
    static let copperDeep      = UIColor(red: 0.18, green: 0.08, blue: 0.04, alpha: 1.0)

    static let boardBackground = UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0)
    static let boardTint       = UIColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0)
    static let selectionGlow   = UIColor(red: 0.55, green: 0.85, blue: 1.00, alpha: 0.9)
    static let hintGlow        = UIColor(red: 1.00, green: 0.82, blue: 0.40, alpha: 0.9)
    /// Shown when a ring's gap is rolled into alignment with its exit — a bright
    /// "ready to pull" cyan-green that reads as distinct from selection.
    static let readyGlow       = UIColor(red: 0.45, green: 1.00, blue: 0.80, alpha: 0.95)
}

enum RingTextureFactory {
    static func texture(
        for kind: RingKind,
        gapDegrees: CGFloat,
        rotationRadians: CGFloat,
        diameter: CGFloat,
        tubeRatio: CGFloat = 0.18,
        scale: CGFloat = 2.0
    ) -> SKTexture {
        let pixelSize = max(64, Int((diameter * scale).rounded()))
        let size = CGSize(width: pixelSize, height: pixelSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            draw(
                into: ctx.cgContext,
                size: size,
                kind: kind,
                gapDegrees: gapDegrees,
                rotationRadians: rotationRadians,
                tubeRatio: tubeRatio
            )
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func draw(
        into ctx: CGContext,
        size: CGSize,
        kind: RingKind,
        gapDegrees: CGFloat,
        rotationRadians: CGFloat,
        tubeRatio: CGFloat
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2 * 0.94
        let tube = outer * tubeRatio
        let inner = outer - tube * 2
        let mid = (outer + inner) / 2

        // A gap of 0° (or less) means a fully closed ring — a closed anchor.
        let halfGap = max(0, gapDegrees) * .pi / 180 / 2
        let start = rotationRadians + halfGap
        let end = rotationRadians + (2 * .pi) - halfGap

        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: 2),
            blur: 6,
            color: UIColor.black.withAlphaComponent(0.55).cgColor
        )
        ctx.beginPath()
        ctx.addArc(center: center, radius: mid, startAngle: start, endAngle: end, clockwise: false)
        ctx.setLineWidth(tube * 2)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.9).cgColor)
        ctx.strokePath()
        ctx.restoreGState()

        let highlight: UIColor
        let base: UIColor
        let shadow: UIColor
        let deep: UIColor
        switch kind {
        case .silver:
            highlight = RingPalette.silverHighlight
            base = RingPalette.silverBase
            shadow = RingPalette.silverShadow
            deep = RingPalette.silverDeep
        case .copper:
            highlight = RingPalette.copperHighlight
            base = RingPalette.copperBase
            shadow = RingPalette.copperShadow
            deep = RingPalette.copperDeep
        }

        ctx.saveGState()
        ctx.beginPath()
        ctx.addArc(center: center, radius: mid, startAngle: start, endAngle: end, clockwise: false)
        ctx.setLineWidth(tube * 2)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(base.cgColor)
        ctx.strokePath()
        ctx.restoreGState()

        ctx.saveGState()
        let strokedPath = CGMutablePath()
        strokedPath.addArc(center: center, radius: mid, startAngle: start, endAngle: end, clockwise: false)
        let clipShape = strokedPath.copy(
            strokingWithWidth: tube * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        ctx.addPath(clipShape)
        ctx.clip()
        let colors = [highlight.cgColor, base.cgColor, shadow.cgColor, deep.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 0.45, 0.78, 1.0]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: center.x, y: center.y - outer),
                end: CGPoint(x: center.x, y: center.y + outer),
                options: []
            )
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.beginPath()
        ctx.addArc(center: center, radius: mid, startAngle: start, endAngle: end, clockwise: false)
        ctx.setLineWidth(tube * 0.55)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(highlight.withAlphaComponent(0.55).cgColor)
        let dashes: [CGFloat] = [tube * 1.5, tube * 0.9]
        ctx.setLineDash(phase: 0, lengths: dashes)
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Resolve a clip's material to a concrete (highlight, base, shadow) triple.
    /// `inherited` borrows the owner ring's metal; `darkSteel` is a gunmetal grey.
    static func clipColors(
        for material: ClipMaterial,
        owner: RingKind
    ) -> (highlight: UIColor, base: UIColor, shadow: UIColor) {
        switch material {
        case .silver:
            return (RingPalette.silverHighlight, RingPalette.silverBase, RingPalette.silverShadow)
        case .copper:
            return (RingPalette.copperHighlight, RingPalette.copperBase, RingPalette.copperShadow)
        case .darkSteel:
            return (UIColor(white: 0.62, alpha: 1),
                    UIColor(white: 0.40, alpha: 1),
                    UIColor(white: 0.18, alpha: 1))
        case .inherited:
            switch owner {
            case .silver:
                return (RingPalette.silverHighlight, RingPalette.silverBase, RingPalette.silverShadow)
            case .copper:
                return (RingPalette.copperHighlight, RingPalette.copperBase, RingPalette.copperShadow)
            }
        }
    }

    /// A small metallic clamp band drawn procedurally — no downloaded art. It has
    /// a brushed-metal gradient, a raised bevel, dark seam edges, and rivet
    /// ridges whose count/weight depend on `style`. `size.width` runs across the
    /// ring tube; `size.height` runs along the ring. Returned upright; the caller
    /// rotates it into place. (Phase 6B: bevel + per-style rivets.)
    static func clipTexture(
        for material: ClipMaterial,
        owner: RingKind,
        size: CGSize,
        style: ClampStyle = .shortBand,
        scale: CGFloat = 2.0
    ) -> SKTexture {
        let px = CGSize(width: max(16, size.width * scale), height: max(8, size.height * scale))
        let colors = clipColors(for: material, owner: owner)
        let renderer = UIGraphicsImageRenderer(size: px)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let inset: CGFloat = px.width * 0.06
            let rect = CGRect(x: inset, y: inset,
                              width: px.width - inset * 2, height: px.height - inset * 2)
            let radius = min(rect.width, rect.height) * 0.34

            // Drop shadow + base fill.
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: px.height * 0.08),
                         blur: px.height * 0.22,
                         color: UIColor.black.withAlphaComponent(0.65).cgColor)
            let body = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            cg.addPath(body.cgPath)
            cg.setFillColor(colors.base.cgColor)
            cg.fillPath()
            cg.restoreGState()

            // Brushed-metal vertical gradient clipped to the band.
            cg.saveGState()
            cg.addPath(body.cgPath)
            cg.clip()
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors.highlight.cgColor, colors.base.cgColor,
                         colors.shadow.cgColor, colors.shadow.cgColor] as CFArray,
                locations: [0.0, 0.42, 0.86, 1.0]
            )
            if let grad {
                cg.drawLinearGradient(
                    grad,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: [])
            }

            // Bevel: a bright top edge and a darker bottom edge inside the band.
            let bevelInset = rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.16)
            cg.setLineWidth(max(1, px.height * 0.06))
            cg.setStrokeColor(colors.highlight.withAlphaComponent(0.65).cgColor)
            cg.move(to: CGPoint(x: bevelInset.minX, y: bevelInset.minY))
            cg.addLine(to: CGPoint(x: bevelInset.maxX, y: bevelInset.minY))
            cg.strokePath()
            cg.setStrokeColor(colors.shadow.withAlphaComponent(0.7).cgColor)
            cg.move(to: CGPoint(x: bevelInset.minX, y: bevelInset.maxY))
            cg.addLine(to: CGPoint(x: bevelInset.maxX, y: bevelInset.maxY))
            cg.strokePath()

            // Rivet ridges. Wider/bridge clamps carry more ridges.
            let ridgeXs: [CGFloat]
            switch style {
            case .shortBand:   ridgeXs = [0.32, 0.68]
            case .rivetedBand: ridgeXs = [0.24, 0.5, 0.76]
            case .wideBand:    ridgeXs = [0.22, 0.42, 0.58, 0.78]
            case .bridgeBand:  ridgeXs = [0.2, 0.4, 0.6, 0.8]
            }
            cg.setLineCap(.round)
            cg.setStrokeColor(colors.shadow.withAlphaComponent(0.85).cgColor)
            cg.setLineWidth(max(1, px.width * 0.045))
            for fx in ridgeXs {
                let x = rect.minX + rect.width * fx
                cg.move(to: CGPoint(x: x, y: rect.minY + rect.height * 0.22))
                cg.addLine(to: CGPoint(x: x, y: rect.maxY - rect.height * 0.22))
            }
            cg.strokePath()
            // Tiny highlight next to each ridge for a forged look.
            cg.setStrokeColor(colors.highlight.withAlphaComponent(0.4).cgColor)
            cg.setLineWidth(max(1, px.width * 0.02))
            for fx in ridgeXs {
                let x = rect.minX + rect.width * fx - px.width * 0.03
                cg.move(to: CGPoint(x: x, y: rect.minY + rect.height * 0.28))
                cg.addLine(to: CGPoint(x: x, y: rect.maxY - rect.height * 0.28))
            }
            cg.strokePath()
            cg.restoreGState()

            // Crisp dark edge so adjacent rings/clips stay legible.
            cg.addPath(body.cgPath)
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(max(1, px.width * 0.05))
            cg.strokePath()
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }

    static func boardBackgroundTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            cg.setFillColor(RingPalette.boardBackground.cgColor)
            cg.fill(rect)
            let colors = [
                RingPalette.boardTint.cgColor,
                RingPalette.boardBackground.cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                cg.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    endRadius: max(size.width, size.height) * 0.7,
                    options: []
                )
            }
        }
        return SKTexture(image: image)
    }
}
