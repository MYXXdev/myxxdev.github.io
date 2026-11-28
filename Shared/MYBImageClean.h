#pragma once
// MYbloXX® Clean Share image tools (iOS only, local, user-invoked). Originals are never modified: every result is a new file that is read back and checked
// before it is offered. Nothing about the image, its metadata or any recognized text is logged.
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

// Rectangles travel as NSValue so this file builds with or without UIKit (the macOS CI test uses it too).
static inline NSValue *MYBRectBox(CGRect r){return [NSValue valueWithBytes:&r objCType:@encode(CGRect)];}
static inline CGRect MYBRectUnbox(NSValue *v){CGRect r=CGRectZero;[v getValue:&r];return r;}
// YES when the file carries location in its EXIF/GPS properties or in its XMP.
static inline BOOL MYBImageHasLocation(NSURL *url){
 CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)url,NULL);if(!source)return NO;
 BOOL found=NO;
 NSDictionary *props=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
 if([props objectForKey:(__bridge id)kCGImagePropertyGPSDictionary])found=YES;
 if(!found){
  CGImageMetadataRef meta=CGImageSourceCopyMetadataAtIndex(source,0,NULL);
  if(meta){
   __block BOOL hit=NO;
   CGImageMetadataEnumerateTagsUsingBlock(meta,NULL,NULL,^bool(CFStringRef path,CGImageMetadataTagRef tag){
    (void)tag;if([(__bridge NSString *)path rangeOfString:@"GPS" options:NSCaseInsensitiveSearch].location!=NSNotFound){hit=YES;return false;}return true;});
   found=hit;CFRelease(meta);
  }
 }
 CFRelease(source);return found;
}
// Writes a new copy of a still photo without location. Returns nil on success, or a plain sentence saying why nothing was exported.
static inline NSString *MYBStripLocation(NSURL *input,NSURL *output){
 CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)input,NULL);
 if(!source)return @"This file could not be read as a photo. Nothing was exported.";
 NSString *type=(__bridge NSString *)CGImageSourceGetType(source);
 if(!type||![@[@"public.jpeg",@"public.heic",@"public.png",@"public.tiff"] containsObject:type]){CFRelease(source);return @"This photo format is not supported, so nothing was exported.";}
 if(CGImageSourceGetCount(source)!=1){CFRelease(source);return @"This file holds more than one image (for example a burst or animation). Nothing was exported.";}
 [NSFileManager.defaultManager removeItemAtURL:output error:NULL];
 CGImageDestinationRef dest=CGImageDestinationCreateWithURL((__bridge CFURLRef)output,(__bridge CFStringRef)type,1,NULL);
 if(!dest){CFRelease(source);return @"A copy could not be started. Nothing was exported.";}
 NSDictionary *options=@{(__bridge id)kCGImageMetadataShouldExcludeGPS:@YES};
 CFErrorRef error=NULL;BOOL done=CGImageDestinationCopyImageSource(dest,source,(__bridge CFDictionaryRef)options,&error);
 if(error)CFRelease(error);
 CFRelease(dest);
 NSString *failure=nil;
 if(!done)failure=@"The copy could not be written. Nothing was exported.";
 else if(MYBImageHasLocation(output))failure=@"Location could not be fully removed from this photo, so nothing was exported.";
 else{
  CGImageSourceRef check=CGImageSourceCreateWithURL((__bridge CFURLRef)output,NULL);
  CGImageRef image=check?CGImageSourceCreateImageAtIndex(check,0,NULL):NULL;
  CGImageRef original=CGImageSourceCreateImageAtIndex(source,0,NULL);
  if(!image||!original||CGImageGetWidth(image)!=CGImageGetWidth(original)||CGImageGetHeight(image)!=CGImageGetHeight(original))failure=@"The copy could not be checked, so nothing was exported.";
  if(image)CGImageRelease(image);if(original)CGImageRelease(original);if(check)CFRelease(check);
 }
 CFRelease(source);
 if(failure)[NSFileManager.defaultManager removeItemAtURL:output error:NULL];
 return failure;
}
// Redaction burns solid black into the pixels of a new flat PNG (no layers, no metadata). rects are in image PIXELS, origin top-left.
static inline NSArray<NSValue *> *MYBRedactNormalize(NSArray<NSValue *> *rects,size_t width,size_t height){
 NSMutableArray *out=[NSMutableArray array];
 for(NSValue *value in rects){
  CGRect r=CGRectInset(MYBRectUnbox(value),-2,-2);r=CGRectIntersection(CGRectIntegral(r),CGRectMake(0,0,(CGFloat)width,(CGFloat)height));
  if(!CGRectIsNull(r)&&r.size.width>=1&&r.size.height>=1)[out addObject:MYBRectBox(r)];
 }
 return out;
}
static inline NSData *MYBRedactRender(CGImageRef image,NSArray<NSValue *> *rects){
 size_t w=CGImageGetWidth(image),h=CGImageGetHeight(image);if(!w||!h)return nil;
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
 CGContextRef ctx=CGBitmapContextCreate(NULL,w,h,8,0,space,(CGBitmapInfo)kCGImageAlphaNoneSkipLast);CGColorSpaceRelease(space);if(!ctx)return nil;
 CGContextDrawImage(ctx,CGRectMake(0,0,(CGFloat)w,(CGFloat)h),image);
 CGContextSetRGBFillColor(ctx,0,0,0,1);
 for(NSValue *value in MYBRedactNormalize(rects,w,h)){CGRect r=MYBRectUnbox(value);CGContextFillRect(ctx,CGRectMake(r.origin.x,(CGFloat)h-r.origin.y-r.size.height,r.size.width,r.size.height));}   // top-left to bottom-left origin
 CGImageRef burned=CGBitmapContextCreateImage(ctx);CGContextRelease(ctx);if(!burned)return nil;
 NSMutableData *data=[NSMutableData data];
 CGImageDestinationRef dest=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,CFSTR("public.png"),1,NULL);
 if(!dest){CGImageRelease(burned);return nil;}
 CGImageDestinationAddImage(dest,burned,NULL);BOOL ok=CGImageDestinationFinalize(dest);CFRelease(dest);CGImageRelease(burned);
 return ok?data:nil;
}
// Reads the saved PNG back and checks that every sampled pixel inside every covered area is solid black, so removing an overlay cannot reveal anything.
static inline BOOL MYBRedactVerify(NSData *png,size_t width,size_t height,NSArray<NSValue *> *rects){
 CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)png,NULL);if(!source)return NO;
 CGImageRef image=CGImageSourceCreateImageAtIndex(source,0,NULL);CFRelease(source);if(!image)return NO;
 if(CGImageGetWidth(image)!=width||CGImageGetHeight(image)!=height){CGImageRelease(image);return NO;}
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
 CGContextRef ctx=CGBitmapContextCreate(NULL,width,height,8,width*4,space,(CGBitmapInfo)kCGImageAlphaPremultipliedLast);CGColorSpaceRelease(space);
 if(!ctx){CGImageRelease(image);return NO;}
 CGContextDrawImage(ctx,CGRectMake(0,0,(CGFloat)width,(CGFloat)height),image);CGImageRelease(image);
 const unsigned char *pixels=CGBitmapContextGetData(ctx);size_t stride=CGBitmapContextGetBytesPerRow(ctx);BOOL ok=pixels!=NULL;
 for(NSValue *value in MYBRedactNormalize(rects,width,height)){
  CGRect r=MYBRectUnbox(value);
  size_t x0=(size_t)r.origin.x,x1=(size_t)(r.origin.x+r.size.width),y0=(size_t)r.origin.y,y1=(size_t)(r.origin.y+r.size.height);
  size_t stepX=MAX((size_t)1,(x1-x0)/48),stepY=MAX((size_t)1,(y1-y0)/48);
  for(size_t y=y0;ok&&y<y1;y+=stepY)for(size_t x=x0;x<x1;x+=stepX){
   const unsigned char *px=pixels+y*stride+x*4;   // memory row 0 is the top row of the image, the same top-left origin as the rectangles
   if(px[0]>2||px[1]>2||px[2]>2||px[3]!=255){ok=NO;break;}
  }
  if(!ok)break;
 }
 CGContextRelease(ctx);return ok;
}
