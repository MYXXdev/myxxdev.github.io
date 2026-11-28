#!/usr/bin/env python3
"""Regenerates Shared/MYBShieldMark.h: the MYbloXX shield alone, on a transparent background (no square, no dark plate).
Source: Brand/MYBMaster.png (the existing logo artwork). The purple shield is separated from the dark plate by brightness, with soft edges."""
import base64,io,pathlib
import numpy as np
from PIL import Image
root=pathlib.Path(__file__).resolve().parent.parent
im=Image.open(root/'Brand/MYBMaster.png').convert('RGBA')
bgc=Image.new('RGBA',im.size,(0,0,0,255));bgc.alpha_composite(im);a0=np.asarray(im.getchannel('A'),dtype=np.float32)/255
rgb=np.asarray(bgc.convert('RGB'),dtype=np.float32)
v=rgb.max(axis=2)
t=np.clip((v-72)/(120-72),0,1);alpha=t*t*(3-2*t)*(a0>0.9)            # smoothstep: plate -> 0, shield -> 1
keep=np.zeros_like(alpha);keep[70:450,70:450]=1;alpha=alpha*keep   # the shield sits in the middle; the plate's thin rim at the edge is dropped
plate=np.array([30,31,42],dtype=np.float32)
a3=np.maximum(alpha,1e-3)[...,None]
col=np.clip((rgb-plate*(1-a3))/a3,0,255)                              # take the plate colour back out of the soft edge
ys,xs=np.where(alpha>0.02);y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
side=int(max(y1-y0,x1-x0)*1.2);cy,cx=(y0+y1)//2,(x0+x1)//2
out=np.zeros((side,side,4),dtype=np.float32)
sy,sx=cy-side//2,cx-side//2
for y in range(side):
    yy=sy+y
    if yy<0 or yy>=alpha.shape[0]:continue
    xa,xb=max(sx,0),min(sx+side,alpha.shape[1])
    out[y,xa-sx:xb-sx,:3]=col[yy,xa:xb]*alpha[yy,xa:xb,None]/1.0       # premultiplied
    out[y,xa-sx:xb-sx,3]=alpha[yy,xa:xb]*255
pm=Image.fromarray(np.clip(out,0,255).astype(np.uint8),'RGBA').resize((360,360),Image.LANCZOS)   # resized premultiplied: no dark fringe
arr=np.asarray(pm,dtype=np.float32);al=np.maximum(arr[...,3:4],1)
un=np.clip(arr[...,:3]*255/al,0,255)
final=Image.fromarray(np.dstack([un,arr[...,3]]).astype(np.uint8),'RGBA')
buf=io.BytesIO();final.save('/tmp/shield-mark.png','PNG');final.save(buf,'PNG',optimize=True)
data=base64.b64encode(buf.getvalue()).decode()
(root/'Shared/MYBShieldMark.h').write_text('#pragma once\n// The MYbloXX shield on a transparent background (no square plate), 120 pt at 3x. Source: Brand/MYBMaster.png.\n// Embedded so the sheet needs no file access in the host app and no network. Regenerate with tools/generate-shield-mark.py.\n#import <UIKit/UIKit.h>\nstatic inline UIImage *MYBShieldMarkImage(void){\n static UIImage *image;static dispatch_once_t once;\n dispatch_once(&once,^{NSData *data=[[NSData alloc] initWithBase64EncodedString:@"%s" options:0];image=data?[UIImage imageWithData:data scale:3]:nil;});\n return image;\n}\n'%data)
print(final.size,len(data))
