#!/usr/bin/env swift

import Foundation
import AppKit
import CoreGraphics
import CoreText
import ImageIO

let size = 1024
let width = size
let height = size

// Create bitmap context
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 4 * width,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

// Flip coordinate system (Core Graphics is bottom-left origin)
context.translateBy(x: 0, y: CGFloat(height))
context.scaleBy(x: 1, y: -1)

// Background gradient
let gradientColors = [
    CGColor(red: 29/255, green: 29/255, blue: 95/255, alpha: 1),   // #1D1D5F
    CGColor(red: 48/255, green: 43/255, blue: 99/255, alpha: 1),   // #302b63
    CGColor(red: 29/255, green: 29/255, blue: 95/255, alpha: 1),   // #1D1D5F
]
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: gradientColors as CFArray,
    locations: [0, 0.5, 1]
)!

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: CGFloat(width), y: CGFloat(height)),
    options: []
)

// Draw "AZERTY" text
let azertyFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 130, nil)
let azertyAttrs: [NSAttributedString.Key: Any] = [
    .font: azertyFont,
    .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
]
let azertyStr = NSAttributedString(string: "AZERTY", attributes: azertyAttrs)
let azertyLine = CTLineCreateWithAttributedString(azertyStr)
let azertyBounds = CTLineGetBoundsWithOptions(azertyLine, .useOpticalBounds)

context.saveGState()
context.textPosition = CGPoint(
    x: (CGFloat(width) - azertyBounds.width) / 2,
    y: CGFloat(height) - 680
)
CTLineDraw(azertyLine, context)
context.restoreGState()

// Draw "Snacks" text in orange
let snacksFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 85, nil)
let snacksAttrs: [NSAttributedString.Key: Any] = [
    .font: snacksFont,
    .foregroundColor: CGColor(red: 207/255, green: 74/255, blue: 12/255, alpha: 1) // #CF4A0C
]
let snacksStr = NSAttributedString(string: "Snacks", attributes: snacksAttrs)
let snacksLine = CTLineCreateWithAttributedString(snacksStr)
let snacksBounds = CTLineGetBoundsWithOptions(snacksLine, .useOpticalBounds)

context.saveGState()
context.textPosition = CGPoint(
    x: (CGFloat(width) - snacksBounds.width) / 2,
    y: CGFloat(height) - 800
)
CTLineDraw(snacksLine, context)
context.restoreGState()

// Draw fries emoji as text (🍟)
let emojiFont = CTFontCreateWithName("Apple Color Emoji" as CFString, 280, nil)
let emojiAttrs: [NSAttributedString.Key: Any] = [
    .font: emojiFont,
]
let emojiStr = NSAttributedString(string: "🍟", attributes: emojiAttrs)
let emojiLine = CTLineCreateWithAttributedString(emojiStr)
let emojiBounds = CTLineGetBoundsWithOptions(emojiLine, .useOpticalBounds)

context.saveGState()
context.textPosition = CGPoint(
    x: (CGFloat(width) - emojiBounds.width) / 2,
    y: CGFloat(height) - 440
)
CTLineDraw(emojiLine, context)
context.restoreGState()

// Orange accent line
context.setFillColor(CGColor(red: 207/255, green: 74/255, blue: 12/255, alpha: 1))
context.fill(CGRect(x: 362, y: height - 878, width: 300, height: 8))

// Export as PNG
guard let image = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "appicon-1024.png"
let url = URL(fileURLWithPath: outputPath)

guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    print("Failed to create image destination")
    exit(1)
}

CGImageDestinationAddImage(dest, image, nil)
if CGImageDestinationFinalize(dest) {
    print("Icon saved to: \(outputPath)")
} else {
    print("Failed to save icon")
    exit(1)
}
