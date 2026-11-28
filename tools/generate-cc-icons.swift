import AppKit
import Foundation
let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
let svg=try String(contentsOf:root.appendingPathComponent("Brand/MYBRibbon.svg"),encoding:.utf8)
let match=try NSRegularExpression(pattern:"\\bd=\"([^\"]+)\"").firstMatch(in:svg,range:NSRange(svg.startIndex...,in:svg))!
let data=(svg as NSString).substring(with:match.range(at:1))
let rx=try NSRegularExpression(pattern:"[MCQLZ]|-?[0-9]+(?:\\.[0-9]+)?")
let tokens=rx.matches(in:data,range:NSRange(data.startIndex...,in:data)).map{(data as NSString).substring(with:$0.range)}
var i=0
func number()->CGFloat{defer{i+=1};return CGFloat(Double(tokens[i])!)}
func point()->CGPoint{let x=number(),y=number();return CGPoint(x:x,y:y)}
let path=CGMutablePath()
while i<tokens.count{let command=tokens[i];i+=1;switch command{
case "M":path.move(to:point())
case "L":path.addLine(to:point())
case "Q":let c=point(),p=point();path.addQuadCurve(to:p,control:c)
case "C":let a=point(),b=point(),p=point();path.addCurve(to:p,control1:a,control2:b)
case "Z":path.closeSubpath()
default:fatalError("Unsupported canonical ribbon path command: \(command)")}}
let bounds=path.boundingBoxOfPath
for scale in 1...3{
 let size=36*scale,margin=CGFloat(scale),factor=(CGFloat(size)-2*margin)/max(bounds.width,bounds.height)
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();let graphics=NSGraphicsContext(bitmapImageRep:bitmap);NSGraphicsContext.current=graphics
 let context=graphics!.cgContext;context.setShouldAntialias(true);context.translateBy(x:(CGFloat(size)-bounds.width*factor)/2-bounds.minX*factor,y:(CGFloat(size)-bounds.height*factor)/2+bounds.maxY*factor);context.scaleBy(x:factor,y:-factor);context.addPath(path);context.setFillColor(NSColor.white.cgColor);context.fillPath();NSGraphicsContext.restoreGraphicsState()
 let suffix=scale==1 ? "" : "@\(scale)x";try bitmap.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("CCPreview/Resources/icon\(suffix).png"))
}
print("Generated 36pt CC glyphs, preserving the canonical ribbon proportions with a 34pt visible width.")

