// Focused check of Shared/MYBImageClean.h on macOS (ImageIO): location is removed and verified, redaction is burned into the pixels and verified.
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#import "../Shared/MYBImageClean.h"
static int fails=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL %s\n",m);fails++;}}while(0)
static CGImageRef Make(size_t w,size_t h){
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGContextRef ctx=CGBitmapContextCreate(NULL,w,h,8,0,space,(CGBitmapInfo)kCGImageAlphaNoneSkipLast);CGColorSpaceRelease(space);
 for(size_t y=0;y<h;y+=8)for(size_t x=0;x<w;x+=8){CGContextSetRGBFillColor(ctx,(CGFloat)(x%255)/255,(CGFloat)(y%255)/255,0.8,1);CGContextFillRect(ctx,CGRectMake(x,y,8,8));}
 CGImageRef image=CGBitmapContextCreateImage(ctx);CGContextRelease(ctx);return image;
}
int main(void){@autoreleasepool{
 NSString *dir=NSTemporaryDirectory();NSURL *original=[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"mybloxx-geo.jpg"]],*clean=[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"mybloxx-geo-clean.jpg"]];
 CGImageRef image=Make(160,120);
 CGImageDestinationRef dest=CGImageDestinationCreateWithURL((__bridge CFURLRef)original,CFSTR("public.jpeg"),1,NULL);
 NSDictionary *gps=@{(__bridge id)kCGImagePropertyGPSLatitude:@40.4168,(__bridge id)kCGImagePropertyGPSLatitudeRef:@"N",(__bridge id)kCGImagePropertyGPSLongitude:@3.7038,(__bridge id)kCGImagePropertyGPSLongitudeRef:@"W"};
 CGImageDestinationAddImage(dest,image,(__bridge CFDictionaryRef)@{(__bridge id)kCGImagePropertyGPSDictionary:gps,(__bridge id)kCGImagePropertyExifDictionary:@{(__bridge id)kCGImagePropertyExifUserComment:@"keep"}});
 CHECK(CGImageDestinationFinalize(dest),"test photo written");CFRelease(dest);
 CHECK(MYBImageHasLocation(original),"test photo carries location");
 NSString *why=MYBStripLocation(original,clean);
 CHECK(why==nil,"strip succeeds on a jpeg");
 CHECK(!MYBImageHasLocation(clean),"the copy has no location");
 CHECK(MYBImageHasLocation(original),"the original still has its location (never modified)");
 NSURL *bad=[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"mybloxx-notphoto.txt"]];[@"hello" writeToURL:bad atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 CHECK(MYBStripLocation(bad,[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"mybloxx-bad-out.jpg"]])!=nil,"a non-photo is refused with a reason");
 // redaction
 NSArray *rects=@[MYBRectBox(CGRectMake(10,10,60,20)),MYBRectBox(CGRectMake(100,80,50,30))];
 NSData *png=MYBRedactRender(image,rects);CHECK(png.length>0,"redaction renders a png");
 CHECK(MYBRedactVerify(png,160,120,rects),"covered pixels are solid black in the saved file");
 CHECK(!MYBRedactVerify(png,160,120,@[MYBRectBox(CGRectMake(70,40,20,20))]),"an uncovered area is not reported as covered");
 CHECK(MYBRectUnbox(MYBRedactNormalize(@[MYBRectBox(CGRectMake(150,110,50,50))],160,120).firstObject).size.width<=12,"rectangles are clamped to the image");
 CHECK(!MYBRedactVerify(png,160,120,@[MYBRectBox(CGRectMake(10,90,60,20))]),"the vertically mirrored area (bottom-left) is not reported as covered, so the check cannot pass on the wrong rows");
 CGImageRelease(image);
 if(fails){fprintf(stderr,"%d failed\n",fails);return 1;}puts("image-clean-native ok");return 0;}}
