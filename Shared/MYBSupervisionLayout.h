#pragma once
// Reclaims the space of Settings' supervision message when "Hide Supervision Message" is on, and puts it back when off.
// Hiding the label is not enough: the message sits in a container whose height the table has already reserved. The
// container is either the table's header view or a section header/footer. Both are handled here:
//   * table header: the owning header view is detached (kept, retained, for restoring) and the scroll position is kept;
//   * section header/footer: the section's height is reported as ~0 through MYBSupHeightOverride(), which the tweak
//     calls from the list controller's height methods, then the table relayouts.
// Nothing here changes supervision state; it is presentation only. Unknown layouts (no owning table) are left alone.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
static char MYBSupOriginalHeader,MYBSupHeaderHeight,MYBSupCollapsedHeaders,MYBSupCollapsedFooters;
static NSHashTable *MYBSupTables(void){static NSHashTable *t;static dispatch_once_t once;dispatch_once(&once,^{t=[NSHashTable weakObjectsHashTable];});return t;}
static inline UITableView *MYBSupOwningTable(UIView *v){for(UIView *x=v;x;x=x.superview)if([x isKindOfClass:UITableView.class])return (UITableView *)x;return nil;}
static inline BOOL MYBSupIsDescendant(UIView *view,UIView *ancestor){for(UIView *x=view;x;x=x.superview)if(x==ancestor)return YES;return NO;}
static inline void MYBSupKeepOffset(UITableView *table,CGFloat removed){ // never jump: stay at the top when at the top, otherwise follow the content
 CGFloat top=-table.adjustedContentInset.top,y=table.contentOffset.y;
 CGFloat target=y<=top+1?top:MAX(top,y-removed);
 [table layoutIfNeeded];CGFloat maxY=MAX(top,table.contentSize.height-table.bounds.size.height+table.adjustedContentInset.bottom);
 table.contentOffset=CGPointMake(table.contentOffset.x,MIN(target,maxY));
}
static inline void MYBSupRelayout(UITableView *table,CGFloat removed){
 [UIView performWithoutAnimation:^{[table beginUpdates];[table endUpdates];MYBSupKeepOffset(table,removed);}];
}
// `link` is the supervision message view (PSUIFooterHyperlinkView). hide==YES collapses its container; NO restores.
static inline void MYBSupApply(UIView *link,BOOL hide){
 UITableView *table=MYBSupOwningTable(link);if(!table)return;[MYBSupTables() addObject:table];
 UIView *orig=objc_getAssociatedObject(table,&MYBSupOriginalHeader);
 if(!hide){return;} // restoring is done table-wide by MYBSupRestoreAll (the link view is gone while the header is detached)
 if(!orig&&table.tableHeaderView&&MYBSupIsDescendant(link,table.tableHeaderView)){
  UIView *header=table.tableHeaderView;CGFloat h=header.bounds.size.height;
  objc_setAssociatedObject(table,&MYBSupOriginalHeader,header,OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(table,&MYBSupHeaderHeight,@(h),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  dispatch_async(dispatch_get_main_queue(),^{ // not inside the layout pass that found it
   if(table.tableHeaderView!=header)return;
   [table layoutIfNeeded];CGFloat before=table.contentSize.height;[UIView performWithoutAnimation:^{table.tableHeaderView=nil;[table layoutIfNeeded];}];
   MYBSupKeepOffset(table,MAX(0,before-table.contentSize.height)); // the measured shrink: grouped tables keep their own top padding
  });
  return;
 }
 if(orig)return;
 // Section header/footer: find which section's view contains the link.
 for(NSInteger s=0;s<table.numberOfSections;s++){
  // Containment first; geometry as the fallback, because plain views returned by the delegate (not header/footer views)
  // are not reported by footerViewForSection:. The message is in the section whose header/footer rect contains it.
  UIView *footer=[table footerViewForSection:s],*head=[table headerViewForSection:s];BOOL isFooter=footer&&MYBSupIsDescendant(link,footer),isHeader=head&&MYBSupIsDescendant(link,head);
  if(!isFooter&&!isHeader){CGRect box=[table convertRect:link.bounds fromView:link],f=[table rectForFooterInSection:s],h=[table rectForHeaderInSection:s];
   CGPoint c=CGPointMake(CGRectGetMidX(box),CGRectGetMidY(box));isFooter=CGRectGetHeight(f)>1&&CGRectContainsPoint(f,c);if(!isFooter)isHeader=CGRectGetHeight(h)>1&&CGRectContainsPoint(h,c);}
  if(!isFooter&&!isHeader)continue;
  char *key=isFooter?&MYBSupCollapsedFooters:&MYBSupCollapsedHeaders;NSMutableIndexSet *set=objc_getAssociatedObject(table,key);
  if(!set){set=[NSMutableIndexSet indexSet];objc_setAssociatedObject(table,key,set,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
  if([set containsIndex:(NSUInteger)s])return;
  CGFloat before=isFooter?CGRectGetHeight([table rectForFooterInSection:s]):CGRectGetHeight([table rectForHeaderInSection:s]);
  [set addIndex:(NSUInteger)s];
  // A section that exists only to carry the message has no rows. Its other half (the footer when the message is the header, or the
  // header when it is the footer) would otherwise keep its stock height and leave a gap larger than iOS has without the message.
  if([table numberOfRowsInSection:s]==0){
   char *otherKey=isFooter?&MYBSupCollapsedHeaders:&MYBSupCollapsedFooters;NSMutableIndexSet *other=objc_getAssociatedObject(table,otherKey);
   if(!other){other=[NSMutableIndexSet indexSet];objc_setAssociatedObject(table,otherKey,other,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
   [other addIndex:(NSUInteger)s];
  }
  dispatch_async(dispatch_get_main_queue(),^{MYBSupRelayout(table,before);});return;
 }
}
// ---- Fitting the container to the branded text ------------------------------------------------------------------------------
// iOS reserves the container for ITS text, which is longer than the branded one, so a short message floats in a tall, empty box. The same
// padding iOS leaves around its own text is kept: the container shrinks by exactly the height the shorter text no longer needs.
static char MYBSupFitHeader,MYBSupFitSections,MYBSupFitKey;
static inline CGFloat MYBSupTextHeight(NSString *text,UIFont *font,CGFloat width){
 if(!text.length||width<=0||!font)return 0;
 return ceil([text boundingRectWithSize:CGSizeMake(width,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:font} context:nil].size.height);
}
// Called with the extra height to remove (0 = none, restore). Safe to call on every layout pass: it acts only when the amount changes.
static inline void MYBSupFit(UIView *link,CGFloat delta){
 UITableView *table=MYBSupOwningTable(link);if(!table)return;
 delta=delta>0.5?floor(delta):0;
 NSNumber *last=objc_getAssociatedObject(link,&MYBSupFitKey);if(last&&[last doubleValue]==delta)return;
 objc_setAssociatedObject(link,&MYBSupFitKey,@(delta),OBJC_ASSOCIATION_RETAIN_NONATOMIC);[MYBSupTables() addObject:table];
 UIView *header=table.tableHeaderView;
 if(header&&MYBSupIsDescendant(link,header)){
  NSNumber *orig=objc_getAssociatedObject(header,&MYBSupFitHeader);CGFloat original=orig?orig.doubleValue:header.bounds.size.height;
  if(!orig){if(delta<=0)return;objc_setAssociatedObject(header,&MYBSupFitHeader,@(original),OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
  dispatch_async(dispatch_get_main_queue(),^{
   if(table.tableHeaderView!=header)return;
   CGRect frame=header.frame;frame.size.height=MAX(1,original-delta);
   [UIView performWithoutAnimation:^{header.frame=frame;table.tableHeaderView=header;[table layoutIfNeeded];}];
  });
  return;
 }
 for(NSInteger s=0;s<table.numberOfSections;s++){
  UIView *footer=[table footerViewForSection:s],*head=[table headerViewForSection:s];BOOL isFooter=footer&&MYBSupIsDescendant(link,footer),isHeader=head&&MYBSupIsDescendant(link,head);
  if(!isFooter&&!isHeader){CGRect box=[table convertRect:link.bounds fromView:link],f=[table rectForFooterInSection:s],h=[table rectForHeaderInSection:s];
   CGPoint c=CGPointMake(CGRectGetMidX(box),CGRectGetMidY(box));isFooter=CGRectGetHeight(f)>1&&CGRectContainsPoint(f,c);if(!isFooter)isHeader=CGRectGetHeight(h)>1&&CGRectContainsPoint(h,c);}
  if(!isFooter&&!isHeader)continue;
  NSMutableDictionary *map=objc_getAssociatedObject(table,&MYBSupFitSections);if(!map){map=[NSMutableDictionary dictionary];objc_setAssociatedObject(table,&MYBSupFitSections,map,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
  NSString *key=[NSString stringWithFormat:@"%c%ld",isFooter?'f':'h',(long)s];
  if(delta>0)map[key]=@(delta);else [map removeObjectForKey:key];
  dispatch_async(dispatch_get_main_queue(),^{MYBSupRelayout(table,0);});
  return;
 }
}
// Extra height to take off a section header/footer the list controller sized for iOS's own text (0 when none).
static inline CGFloat MYBSupFitDelta(UITableView *table,NSInteger section,BOOL footer){
 NSDictionary *map=objc_getAssociatedObject(table,&MYBSupFitSections);
 return [map[[NSString stringWithFormat:@"%c%ld",footer?'f':'h',(long)section]] doubleValue];
}
// The list controller's height methods call this first; YES means "use *height" (the section is collapsed).
static inline BOOL MYBSupHeightOverride(UITableView *table,NSInteger section,BOOL footer,CGFloat *height){
 NSIndexSet *set=objc_getAssociatedObject(table,footer?&MYBSupCollapsedFooters:&MYBSupCollapsedHeaders);
 if(set&&[set containsIndex:(NSUInteger)section]){if(height)*height=CGFLOAT_MIN;return YES;}return NO;
}
// Hide turned off (or the tweak is told the setting changed): put every collapsed header/section back.
static inline void MYBSupRestoreAll(void){
 for(UITableView *table in MYBSupTables().allObjects){
  UIView *orig=objc_getAssociatedObject(table,&MYBSupOriginalHeader);NSNumber *h=objc_getAssociatedObject(table,&MYBSupHeaderHeight);
  BOOL had=orig!=nil||[objc_getAssociatedObject(table,&MYBSupCollapsedFooters) count]||[objc_getAssociatedObject(table,&MYBSupCollapsedHeaders) count];if(!had)continue;
  objc_setAssociatedObject(table,&MYBSupCollapsedFooters,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(table,&MYBSupCollapsedHeaders,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if(orig){objc_setAssociatedObject(table,&MYBSupOriginalHeader,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(table,&MYBSupHeaderHeight,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
   [table layoutIfNeeded];CGFloat before=table.contentSize.height;[UIView performWithoutAnimation:^{table.tableHeaderView=orig;[table layoutIfNeeded];}];MYBSupKeepOffset(table,-MAX(0,table.contentSize.height-before));(void)h;}
  else MYBSupRelayout(table,0);
 }
}
