#import <UIKit/UIKit.h>
#import <roothide.h>
#import <notify.h>
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <spawn.h>
#import <signal.h>
#import <sys/wait.h>
extern char **environ;
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../Shared/MYBSupervisionLayout.h"
#import "../../Shared/MYBSupervisionMessage.h"
#import "../../Shared/MYBMYbloXXProfile.h"
static char previousVisibility,originalText;
@interface PSUIFooterHyperlinkView : UIView @end
// Settings-only presentation hook. This never edits supervision or MDM state.
static BOOL hideSign;
static void reloadSign(void){hideSign=[[[NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.appearance.plist")] objectForKey:@"HideSupervisionSign"] boolValue];}
// ---- Branded message ----------------------------------------------------------------------------------------------------
// The message is rewritten only when MYbloXX's own spoofed supervision is on and nothing else describes this device as managed
// (Shared/MYBSupervisionMessage.h). Everything is read fresh from disk, cached for two seconds, so the text follows the real protection
// state. Not branded: the view is left exactly as iOS made it, and anything this tweak changed earlier is put back.
static NSString *brandCached;static NSDate *brandAt;
static NSString *brandedText(void){
 NSString *cached;
 if(brandAt&&[brandAt timeIntervalSinceNow]>-2.0)return brandCached;
 NSString *details=@"/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles/CloudConfigurationDetails.plist";
 NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:details]?:[NSDictionary dictionaryWithContentsOfFile:[@"/rootfs" stringByAppendingString:details]];
 NSDictionary *record=[NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/MYbloXX/Supervision.plist")];
 // Settings may not be allowed to read iOS's own file or MYbloXX's record on every device. The helper reads both as root and publishes the answer
 // in the status file the Settings pages already use, so the message falls back to that instead of silently leaving iOS's text.
 NSDictionary *status=[NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.supervision.plist")];
 if(![status isKindOfClass:NSDictionary.class])status=@{};
 if(![d isKindOfClass:NSDictionary.class]&&[status[@"supervised"] boolValue])d=[status[@"managed"] boolValue]?@{@"IsSupervised":@YES,@"MDMManaged":@YES}:@{@"IsSupervised":@YES};
 if(![record[@"owner"] isEqual:@"net.myxxdev.mybloxx"]&&[status[@"owned"] boolValue])record=@{@"owner":@"net.myxxdev.mybloxx"};
 cached=MYBSupervisionMessage(d,record,
  [NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/MYbloXX/State.plist")],
  // iOS itself says whether a MYbloXX® profile is installed (Settings may ask; it covers profiles installed by hand, too).
  [MYBInstalledMYbloXXProfile()[@"installed"] boolValue]?@{@"checks":@{@"net.myxxdev.mybloxx":@{@"state":@"installed"}}}:[NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profileinstall.plist")]);
 // One diagnostic line whenever the decision changes: key NAMES only, never values. It explains a message that did not change.
 static NSString *lastNote;
 NSString *note=[NSString stringWithFormat:@"detailsReadable=%d supervised=%d ownedRecord=%d statusSupervised=%d statusOwned=%d keys=[%@] shows=%@",[d isKindOfClass:NSDictionary.class],[d[@"IsSupervised"] boolValue],[record[@"owner"] isEqual:@"net.myxxdev.mybloxx"],[status[@"supervised"] boolValue],[status[@"owned"] boolValue],[[d.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","],cached?@"MYbloXX® text":@"iOS text"];
 if(![note isEqualToString:lastNote]){
  lastNote=note;
  int fd=open(jbroot(@"/var/mobile/Library/MYbloXX/ProfileDiagnostics.txt").fileSystemRepresentation,O_WRONLY|O_APPEND|O_CREAT,0666);
  if(fd>=0){fchmod(fd,0666);NSData *line=[[NSString stringWithFormat:@"%@ [supervision] %@\n",[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle],note] dataUsingEncoding:NSUTF8StringEncoding];if(line)write(fd,line.bytes,line.length);close(fd);}
 }
 brandCached=cached;brandAt=[NSDate date];return cached;
}
static NSString *displayText(NSString *message){return message;}
// The first text-bearing subview of the message view (a label or a text view). Only these two kinds are touched.
static UIView *textHolder(UIView *root,int depth){
 if([root isKindOfClass:UILabel.class]||[root isKindOfClass:UITextView.class])return root;
 if(depth>4)return nil;
 for(UIView *sub in root.subviews){UIView *found=textHolder(sub,depth+1);if(found)return found;}
 return nil;
}
static NSString *holderText(UIView *v){return [v isKindOfClass:UILabel.class]?((UILabel *)v).text:((UITextView *)v).text;}
// ---- The MYbloXX word: blue, and a tap opens MYbloXX's own settings ------------------------------------------------------------------
static char tapInstalled;
// One line per tap in ProfileDiagnostics.txt: what was hit and which route opened the page. Row titles only, never anything personal.
static void tapLog(NSString *note){
 int fd=open(jbroot(@"/var/mobile/Library/MYbloXX/ProfileDiagnostics.txt").fileSystemRepresentation,O_WRONLY|O_APPEND|O_CREAT,0666);
 if(fd>=0){fchmod(fd,0666);NSData *line=[[NSString stringWithFormat:@"%@ [supervision-tap] %@\n",[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle],note] dataUsingEncoding:NSUTF8StringEncoding];ssize_t n=write(fd,line.bytes,line.length);(void)n;close(fd);}
}
static NSAttributedString *brandedAttributed(NSString *text,UIFont *font,UIColor *gray,NSTextAlignment alignment,NSLineBreakMode breakMode){
 NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.alignment=alignment;style.lineBreakMode=breakMode; // the same alignment the view draws with, so the hit area matches the drawn word
 NSMutableAttributedString *a=[[NSMutableAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:gray,NSParagraphStyleAttributeName:style}];
 NSRange word=[text rangeOfString:@"MYbloXX®"];
 if(word.location!=NSNotFound)[a addAttribute:NSForegroundColorAttributeName value:UIColor.systemBlueColor range:word];
 return a;
}
static BOOL isMYbloXXName(NSString *name){return [name isKindOfClass:NSString.class]&&[name hasPrefix:@"MYbloXX"];}
// Opens the MYbloXX page. Route 1: select its own row in the list that shows the message. Route 2: push its settings controller through the
// list. Route 3: Settings' own address for it. Each route is logged.
static void openMYbloXXSettings(UIView *from){
 UITableView *table=MYBSupOwningTable(from);id list=table.delegate;
 SEL specSel=NSSelectorFromString(@"specifiers"),indexSel=NSSelectorFromString(@"indexPathForSpecifier:"),nameSel=NSSelectorFromString(@"name");
 NSMutableArray *names=[NSMutableArray array];
 if(table&&[list respondsToSelector:specSel]){
  NSArray *specs=((NSArray *(*)(id,SEL))objc_msgSend)(list,specSel);
  for(id spec in specs){
   NSString *name=[spec respondsToSelector:nameSel]?((NSString *(*)(id,SEL))objc_msgSend)(spec,nameSel):nil;
   if(isMYbloXXName(name))[names addObject:name];
   if(!isMYbloXXName(name)||![list respondsToSelector:indexSel])continue;
   NSIndexPath *ip=((NSIndexPath *(*)(id,SEL,id))objc_msgSend)(list,indexSel,spec);
   if(ip&&[table.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]){tapLog([NSString stringWithFormat:@"route=row-select list=%@ row=%@",NSStringFromClass([list class]),name]);[table.delegate tableView:table didSelectRowAtIndexPath:ip];return;}
  }
 }
 // The settings page is in the MYbloXXDiagnostics bundle; load it if Settings has not yet.
 Class page=NSClassFromString(@"MYBModernController");
 if(!page){NSBundle *bundle=[NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/MYbloXXDiagnostics.bundle")];[bundle load];page=NSClassFromString(@"MYBModernController");}
 SEL show=NSSelectorFromString(@"showController:");
 if(page&&[list respondsToSelector:show]){tapLog([NSString stringWithFormat:@"route=showController list=%@ rowsNamed=%lu",NSStringFromClass([list class]),(unsigned long)names.count]);((void(*)(id,SEL,id))objc_msgSend)(list,show,[[page alloc] init]);return;}
 tapLog([NSString stringWithFormat:@"route=url list=%@ page=%d rowsNamed=%lu",list?NSStringFromClass([list class]):@"none",page!=nil,(unsigned long)names.count]);
 [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"prefs:root=MYbloXX%C2%AE"] options:@{} completionHandler:nil];
}
@interface MYBSupTapTarget : NSObject
@property(nonatomic,weak) UIView *holder;@property(nonatomic,weak) UIView *link;
- (void)tapped:(UITapGestureRecognizer *)g;
@end
@implementation MYBSupTapTarget
- (void)tapped:(UITapGestureRecognizer *)g{
 UIView *holder=self.holder;if(!holder||g.state!=UIGestureRecognizerStateEnded)return;
 NSAttributedString *text=[holder isKindOfClass:UILabel.class]?((UILabel *)holder).attributedText:((UITextView *)holder).attributedText;
 NSRange word=[text.string rangeOfString:@"MYbloXX®"];
 if(word.location==NSNotFound){tapLog(@"tap ignored: no link in the text");return;}
 // Where each link is drawn, from the same text, alignment and width the view uses.
 UIEdgeInsets inset=UIEdgeInsetsZero;CGFloat padding=0;BOOL label=[holder isKindOfClass:UILabel.class];
 if(!label){UITextView *tv=(UITextView *)holder;inset=tv.textContainerInset;padding=tv.textContainer.lineFragmentPadding;}
 NSTextStorage *storage=[[NSTextStorage alloc] initWithAttributedString:text];NSLayoutManager *manager=[NSLayoutManager new];
 NSTextContainer *container=[[NSTextContainer alloc] initWithSize:CGSizeMake(MAX(1,holder.bounds.size.width-inset.left-inset.right),CGFLOAT_MAX)];container.lineFragmentPadding=padding;
 [manager addTextContainer:container];[storage addLayoutManager:manager];
 CGPoint at=[g locationInView:holder];
 {
  NSRange range=word;
  NSRange glyphs=[manager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  CGRect box=[manager boundingRectForGlyphRange:glyphs inTextContainer:container];box.origin.x+=inset.left;box.origin.y+=inset.top;
  if(label){CGRect used=[manager usedRectForTextContainer:container];box.origin.y+=MAX(0,(holder.bounds.size.height-used.size.height)/2);} // a label centres its text vertically
  BOOL hit=CGRectContainsPoint(CGRectInset(box,-16,-16),at);
  tapLog([NSString stringWithFormat:@"tap %@ hit=%d holder=%@ at=(%.0f,%.0f) link=(%.0f,%.0f %.0fx%.0f) size=%.0fx%.0f",@"name",hit,NSStringFromClass(holder.class),at.x,at.y,box.origin.x,box.origin.y,box.size.width,box.size.height,holder.bounds.size.width,holder.bounds.size.height]);
  if(!hit)return;
  openMYbloXXSettings(self.link?:holder);
  return;
 }
}
@end
static void installTap(UIView *link,UIView *holder){
 if(objc_getAssociatedObject(holder,&tapInstalled))return;
 MYBSupTapTarget *target=[MYBSupTapTarget new];target.holder=holder;target.link=link;
 UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:target action:@selector(tapped:)];tap.cancelsTouchesInView=NO;
 for(UIView *v=holder;v&&![v isKindOfClass:UITableView.class];v=v.superview)v.userInteractionEnabled=YES; // every view between the text and the table must accept touches
 if([holder isKindOfClass:UITextView.class]){((UITextView *)holder).editable=NO;((UITextView *)holder).selectable=NO;}
 [holder addGestureRecognizer:tap];objc_setAssociatedObject(holder,&tapInstalled,target,OBJC_ASSOCIATION_RETAIN_NONATOMIC); // the recognizer does not retain its target
}
static UIFont *holderFont(UIView *v){return [v isKindOfClass:UILabel.class]?((UILabel *)v).font:((UITextView *)v).font;}
static CGFloat holderWidth(UIView *v){
 if([v isKindOfClass:UITextView.class]){UITextView *tv=(UITextView *)v;return tv.bounds.size.width-tv.textContainerInset.left-tv.textContainerInset.right-2*tv.textContainer.lineFragmentPadding;}
 return v.bounds.size.width;
}
static void applyBrand(UIView *link){
 UIView *holder=textHolder(link,0);if(!holder)return;
 NSString *want=displayText(brandedText());
 NSString *saved=objc_getAssociatedObject(holder,&originalText);
 UIColor *gray=UIColor.secondaryLabelColor; // the standard grey of a Settings footer, not the blue of a link
 if(want){
  if(!saved)objc_setAssociatedObject(holder,&originalText,holderText(holder)?:@"",OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if(![holderText(holder) isEqualToString:want]){
   UIFont *font=holderFont(holder)?:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
   if([holder isKindOfClass:UILabel.class]){((UILabel *)holder).attributedText=brandedAttributed(want,font,gray,((UILabel *)holder).textAlignment,((UILabel *)holder).lineBreakMode);}
   else{UITextView *tv=(UITextView *)holder;tv.linkTextAttributes=@{NSForegroundColorAttributeName:gray};tv.attributedText=brandedAttributed(want,font,gray,tv.textAlignment,NSLineBreakByWordWrapping);} // iOS's own link is not kept; the MYbloXX word is ours
   installTap(link,holder);
  }
  // Measured on the device screenshot: the line sat about 12 pt closer to the box bottom than the top, so it is lifted 6 pt to sit evenly.
  holder.transform=CGAffineTransformMakeTranslation(0,-6);
  // Shrink the box iOS sized for its longer text to what the branded text needs (same padding as iOS leaves).
  NSString *original=objc_getAssociatedObject(holder,&originalText);CGFloat width=holderWidth(holder);UIFont *font=holderFont(holder);
  if(width>0&&font)MYBSupFit(link,MYBSupTextHeight(original,font,width)-MYBSupTextHeight(want,font,width));
 }else if(saved){
  if([holder isKindOfClass:UILabel.class])((UILabel *)holder).text=saved;else((UITextView *)holder).text=saved;
  objc_setAssociatedObject(holder,&originalText,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  holder.transform=CGAffineTransformIdentity;
  MYBSupFit(link,0);
 }
}
// Every message view that exists, so the text can follow the protection state without Settings being closed and reopened.
static NSHashTable<UIView *> *signViews;
static void refreshSigns(void){
 brandAt=nil; // the next read is of the real state
 for(UIView *v in signViews.allObjects){[v setNeedsLayout];[v layoutIfNeeded];UITableView *table=MYBSupOwningTable(v);if(table){[table beginUpdates];[table endUpdates];}}
}
%hook PSUIFooterHyperlinkView
- (void)didMoveToWindow{%orig;if(self.window){brandAt=nil;[self setNeedsLayout];}} // coming back to the list shows the current state at once
- (void)layoutSubviews {
 %orig;
 if(!signViews)signViews=[NSHashTable weakObjectsHashTable];[signViews addObject:self];
 if(!hideSign)applyBrand(self); // Hide Supervision Message keeps its own layout handling below and wins when on
 // This is the dedicated hyperlink footer used for Settings' supervision sign.
 NSDictionary *previous=objc_getAssociatedObject(self,&previousVisibility);
 if(hideSign){
  if(!previous)objc_setAssociatedObject(self,&previousVisibility,@{@"hidden":@(self.hidden),@"accessibility":@(self.accessibilityElementsHidden)},OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  self.hidden=YES;self.accessibilityElementsHidden=YES;
  MYBSupApply(self,YES); // reclaim the space the message reserved (table header or section header/footer)
 }else if(previous){
  self.hidden=[previous[@"hidden"] boolValue];self.accessibilityElementsHidden=[previous[@"accessibility"] boolValue];objc_setAssociatedObject(self,&previousVisibility,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 }
}
- (CGSize)sizeThatFits:(CGSize)size {return hideSign?CGSizeZero:%orig;}
%end
// Section heights come from the list controller. Hooked only where the class itself declares the method, and only
// ever changes the answer for a section this tweak has collapsed; everything else calls the original.
static void hookHeights(Class cls){
 if(!cls)return;
 for(int f=0;f<2;f++){
  SEL sel=f?@selector(tableView:heightForFooterInSection:):@selector(tableView:heightForHeaderInSection:);
  unsigned count=0;Method *list=class_copyMethodList(cls,&count);Method method=NULL;for(unsigned i=0;i<count;i++)if(method_getName(list[i])==sel)method=list[i];free(list);
  if(!method)continue;
  IMP original=method_getImplementation(method);BOOL isFooter=f==1;
  method_setImplementation(method,imp_implementationWithBlock(^CGFloat(id receiver,UITableView *table,NSInteger section){
   CGFloat height=0;if(hideSign&&MYBSupHeightOverride(table,section,isFooter,&height))return height;
   CGFloat natural=((CGFloat(*)(id,SEL,UITableView *,NSInteger))original)(receiver,sel,table,section);
   CGFloat fit=hideSign?0:MYBSupFitDelta(table,section,isFooter);
   return fit>0?MAX(1,natural-fit):natural;
  }));
 }
}
%ctor{@autoreleasepool{
 reloadSign();hookHeights(NSClassFromString(@"PSListController"));hookHeights(NSClassFromString(@"PSUIPrefsListController"));
 int stateToken=0;notify_register_dispatch("net.myxxdev.mybloxx.statuschanged",&stateToken,dispatch_get_main_queue(),^(__unused int t){refreshSigns();});
 int token=0;notify_register_dispatch("net.myxxdev.mybloxx.appearance.changed",&token,dispatch_get_main_queue(),^(__unused int t){
  reloadSign();if(!hideSign)MYBSupRestoreAll();
  for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){if([scene isKindOfClass:UIWindowScene.class])for(UIWindow *window in ((UIWindowScene *)scene).windows){[window setNeedsLayout];[window layoutIfNeeded];}}
 });
}}
