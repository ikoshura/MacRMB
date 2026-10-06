#!/usr/bin/env swift
// Masks icon2.png into the macOS icon squircle (superellipse n=5) with
// transparent corners — macOS Big Sur+ does NOT auto-round app icons;
// square icons render with sharp corners in alerts, Dock, and Finder.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let inPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/Users/abrar/Developer/icon2.png"
let outPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/Users/abrar/Developer/icon2-masked.png"
let size = 1024

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil)
else { fatalError("could not load \(inPath)") }

let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))

// Superellipse |x/a|^5 + |y/b|^5 <= 1, centered.
let a = Double(size) / 2
let b = a
let n = 5.0
let steps = 4096
var points: [CGPoint] = []
points.reserveCapacity(steps)
for i in 0..<steps {
    let t = 2.0 * Double.pi * Double(i) / Double(steps)
    let c = cos(t), s = sin(t)
    let x = a * (c < 0 ? -1.0 : 1.0) * pow(abs(c), 2.0 / n)
    let y = b * (s < 0 ? -1.0 : 1.0) * pow(abs(s), 2.0 / n)
    points.append(CGPoint(x: a + x, y: b + y))
}
let path = CGMutablePath()
path.addLines(between: points)
path.closeSubpath()

ctx.addPath(path)
ctx.clip()
ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size)))

guard let masked = ctx.makeImage() else { fatalError("render failed") }
guard let dest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("destination failed") }
CGImageDestinationAddImage(dest, masked, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("masked icon written to \(outPath)")
