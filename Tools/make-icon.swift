import AppKit
let destination = CommandLine.arguments[1]
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor.clear.setFill(); NSRect(x:0,y:0,width:CGFloat(size),height:CGFloat(size)).fill()
let base = NSBezierPath(roundedRect: NSRect(x:48,y:48,width:928,height:928), xRadius:210,yRadius:210)
NSColor(calibratedRed:0.15,green:0.25,blue:0.21,alpha:1).setFill(); base.fill()
let pageColor = NSColor(calibratedRed:0.94,green:0.93,blue:0.86,alpha:1)
let left = NSBezierPath(); left.move(to:NSPoint(x:200,y:312)); left.line(to:NSPoint(x:490,y:262)); left.line(to:NSPoint(x:490,y:722)); left.curve(to:NSPoint(x:200,y:772),controlPoint1:NSPoint(x:390,y:775),controlPoint2:NSPoint(x:290,y:790)); left.close(); pageColor.setFill(); left.fill()
let right = NSBezierPath(); right.move(to:NSPoint(x:534,y:262));right.line(to:NSPoint(x:824,y:312));right.line(to:NSPoint(x:824,y:772));right.curve(to:NSPoint(x:534,y:722),controlPoint1:NSPoint(x:735,y:790),controlPoint2:NSPoint(x:635,y:775));right.close();right.fill()
NSColor(calibratedRed:0.69,green:0.36,blue:0.25,alpha:1).setFill()
let bookmark=NSBezierPath();bookmark.move(to:NSPoint(x:695,y:780));bookmark.line(to:NSPoint(x:755,y:780));bookmark.line(to:NSPoint(x:755,y:580));bookmark.line(to:NSPoint(x:725,y:610));bookmark.line(to:NSPoint(x:695,y:580));bookmark.close();bookmark.fill()
let attrs: [NSAttributedString.Key:Any] = [.font:NSFont(name:"Baskerville-SemiBold",size:310) ?? NSFont.boldSystemFont(ofSize:310),.foregroundColor:NSColor(calibratedRed:0.15,green:0.25,blue:0.21,alpha:1)]
("K" as NSString).draw(at:NSPoint(x:241,y:343),withAttributes:attrs)
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:destination))
