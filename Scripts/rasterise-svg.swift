#!/usr/bin/env swift

// Rasterises an SVG to a PNG at a given pixel size, controlling the alpha channel.
//
// Quick Look (`qlmanage -t`) is the obvious tool and the wrong one: it composites onto white, so a
// shaped icon comes back with opaque white corners instead of transparency. Drawing through
// CoreGraphics lets the backing store be chosen, which is what the two icon sets need — and they
// need opposite things:
//
//   iOS     a full square with NO alpha sample. An alpha channel on the marketing icon is
//           ITMS-90717, a hard reject, and the system applies its own mask anyway.
//   macOS   the shaped icon WITH alpha, because nothing masks a Mac icon for you.
//
// Usage:  swift Scripts/rasterise-svg.swift <input.svg> <pixels> <output.png> [--opaque]

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 4, let pixels = Int(arguments[2]) else {
    FileHandle.standardError.write(Data("usage: rasterise-svg.swift <input.svg> <pixels> <output.png> [--opaque]\n".utf8))
    exit(2)
}

let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[3])
let wantsOpaque = arguments.contains("--opaque")

guard let image = NSImage(contentsOf: input) else {
    FileHandle.standardError.write(Data("error: could not load \(input.lastPathComponent)\n".utf8))
    exit(1)
}

// noneSkipLast writes three colour samples and no alpha sample, which is what makes the encoded PNG
// truecolour rather than truecolour-with-alpha.
let alphaInfo: CGImageAlphaInfo = wantsOpaque ? .noneSkipLast : .premultipliedLast
guard let context = CGContext(
    data: nil,
    width: pixels,
    height: pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: alphaInfo.rawValue
) else {
    FileHandle.standardError.write(Data("error: could not allocate a \(pixels)x\(pixels) context\n".utf8))
    exit(1)
}
context.interpolationQuality = .high

let bounds = CGRect(x: 0, y: 0, width: pixels, height: pixels)
if wantsOpaque {
    // The artwork covers the full square once the squircle clip is stripped, so this only makes the
    // invariant true rather than showing anywhere.
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.fill(bounds)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
image.draw(in: NSRect(origin: .zero, size: NSSize(width: pixels, height: pixels)),
           from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let rendered = context.makeImage() else {
    FileHandle.standardError.write(Data("error: could not snapshot the context\n".utf8))
    exit(1)
}
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("error: could not open \(output.lastPathComponent) for writing\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, rendered, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("error: could not encode \(output.lastPathComponent)\n".utf8))
    exit(1)
}
