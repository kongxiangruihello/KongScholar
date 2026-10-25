import AppKit

final class EvidenceCropView: NSView {
    let image: NSImage
    private var start: CGPoint?
    private var selection: CGRect?
    init(image: NSImage) { self.image = image; super.init(frame: NSRect(x: 0, y: 0, width: 660, height: 540)); setAccessibilityLabel("拖动选择影像证据区域；未选择时截取整页"); setAccessibilityRole(.image) }
    required init?(coder: NSCoder) { fatalError() }
    private var imageFrame: CGRect { let scale = min(bounds.width / max(image.size.width, 1), bounds.height / max(image.size.height, 1)); let size = NSSize(width: image.size.width * scale, height: image.size.height * scale); return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height) }
    override func draw(_ dirtyRect: NSRect) { NSColor.controlBackgroundColor.setFill(); bounds.fill(); image.draw(in: imageFrame); if let rect = selection { NSColor.controlAccentColor.withAlphaComponent(0.2).setFill(); rect.fill(); NSColor.controlAccentColor.setStroke(); NSBezierPath(rect: rect).stroke() } }
    override func mouseDown(with event: NSEvent) { let p = convert(event.locationInWindow, from: nil); if imageFrame.contains(p) { start = p; selection = nil; needsDisplay = true } }
    override func mouseDragged(with event: NSEvent) { guard let a = start else { return }; let b = convert(event.locationInWindow, from: nil); selection = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y)).intersection(imageFrame); needsDisplay = true }
    var normalizedSelection: CGRect { guard let rect = selection, rect.width >= 3, rect.height >= 3 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }; let box = imageFrame; return CGRect(x: (rect.minX-box.minX)/box.width, y: (box.maxY-rect.maxY)/box.height, width: rect.width/box.width, height: rect.height/box.height) }
}
