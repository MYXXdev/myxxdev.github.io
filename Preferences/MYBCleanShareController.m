#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBTips.h"
#import <PhotosUI/PhotosUI.h>
#import <Vision/Vision.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../Shared/MYBCleanLink.h"
#import "../Shared/MYBImageClean.h"
// Clean Share: three actions the person starts. Each shows a preview, keeps the original, and hands the result to the iOS share sheet (which also offers
// Copy and Save). Processing is on this iPhone only. Links, image data and recognized text are never logged or stored.

// ---- shared bits ------------------------------------------------------------------------------------------------------------------------
static UILabel *CSLabel(NSString *text,UIFontTextStyle style,UIColor *color){
 UILabel *label=[UILabel new];label.numberOfLines=0;label.text=text;label.font=[UIFont preferredFontForTextStyle:style];label.textColor=color?:UIColor.labelColor;label.adjustsFontForContentSizeCategory=YES;return label;
}
static UIButton *CSButton(NSString *title,BOOL primary,id target,SEL action){
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
 UIButtonConfiguration *config=primary?[UIButtonConfiguration filledButtonConfiguration]:[UIButtonConfiguration tintedButtonConfiguration];
 config.title=title;config.baseBackgroundColor=MYBAccent();config.baseForegroundColor=primary?UIColor.whiteColor:MYBAccent();config.cornerStyle=UIButtonConfigurationCornerStyleLarge;
 config.contentInsets=NSDirectionalEdgeInsetsMake(14,16,14,16);button.configuration=config;[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];return button;
}
@interface MYBCSPage:UIViewController
@property(nonatomic,strong) UIStackView *stack;
@end
@implementation MYBCSPage
- (void)viewDidLoad{
 [super viewDidLoad];self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;[self.view addSubview:scroll];
 self.stack=[UIStackView new];self.stack.axis=UILayoutConstraintAxisVertical;self.stack.spacing=14;self.stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:self.stack];
 [NSLayoutConstraint activateConstraints:@[
  [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
  [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
  [self.stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[self.stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
  [self.stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:20],[self.stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-20]]];
}
- (void)share:(NSArray *)items from:(UIView *)source{
 UIActivityViewController *sheet=[[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
 sheet.popoverPresentationController.sourceView=source;sheet.popoverPresentationController.sourceRect=source.bounds;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)say:(NSString *)title detail:(NSString *)detail{
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:detail preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
- (PHPickerViewController *)pickerForImages{
 PHPickerConfiguration *config=[[PHPickerConfiguration alloc] init];config.filter=[PHPickerFilter imagesFilter];config.selectionLimit=1;config.preferredAssetRepresentationMode=PHPickerConfigurationAssetRepresentationModeCurrent;
 PHPickerViewController *picker=[[PHPickerViewController alloc] initWithConfiguration:config];return picker;
}
@end

// ---- 1. Clean Link ----------------------------------------------------------------------------------------------------------------------
@interface MYBCleanLinkController:MYBCSPage<UITextViewDelegate>
@property(nonatomic,strong) UITextView *input;
@property(nonatomic,strong) UILabel *hint,*result,*changes;
@property(nonatomic,strong) UIButton *shareButton,*cleanCopyButton,*originalCopyButton;
@property(nonatomic,copy) NSDictionary *current;
@end
@implementation MYBCleanLinkController
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"Clean Link";
 [self.stack addArrangedSubview:CSLabel(@"Paste a link. MYbloXX® removes well-understood tracking parameters and shows you exactly what changed. Nothing is opened or sent anywhere.",UIFontTextStyleSubheadline,UIColor.secondaryLabelColor)];
 self.input=[UITextView new];self.input.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];self.input.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;self.input.layer.cornerRadius=12;
 self.input.textContainerInset=UIEdgeInsetsMake(12,10,12,10);self.input.autocorrectionType=UITextAutocorrectionTypeNo;self.input.autocapitalizationType=UITextAutocapitalizationTypeNone;self.input.keyboardType=UIKeyboardTypeURL;self.input.delegate=self;
 [self.input.heightAnchor constraintGreaterThanOrEqualToConstant:96].active=YES;[self.stack addArrangedSubview:self.input];
 [self.stack addArrangedSubview:CSButton(@"Paste",NO,self,@selector(paste))];
 self.changes=CSLabel(@"",UIFontTextStyleFootnote,UIColor.secondaryLabelColor);[self.stack addArrangedSubview:self.changes];
 self.result=CSLabel(@"",UIFontTextStyleBody,nil);self.result.userInteractionEnabled=YES;[self.stack addArrangedSubview:self.result];
 self.shareButton=CSButton(@"Share Clean Link",YES,self,@selector(shareClean));self.cleanCopyButton=CSButton(@"Copy Clean Link",NO,self,@selector(doCopyClean));self.originalCopyButton=CSButton(@"Copy Original Instead",NO,self,@selector(doCopyOriginal));
 for(UIView *v in @[self.shareButton,self.cleanCopyButton,self.originalCopyButton])[self.stack addArrangedSubview:v];
 [self refresh];
}
- (void)paste{NSString *text=UIPasteboard.generalPasteboard.string;if(text.length){self.input.text=text;[self refresh];}else [self say:@"Nothing to Paste" detail:@"Copy a link first, then tap Paste."];}
- (void)textViewDidChange:(UITextView *)textView{(void)textView;[self refresh];}
- (void)refresh{
 NSString *text=self.input.text?:@"";BOOL empty=![text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length;
 self.current=empty?nil:MYBCleanLink(text);
 BOOL changed=[self.current[@"changed"] boolValue];
 if(empty)self.changes.text=@"";
 else if(changed)self.changes.text=[NSString stringWithFormat:@"Removed: %@. Everything else is unchanged.",[self.current[@"removed"] componentsJoinedByString:@", "]];
 else self.changes.text=self.current[@"note"];
 self.result.text=empty?@"":(changed?self.current[@"clean"]:@"Nothing to clean. Your original link is unchanged.");
 self.shareButton.hidden=self.cleanCopyButton.hidden=self.originalCopyButton.hidden=!changed;
}
- (void)shareClean{[self share:@[self.current[@"clean"]] from:self.shareButton];}
- (void)doCopyClean{UIPasteboard.generalPasteboard.string=self.current[@"clean"];[self say:@"Copied" detail:@"The clean link is on your clipboard."];}
- (void)doCopyOriginal{UIPasteboard.generalPasteboard.string=[self.input.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];[self say:@"Copied" detail:@"The original link is on your clipboard."];}
@end

// ---- 2. Share Without Location ----------------------------------------------------------------------------------------------------------
@interface MYBPhotoLocationController:MYBCSPage<PHPickerViewControllerDelegate>
@property(nonatomic,strong) UIImageView *preview;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIButton *shareButton;
@property(nonatomic,strong) NSURL *result;
@end
@implementation MYBPhotoLocationController
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"Share Without Location";
 [self.stack addArrangedSubview:CSLabel(@"Choose a photo. MYbloXX® makes a new copy with its location removed and checks the copy before you can share it. Your original in Photos is not changed.",UIFontTextStyleSubheadline,UIColor.secondaryLabelColor)];
 [self.stack addArrangedSubview:CSButton(@"Choose Photo",YES,self,@selector(choose))];
 self.preview=[UIImageView new];self.preview.contentMode=UIViewContentModeScaleAspectFit;self.preview.layer.cornerRadius=12;self.preview.clipsToBounds=YES;[self.preview.heightAnchor constraintEqualToConstant:260].active=YES;self.preview.hidden=YES;[self.stack addArrangedSubview:self.preview];
 self.status=CSLabel(@"",UIFontTextStyleFootnote,UIColor.secondaryLabelColor);[self.stack addArrangedSubview:self.status];
 self.shareButton=CSButton(@"Share Copy",YES,self,@selector(shareCopy));self.shareButton.hidden=YES;[self.stack addArrangedSubview:self.shareButton];
 [self.stack addArrangedSubview:CSLabel(@"Photos, Live Photos' still frames and screenshots in JPEG, HEIC, PNG or TIFF are supported. Videos are not offered, and a Live Photo's motion is not kept.",UIFontTextStyleCaption1,UIColor.tertiaryLabelColor)];
}
- (void)choose{PHPickerViewController *picker=[self pickerForImages];picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results{
 [picker dismissViewControllerAnimated:YES completion:nil];PHPickerResult *pick=results.firstObject;if(!pick)return;
 NSItemProvider *provider=pick.itemProvider;
 BOOL live=[provider.registeredTypeIdentifiers containsObject:@"com.apple.live-photo-bundle"]||[provider hasItemConformingToTypeIdentifier:@"com.apple.live-photo"];
 __weak typeof(self) weak=self;
 void (^go)(void)=^{[weak exportProvider:provider];};
 if(live){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"This is a Live Photo" message:@"Only its still photo can be exported without location. The motion and sound are not kept." preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Export Still Photo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;go();}]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:alert animated:YES completion:nil];
 }else go();
}
- (void)exportProvider:(NSItemProvider *)provider{
 NSString *type=nil;for(NSString *candidate in provider.registeredTypeIdentifiers){UTType *t=[UTType typeWithIdentifier:candidate];if(t&&[t conformsToType:UTTypeImage]&&![candidate isEqual:@"com.apple.live-photo-bundle"]){type=candidate;break;}}
 if(!type){[self say:@"Couldn’t Read This Photo" detail:@"Nothing was exported."];return;}
 self.status.text=@"Working...";self.shareButton.hidden=YES;
 __weak typeof(self) weak=self;
 [provider loadFileRepresentationForTypeIdentifier:type completionHandler:^(NSURL *url,NSError *error){
  if(!url||error){dispatch_async(dispatch_get_main_queue(),^{weak.status.text=@"";[weak say:@"Couldn’t Read This Photo" detail:@"Nothing was exported."];});return;}
  // The provider's file is only valid inside this handler: work from a private copy, never the original.
  NSString *ext=url.pathExtension.length?url.pathExtension:@"jpg";
  NSURL *work=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"mybloxx-src-%@.%@",NSUUID.UUID.UUIDString,ext]]];
  NSURL *out=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Photo-no-location-%@.%@",[NSUUID.UUID.UUIDString substringToIndex:6],ext]]];
  NSError *copyError=nil;[NSFileManager.defaultManager copyItemAtURL:url toURL:work error:&copyError];
  BOOL had=copyError?NO:MYBImageHasLocation(work);NSString *why=copyError?@"The photo could not be copied. Nothing was exported.":MYBStripLocation(work,out);
  [NSFileManager.defaultManager removeItemAtURL:work error:NULL];
  dispatch_async(dispatch_get_main_queue(),^{
   typeof(self) me=weak;if(!me)return;
   if(why){me.status.text=@"";me.preview.hidden=YES;[me say:@"Not Exported" detail:why];return;}
   me.result=out;me.preview.image=[UIImage imageWithContentsOfFile:out.path];me.preview.hidden=NO;me.shareButton.hidden=NO;
   me.status.text=had?@"Checked: the original had a location and this copy has none.":@"Checked: this photo had no location, and the copy has none.";
  });
 }];
}
- (void)shareCopy{if(self.result)[self share:@[self.result] from:self.shareButton];}
@end

// ---- 3. Redact Screenshot ---------------------------------------------------------------------------------------------------------------
@interface MYBRedactCanvas:UIView
@property(nonatomic,strong) UIImage *image;
@property(nonatomic,strong) NSMutableArray<NSValue *> *covers,*suggestions;   // image pixels, top-left origin
@property(nonatomic,assign) CGRect draft;
@end
@implementation MYBRedactCanvas{CGPoint _start;}
- (instancetype)initWithFrame:(CGRect)frame{
 self=[super initWithFrame:frame];self.covers=[NSMutableArray array];self.suggestions=[NSMutableArray array];self.backgroundColor=UIColor.secondarySystemBackgroundColor;
 UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];[self addGestureRecognizer:pan];
 [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)]];return self;
}
- (CGRect)fit{
 if(!self.image)return CGRectZero;CGSize s=self.image.size;CGFloat k=MIN(self.bounds.size.width/s.width,self.bounds.size.height/s.height);
 CGSize d=CGSizeMake(s.width*k,s.height*k);return CGRectMake((self.bounds.size.width-d.width)/2,(self.bounds.size.height-d.height)/2,d.width,d.height);
}
- (CGFloat)pixelsPerPoint{CGRect fit=[self fit];return fit.size.width>0?CGImageGetWidth(self.image.CGImage)/fit.size.width:1;}
- (CGRect)toView:(CGRect)pixels{CGRect fit=[self fit];CGFloat k=1/[self pixelsPerPoint];return CGRectMake(fit.origin.x+pixels.origin.x*k,fit.origin.y+pixels.origin.y*k,pixels.size.width*k,pixels.size.height*k);}
- (CGRect)toPixels:(CGRect)view{CGRect fit=[self fit];CGFloat k=[self pixelsPerPoint];return CGRectMake((view.origin.x-fit.origin.x)*k,(view.origin.y-fit.origin.y)*k,view.size.width*k,view.size.height*k);}
- (void)pan:(UIPanGestureRecognizer *)pan{
 CGRect fit=[self fit];CGPoint p=[pan locationInView:self];p.x=MIN(MAX(p.x,CGRectGetMinX(fit)),CGRectGetMaxX(fit));p.y=MIN(MAX(p.y,CGRectGetMinY(fit)),CGRectGetMaxY(fit));
 if(pan.state==UIGestureRecognizerStateBegan)_start=p;
 CGRect r=CGRectMake(MIN(_start.x,p.x),MIN(_start.y,p.y),fabs(p.x-_start.x),fabs(p.y-_start.y));
 if(pan.state==UIGestureRecognizerStateEnded){self.draft=CGRectZero;if(r.size.width>6&&r.size.height>6)[self.covers addObject:MYBRectBox([self toPixels:r])];}
 else self.draft=r;
 [self setNeedsDisplay];
}
- (void)tap:(UITapGestureRecognizer *)tap{   // tapping a suggestion confirms it
 CGPoint p=[tap locationInView:self];
 for(NSValue *s in [self.suggestions copy])if(CGRectContainsPoint(CGRectInset([self toView:MYBRectUnbox(s)],-6,-6),p)){[self.covers addObject:s];[self.suggestions removeObject:s];[self setNeedsDisplay];return;}
}
- (void)drawRect:(CGRect)rect{
 (void)rect;if(!self.image)return;[self.image drawInRect:[self fit]];CGContextRef ctx=UIGraphicsGetCurrentContext();
 for(NSValue *s in self.suggestions){CGContextSetStrokeColorWithColor(ctx,UIColor.systemOrangeColor.CGColor);CGContextSetLineWidth(ctx,2);CGFloat dash[]={5,3};CGContextSetLineDash(ctx,0,dash,2);CGContextStrokeRect(ctx,[self toView:MYBRectUnbox(s)]);}
 CGContextSetLineDash(ctx,0,NULL,0);CGContextSetFillColorWithColor(ctx,UIColor.blackColor.CGColor);
 for(NSValue *c in self.covers)CGContextFillRect(ctx,[self toView:MYBRectUnbox(c)]);
 if(!CGRectIsEmpty(self.draft)){CGContextSetFillColorWithColor(ctx,[UIColor.blackColor colorWithAlphaComponent:0.6].CGColor);CGContextFillRect(ctx,self.draft);}
}
@end

@interface MYBRedactPreviewController:MYBCSPage @property(nonatomic,strong) NSData *png;@property(nonatomic,copy) NSString *note;@property(nonatomic,strong) NSURL *file; @end
@implementation MYBRedactPreviewController
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"Redacted Preview";
 UIImageView *image=[[UIImageView alloc] initWithImage:[UIImage imageWithData:self.png]];image.contentMode=UIViewContentModeScaleAspectFit;[image.heightAnchor constraintEqualToConstant:380].active=YES;[self.stack addArrangedSubview:image];
 [self.stack addArrangedSubview:CSLabel(self.note,UIFontTextStyleFootnote,UIColor.secondaryLabelColor)];
 [self.stack addArrangedSubview:CSButton(@"Share or Save",YES,self,@selector(shareIt:))];
}
- (void)shareIt:(UIButton *)sender{
 NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Redacted-%@.png",[NSUUID.UUID.UUIDString substringToIndex:6]]]];
 if(![self.png writeToURL:url options:NSDataWritingAtomic error:NULL]){[self say:@"Couldn’t Save" detail:@"Nothing was exported."];return;}
 [self share:@[url] from:sender];
}
@end

@interface MYBRedactController:MYBCSPage<PHPickerViewControllerDelegate>
@property(nonatomic,strong) MYBRedactCanvas *canvas;
@property(nonatomic,strong) UIStackView *tools;
@end
@implementation MYBRedactController
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"Redact Screenshot";
 [self.stack addArrangedSubview:CSLabel(@"Choose a screenshot, then drag over anything to cover. Suggestions are only outlines: tap one to cover it. The covered areas are burned into a new image, and your original is not changed.",UIFontTextStyleSubheadline,UIColor.secondaryLabelColor)];
 [self.stack addArrangedSubview:CSButton(@"Choose Screenshot",YES,self,@selector(choose))];
 self.canvas=[[MYBRedactCanvas alloc] initWithFrame:CGRectZero];self.canvas.layer.cornerRadius=12;self.canvas.clipsToBounds=YES;self.canvas.hidden=YES;[self.canvas.heightAnchor constraintEqualToConstant:420].active=YES;[self.stack addArrangedSubview:self.canvas];
 self.tools=[UIStackView new];self.tools.axis=UILayoutConstraintAxisVertical;self.tools.spacing=10;self.tools.hidden=YES;
 for(NSArray *t in @[@[@"Suggest Areas",@"suggest"],@[@"Undo Last",@"undo"],@[@"Preview Result",@"preview"]])[self.tools addArrangedSubview:CSButton(t[0],[t[1] isEqual:@"preview"],self,NSSelectorFromString(t[1]))];
 [self.stack addArrangedSubview:self.tools];
}
- (void)choose{PHPickerViewController *picker=[self pickerForImages];picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results{
 [picker dismissViewControllerAnimated:YES completion:nil];PHPickerResult *pick=results.firstObject;if(!pick)return;
 __weak typeof(self) weak=self;
 [pick.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(id object,NSError *error){
  dispatch_async(dispatch_get_main_queue(),^{
   typeof(self) me=weak;if(!me)return;UIImage *image=[object isKindOfClass:UIImage.class]?object:nil;
   if(!image||error){[me say:@"Couldn’t Read This Image" detail:@"Nothing was changed."];return;}
   // Flatten orientation so what is drawn on screen and what is exported are the same pixels.
   UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];format.scale=1;format.opaque=YES;
   UIImage *flat=[[[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format] imageWithActions:^(UIGraphicsImageRendererContext *c){(void)c;[image drawAtPoint:CGPointZero];}];
   me.canvas.image=flat;[me.canvas.covers removeAllObjects];[me.canvas.suggestions removeAllObjects];me.canvas.hidden=NO;me.tools.hidden=NO;[me.canvas setNeedsDisplay];
  });
 }];
}
- (void)undo{[self.canvas.covers.lastObject?:nil description];if(self.canvas.covers.count)[self.canvas.covers removeLastObject];[self.canvas setNeedsDisplay];}
// Optional on-device suggestions: text that looks like an email, phone number, link or long number. Only an outline is drawn; the person decides.
- (void)suggest{
 CGImageRef cg=self.canvas.image.CGImage;if(!cg)return;
 size_t w=CGImageGetWidth(cg),h=CGImageGetHeight(cg);__weak typeof(self) weak=self;
 VNRecognizeTextRequest *request=[[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *req,NSError *error){
  NSMutableArray *found=[NSMutableArray array];
  if(!error){
   NSDataDetector *detector=[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink|NSTextCheckingTypePhoneNumber|NSTextCheckingTypeAddress error:NULL];
   for(VNRecognizedTextObservation *o in req.results){
    NSString *text=[[o topCandidates:1] firstObject].string;if(!text.length)continue;
    BOOL digits=NO;NSUInteger run=0;for(NSUInteger i=0;i<text.length;i++){if(isdigit([text characterAtIndex:i]))run++;else if(run<6)run=0;if(run>=6){digits=YES;break;}}
    if([detector numberOfMatchesInString:text options:0 range:NSMakeRange(0,text.length)]>0||[text containsString:@"@"]||digits){
     CGRect b=o.boundingBox;[found addObject:MYBRectBox(CGRectMake(b.origin.x*w,(1-b.origin.y-b.size.height)*h,b.size.width*w,b.size.height*h))];
    }
   }
  }
  dispatch_async(dispatch_get_main_queue(),^{
   typeof(self) me=weak;if(!me)return;[me.canvas.suggestions setArray:found];[me.canvas setNeedsDisplay];
   if(!found.count)[me say:@"No Suggestions" detail:@"Nothing that looks like an email, number or link was found. You can still drag to cover anything."];
  });
 }];
 request.recognitionLevel=VNRequestTextRecognitionLevelAccurate;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{VNImageRequestHandler *handler=[[VNImageRequestHandler alloc] initWithCGImage:cg options:@{}];[handler performRequests:@[request] error:NULL];});
}
- (void)preview{
 CGImageRef cg=self.canvas.image.CGImage;if(!cg)return;
 if(!self.canvas.covers.count){[self say:@"Nothing Covered Yet" detail:@"Drag over the areas you want to hide first."];return;}
 NSData *png=MYBRedactRender(cg,self.canvas.covers);
 if(!png||!MYBRedactVerify(png,CGImageGetWidth(cg),CGImageGetHeight(cg),self.canvas.covers)){[self say:@"Not Exported" detail:@"The covered areas could not be checked in the saved image, so nothing was exported."];return;}
 MYBRedactPreviewController *page=[MYBRedactPreviewController new];page.png=png;
 page.note=@"Checked: the covered areas are solid black in the saved image, so nothing underneath can be recovered by removing an overlay. Your original is unchanged.";
 [self.navigationController pushViewController:page animated:YES];
}
@end

// ---- the Clean Share page ---------------------------------------------------------------------------------------------------------------
@interface MYBCleanShareController:MYBMenuBase @end
@implementation MYBCleanShareController
- (NSString *)heroTitle{return @"Clean Share";}
- (NSString *)heroDetail{return @"Three tools you start yourself. Each shows a preview and leaves your original alone.";}
- (void)rebuildMenu{
 self.title=@"Clean Share";
 self.menuSections=@[@{@"title":@"TOOLS",@"rows":@[
  @{@"title":@"Clean Link",@"detail":@"Remove tracking from a link before you share it",@"icon":@"link",@"accent":@YES,@"tone":@(MYBToneBlue),@"page":@"MYBCleanLinkController",@"action":@"openPage"},
  @{@"title":@"Share Without Location",@"detail":@"Make a copy of a photo with its location removed",@"icon":@"location.slash.fill",@"accent":@YES,@"tone":@(MYBToneGreen),@"page":@"MYBPhotoLocationController",@"action":@"openPage"},
  @{@"title":@"Redact Screenshot",@"detail":@"Cover private details and save a new image",@"icon":@"rectangle.dashed.and.paperclip",@"accent":@YES,@"tone":@(MYBToneViolet),@"page":@"MYBRedactController",@"action":@"openPage"}],
  @"footer":@"Nothing here changes links you open, and nothing is shared until you choose Share. Links, images and recognized text are never logged."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
@end
