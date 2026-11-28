// MYbloXX In-App Ad Blocking: X. Ads only.
// PROVENANCE: written against interface evidence (BHTwitter's published TFNItemsDataViewController selectors and promoted tests;
// BHTwitter has no licence file). No source text is used, but the decisions follow it; see NOTICE.md in usr/share/doc/mybloxx-inappads.
// Removes items X itself marks as promoted (a promoted post answers isPromoted, a promoted trend carries a promoted_id in its scribe
// data). Ordinary posts, replies, Who to follow, topics, trends and Spaces are left alone, as is everything not marked promoted.
// A promoted row is hidden and given zero height so no gap remains. If the list controller or its methods are not present in a given
// X version, that hook stays off and the app is untouched.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

static IMP origCellForItem,origHeight,origCardHidden,origDynamicAd;
static BOOL MYBXItemIsPromoted(id item){
 if(!item)return NO;
 SEL promoted=sel_registerName("isPromoted");
 if([item respondsToSelector:promoted]&&((BOOL(*)(id,SEL))objc_msgSend)(item,promoted))return YES;
 SEL scribe=sel_registerName("scribeItem");
 if([item respondsToSelector:scribe]){id d=((id(*)(id,SEL))objc_msgSend)(item,scribe);if([d isKindOfClass:NSDictionary.class]&&[[(NSDictionary *)d allKeys] containsObject:@"promoted_id"])return YES;}
 return NO;
}
static id hookCellForItem(id self_,SEL _cmd,id item,id indexPath){
 id cell=((id(*)(id,SEL,id,id))origCellForItem)(self_,_cmd,item,indexPath);
 if(MYBXItemIsPromoted(item)&&[cell respondsToSelector:sel_registerName("setHidden:")]){((void(*)(id,SEL,BOOL))objc_msgSend)(cell,sel_registerName("setHidden:"),YES);MYBAdsNoteDecisions(@"x",@"feed",1);}
 return cell;
}
static double hookHeight(id self_,SEL _cmd,id table,id indexPath){
 double h=((double(*)(id,SEL,id,id))origHeight)(self_,_cmd,table,indexPath);
 SEL itemAt=sel_registerName("itemAtIndexPath:");
 if([self_ respondsToSelector:itemAt]){id item=((id(*)(id,SEL,id))objc_msgSend)(self_,itemAt,indexPath);if(MYBXItemIsPromoted(item))return 0;}
 return h;
}
// A promoted post's card (the link/media preview X attaches) is reported hidden; every other post keeps the app's own answer.
static BOOL hookCardHidden(id self_,SEL _cmd){
 BOOL original=origCardHidden?((BOOL(*)(id,SEL))origCardHidden)(self_,_cmd):NO;
 if(original)return YES;
 SEL promoted=sel_registerName("isPromoted");
 if([self_ respondsToSelector:promoted]&&((BOOL(*)(id,SEL))objc_msgSend)(self_,promoted)){MYBAdsNoteDecisions(@"x",@"feed",1);return YES;}
 return NO;
}
// The account's "dynamic video ads" capability answers no; counted only when the app would have allowed them.
static BOOL hookDynamicAd(id self_,SEL _cmd){
 BOOL original=origDynamicAd?((BOOL(*)(id,SEL))origDynamicAd)(self_,_cmd):NO;
 if(original)MYBAdsNoteDecisions(@"x",@"video",1);
 return NO;
}
NSUInteger MYBXInstallHooks(NSUInteger *attempted){
 struct H{const char *cls,*sel;BOOL classMethod;IMP imp;IMP *orig;} table[]={
  {"TFNItemsDataViewController","tableViewCellForItem:atIndexPath:",NO,(IMP)hookCellForItem,&origCellForItem},
  {"TFNItemsDataViewController","tableView:heightForRowAtIndexPath:",NO,(IMP)hookHeight,&origHeight},
  {"TFNTwitterStatus","isCardHidden",NO,(IMP)hookCardHidden,&origCardHidden},
  {"TFNTwitterAccount","isVideoDynamicAdEnabled",NO,(IMP)hookDynamicAd,&origDynamicAd}};
 NSUInteger count=sizeof(table)/sizeof(table[0]),ok=0;
 for(NSUInteger i=0;i<count;i++)if(MYBAdsHookNamed(table[i].cls,table[i].sel,table[i].classMethod,table[i].imp,table[i].orig))ok++;
 if(attempted)*attempted=count;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_x(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"x"))return;
  MYBAdsReportLoaded(@"x",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBXInstallHooks(&attempted);MYBAdsLogResult("x",ok,attempted);MYBAdsReportHooks(@"x",ok,attempted,0);
 }
}
#endif
