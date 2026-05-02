#!/usr/bin/env swift

import AppKit
import CoreGraphics

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Background - deep navy blue with rounded rect
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.185
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(bgPath)
    context.setFillColor(CGColor(red: 0.10, green: 0.15, blue: 0.30, alpha: 1.0))
    context.fillPath()

    // Subtle gradient overlay for depth
    let gradientColors = [
        CGColor(red: 0.15, green: 0.22, blue: 0.40, alpha: 0.6),
        CGColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 0.6)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0.0, 1.0]) {
        context.saveGState()
        context.addPath(bgPath)
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
        context.restoreGState()
    }

    // Draw a PDF document icon (left side - the source doc)
    let docW = s * 0.32
    let docH = s * 0.42
    let docX = s * 0.12
    let docY = s * 0.30
    let foldSize = s * 0.08

    // Document body with dog-ear
    context.beginPath()
    context.move(to: CGPoint(x: docX, y: docY))
    context.addLine(to: CGPoint(x: docX + docW - foldSize, y: docY))
    context.addLine(to: CGPoint(x: docX + docW, y: docY + foldSize))
    context.addLine(to: CGPoint(x: docX + docW, y: docY + docH))
    context.addLine(to: CGPoint(x: docX, y: docY + docH))
    context.closePath()
    context.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0))
    context.fillPath()

    // Dog-ear fold
    context.beginPath()
    context.move(to: CGPoint(x: docX + docW - foldSize, y: docY))
    context.addLine(to: CGPoint(x: docX + docW - foldSize, y: docY + foldSize))
    context.addLine(to: CGPoint(x: docX + docW, y: docY + foldSize))
    context.closePath()
    context.setFillColor(CGColor(red: 0.80, green: 0.82, blue: 0.86, alpha: 1.0))
    context.fillPath()

    // Text lines on document
    let lineColor = CGColor(red: 0.65, green: 0.68, blue: 0.72, alpha: 1.0)
    context.setFillColor(lineColor)
    let lineH = s * 0.018
    let lineSpacing = s * 0.04
    for i in 0..<6 {
        let ly = docY + s * 0.08 + CGFloat(i) * lineSpacing
        let lw = (i == 2) ? docW * 0.5 : docW * 0.7
        let rect = CGRect(x: docX + s * 0.03, y: ly, width: lw, height: lineH)
        context.fill(rect)
    }

    // Scissors / split symbol in center
    let splitX = s * 0.48
    let splitY1 = s * 0.38
    let splitY2 = s * 0.62

    // Dashed vertical line
    context.setStrokeColor(CGColor(red: 0.90, green: 0.35, blue: 0.30, alpha: 1.0))
    context.setLineWidth(s * 0.015)
    context.setLineDash(phase: 0, lengths: [s * 0.025, s * 0.015])
    context.beginPath()
    context.move(to: CGPoint(x: splitX, y: splitY1))
    context.addLine(to: CGPoint(x: splitX, y: splitY2))
    context.strokePath()
    context.setLineDash(phase: 0, lengths: [])

    // Arrow pointing right from split line
    let arrowX = s * 0.52
    let arrowY = s * 0.50
    let arrowLen = s * 0.10
    let arrowHead = s * 0.035

    context.setStrokeColor(CGColor(red: 0.90, green: 0.35, blue: 0.30, alpha: 1.0))
    context.setLineWidth(s * 0.02)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // Arrow shaft
    context.beginPath()
    context.move(to: CGPoint(x: arrowX, y: arrowY))
    context.addLine(to: CGPoint(x: arrowX + arrowLen, y: arrowY))
    context.strokePath()

    // Arrow head
    context.beginPath()
    context.move(to: CGPoint(x: arrowX + arrowLen - arrowHead, y: arrowY - arrowHead))
    context.addLine(to: CGPoint(x: arrowX + arrowLen, y: arrowY))
    context.addLine(to: CGPoint(x: arrowX + arrowLen - arrowHead, y: arrowY + arrowHead))
    context.strokePath()

    // Two smaller output docs (right side, stacked)
    let smallW = s * 0.22
    let smallH = s * 0.16
    let smallX = s * 0.65
    let smallFold = s * 0.05

    // Top small doc
    let topY = s * 0.52
    drawMiniDoc(context: context, x: smallX, y: topY, w: smallW, h: smallH, fold: smallFold,
                fillColor: CGColor(red: 0.40, green: 0.75, blue: 0.55, alpha: 1.0))

    // Bottom small doc
    let botY = s * 0.32
    drawMiniDoc(context: context, x: smallX, y: botY, w: smallW, h: smallH, fold: smallFold,
                fillColor: CGColor(red: 0.35, green: 0.60, blue: 0.85, alpha: 1.0))

    // "PDF" label at bottom
    let fontSize = s * 0.09
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor(red: 0.85, green: 0.87, blue: 0.92, alpha: 0.8)
    ]
    let text = "PDF" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textX = (s - textSize.width) / 2
    let textY = s * 0.12
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

    // Gavel at top
    let gavelCenterX = s * 0.50
    let gavelCenterY = s * 0.82

    // Gavel head (horizontal rect)
    let ghW = s * 0.18
    let ghH = s * 0.06
    context.saveGState()
    context.translateBy(x: gavelCenterX, y: gavelCenterY)
    context.rotate(by: -0.3)
    let gavelHeadRect = CGRect(x: -ghW/2, y: -ghH/2, width: ghW, height: ghH)
    context.setFillColor(CGColor(red: 0.82, green: 0.68, blue: 0.45, alpha: 1.0))
    context.fill(gavelHeadRect)

    // Gavel handle
    let handleW = s * 0.025
    let handleH = s * 0.14
    let handleRect = CGRect(x: -handleW/2, y: -ghH/2 - handleH, width: handleW, height: handleH)
    context.setFillColor(CGColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 1.0))
    context.fill(handleRect)
    context.restoreGState()

    image.unlockFocus()
    return image
}

func drawMiniDoc(context: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, fold: CGFloat, fillColor: CGColor) {
    // Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 1, height: -1), blur: 3, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.3))

    context.beginPath()
    context.move(to: CGPoint(x: x, y: y))
    context.addLine(to: CGPoint(x: x + w - fold, y: y))
    context.addLine(to: CGPoint(x: x + w, y: y + fold))
    context.addLine(to: CGPoint(x: x + w, y: y + h))
    context.addLine(to: CGPoint(x: x, y: y + h))
    context.closePath()
    context.setFillColor(fillColor)
    context.fillPath()
    context.restoreGState()

    // Dog-ear
    context.beginPath()
    context.move(to: CGPoint(x: x + w - fold, y: y))
    context.addLine(to: CGPoint(x: x + w - fold, y: y + fold))
    context.addLine(to: CGPoint(x: x + w, y: y + fold))
    context.closePath()
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.3))
    context.fillPath()

    // Mini lines
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    let lh = h * 0.06
    for i in 0..<2 {
        let ly = y + h * 0.3 + CGFloat(i) * h * 0.2
        context.fill(CGRect(x: x + w * 0.12, y: ly, width: w * 0.6, height: lh))
    }
}

func savePNG(image: NSImage, size: Int, path: String) {
    let bitmap = NSBitmapImageRep(
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
    )!
    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Generated: \(path) (\(size)x\(size))")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] :
    FileManager.default.currentDirectoryPath

for size in sizes {
    let icon = generateIcon(size: size)
    let path = "\(outputDir)/icon_\(size).png"
    savePNG(image: icon, size: size, path: path)
}

print("Icon generation complete!")
