import AppKit
func bitmap(_ w: Int, _ h: Int) -> NSBitmapImageRep { return NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)! }
func save(_ rep: NSBitmapImageRep, _ path: String) { try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path)) }
func check(_ s: CGFloat, _ color: NSColor, ring: Bool) {
    color.set()
    if ring { let p = NSBezierPath(ovalIn: NSRect(x: s*0.14, y: s*0.14, width: s*0.72, height: s*0.72)); p.lineWidth = s*0.08; p.stroke() }
    let c = NSBezierPath(); c.lineWidth = s*0.11; c.lineCapStyle = .round; c.lineJoinStyle = .round
    c.move(to: NSPoint(x: s*0.30, y: s*0.50)); c.line(to: NSPoint(x: s*0.45, y: s*0.35)); c.line(to: NSPoint(x: s*0.71, y: s*0.64)); c.stroke()
}
func icon(_ size: Int, _ path: String) {
    let rep = bitmap(size, size); NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size)
    NSGradient(starting: NSColor(deviceRed: 0.49, green: 0.72, blue: 0.14, alpha: 1), ending: NSColor(deviceRed: 0.30, green: 0.49, blue: 0.06, alpha: 1))!.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -90)
    let sh = NSShadow(); sh.shadowOffset = NSSize(width: 0, height: -s*0.02); sh.shadowBlurRadius = s*0.03; sh.shadowColor = NSColor(white: 0, alpha: 0.35); sh.set()
    check(s, NSColor.white, ring: true)
    NSGraphicsContext.restoreGraphicsState(); save(rep, path)
}
icon(57, "Icon.png"); icon(114, "Icon@2x.png"); icon(256, "Icon-preview.png")
func glyph(_ name: String, _ draw: (CGFloat) -> Void) { for (sz, suf) in [(30, ""), (60, "@2x")] { let rep = bitmap(sz, sz); NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep); NSColor.white.set(); draw(CGFloat(sz)); NSGraphicsContext.restoreGraphicsState(); save(rep, "\(name)\(suf).png") } }
glyph("tab-today") { s in check(s, .white, ring: true) }
glyph("tab-habits") { s in for i in 0..<3 { let y = s*0.16 + CGFloat(i)*s*0.27; let r = NSBezierPath(ovalIn: NSRect(x: s*0.08, y: y, width: s*0.18, height: s*0.18)); r.lineWidth = s*0.05; if i == 2 { r.stroke() } else { r.fill() }; NSBezierPath(roundedRect: NSRect(x: s*0.34, y: y + s*0.04, width: s*0.58, height: s*0.1), xRadius: s*0.05, yRadius: s*0.05).fill() } }
glyph("tab-review") { s in for (i, h) in [0.35, 0.6, 0.82].enumerated() { NSBezierPath(roundedRect: NSRect(x: s*0.1 + CGFloat(i)*s*0.3, y: s*0.1, width: s*0.2, height: s*CGFloat(h)), xRadius: s*0.03, yRadius: s*0.03).fill() } }
glyph("tab-focus") { s in NSBezierPath(ovalIn: NSRect(x: s*0.08, y: s*0.04, width: s*0.84, height: s*0.74)).fill(); for i in 0..<5 { let a = CGFloat.pi/2 + CGFloat(i-2)*0.62; let p = NSBezierPath(); p.move(to: NSPoint(x: s*0.5, y: s*0.68)); p.line(to: NSPoint(x: s*0.5 + cos(a)*s*0.3, y: s*0.68 + sin(a)*s*0.3)); p.lineWidth = s*0.1; p.lineCapStyle = .round; p.stroke() } }
print("icons ok")
