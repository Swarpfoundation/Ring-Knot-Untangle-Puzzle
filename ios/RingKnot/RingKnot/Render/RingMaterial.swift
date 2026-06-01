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

        let halfGap = (gapDegrees * .pi / 180) / 2
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
