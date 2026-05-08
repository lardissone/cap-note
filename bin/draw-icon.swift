#!/usr/bin/env swift
//
// Draw the CapNote app icon at a given size and write it to a PNG file.
//
// Usage: swift draw-icon.swift <size> <output.png>
//
// The icon is a black-and-white squircle with a stylized note:
// a rounded rectangle "page" containing three horizontal lines of text.
// It mirrors the SF Symbol `note.text` used by the menubar.

import AppKit
import Foundation

// MARK: - Argument parsing

let arguments = CommandLine.arguments
guard arguments.count == 3,
      let size = Int(arguments[1]),
      size > 0
else {
    FileHandle.standardError.write(Data("Usage: draw-icon.swift <size> <output.png>\n".utf8))
    exit(1)
}
let outputPath = arguments[2]

// MARK: - Drawing

let canvas = CGFloat(size)
let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

guard let context = NSGraphicsContext.current else {
    FileHandle.standardError.write(Data("Failed to obtain graphics context\n".utf8))
    exit(1)
}
context.imageInterpolation = .high
context.shouldAntialias = true

// Background squircle. The macOS Big Sur icon grid leaves a transparent
// margin around the rounded square so the shape lines up with the rest of
// the dock. We use ~10% padding all around.
let margin = canvas * 0.10
let squircleRect = NSRect(
    x: margin,
    y: margin,
    width: canvas - margin * 2,
    height: canvas - margin * 2
)
// Apple's icon corners sit around 22.4% of the squircle width.
let cornerRadius = squircleRect.width * 0.224
let squircle = NSBezierPath(
    roundedRect: squircleRect,
    xRadius: cornerRadius,
    yRadius: cornerRadius
)

NSColor.black.setFill()
squircle.fill()

// Foreground note. A rounded rectangle that takes up roughly the central
// 60% of the squircle, with three horizontal lines representing text.
let noteWidth = squircleRect.width * 0.56
let noteHeight = noteWidth * 1.20 // slight portrait ratio, like a sheet of paper
let noteRect = NSRect(
    x: squircleRect.midX - noteWidth / 2,
    y: squircleRect.midY - noteHeight / 2,
    width: noteWidth,
    height: noteHeight
)
let noteRadius = noteWidth * 0.10
let note = NSBezierPath(
    roundedRect: noteRect,
    xRadius: noteRadius,
    yRadius: noteRadius
)

NSColor.white.setFill()
note.fill()

// Three horizontal text lines inside the page. The third line is shorter
// to suggest the end of a paragraph, matching the `note.text` glyph.
NSColor.black.setStroke()
let lineThickness = noteHeight * 0.06
let lineInset = noteWidth * 0.18
let lineLeft = noteRect.minX + lineInset
let lineRightFull = noteRect.maxX - lineInset
let lineRightShort = lineLeft + (lineRightFull - lineLeft) * 0.55

// Vertical layout: split the page into thirds and put a line in each.
let lineSpacing = noteHeight * 0.22
let centerY = noteRect.midY
let lineYs: [CGFloat] = [
    centerY + lineSpacing,
    centerY,
    centerY - lineSpacing,
]
let lineEnds: [CGFloat] = [lineRightFull, lineRightFull, lineRightShort]

for (y, rightX) in zip(lineYs, lineEnds) {
    let path = NSBezierPath()
    path.lineWidth = lineThickness
    path.lineCapStyle = .round
    path.move(to: NSPoint(x: lineLeft, y: y))
    path.line(to: NSPoint(x: rightX, y: y))
    path.stroke()
}

image.unlockFocus()

// MARK: - Encoding

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Failed to encode PNG\n".utf8))
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
do {
    try pngData.write(to: outputURL)
} catch {
    FileHandle.standardError.write(Data("Failed to write \(outputPath): \(error)\n".utf8))
    exit(1)
}
