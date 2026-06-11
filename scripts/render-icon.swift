// Renderizza l'icona dell'app a 1024×1024 (stile squircle macOS):
// gradiente blu→teal dell'identità ContainerDeck + shippingbox bianco.
// Uso: swift scripts/render-icon.swift <output.png>
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let canvas: CGFloat = 1024

// Simbolo bianco preparato prima di entrare nel contesto principale.
let config = NSImage.SymbolConfiguration(pointSize: 430, weight: .semibold)
guard let symbol = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    fatalError("SF Symbol shippingbox.fill non disponibile")
}
let tinted = NSImage(size: symbol.size)
tinted.lockFocus()
symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
NSColor.white.set()
NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
tinted.unlockFocus()

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current = ctx

// Griglia icone macOS: squircle 824×824 centrato, raggio ~185.
let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: iconRect, xRadius: 185, yRadius: 185)

// Ombra morbida dietro lo squircle (come le icone di sistema).
NSGraphicsContext.saveGraphicsState()
let dropShadow = NSShadow()
dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
dropShadow.shadowBlurRadius = 26
dropShadow.shadowOffset = NSSize(width: 0, height: -14)
dropShadow.set()
NSColor.white.set()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()

// Base: gradiente diagonale blu → teal.
let base = NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.38, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.04, green: 0.66, blue: 0.60, alpha: 1)
])!
base.draw(in: squircle, angle: -55)

NSGraphicsContext.saveGraphicsState()
squircle.setClip()

// Riflesso superiore per dare profondità.
let gloss = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.30),
    NSColor.white.withAlphaComponent(0.02)
])!
gloss.draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)

// Vignettatura leggera in basso.
let vignette = NSGradient(colors: [
    NSColor.black.withAlphaComponent(0.16),
    NSColor.black.withAlphaComponent(0.0)
])!
vignette.draw(in: NSRect(x: 100, y: 100, width: 824, height: 280), angle: 90)

// Simbolo centrato con ombra in tinta.
let symbolShadow = NSShadow()
symbolShadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
symbolShadow.shadowBlurRadius = 24
symbolShadow.shadowOffset = NSSize(width: 0, height: -12)
symbolShadow.set()
let s = tinted.size
tinted.draw(in: NSRect(x: (canvas - s.width) / 2, y: (canvas - s.height) / 2, width: s.width, height: s.height))
NSGraphicsContext.restoreGraphicsState()

// Bordo interno chiaro, appena percettibile.
NSColor.white.withAlphaComponent(0.22).set()
let border = NSBezierPath(roundedRect: iconRect.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
border.lineWidth = 4
border.stroke()

NSGraphicsContext.current = nil
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Icona scritta in \(outputPath)")
