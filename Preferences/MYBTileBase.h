#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import <objc/message.h>
// Shared by the Pop-Up Control and App Redirect Protection screens: the Activity-style header (a badge, up to three tappable summary tiles, an
// optional segmented filter) plus the small helpers their lists use. Nothing here reads or writes settings.
@interface MYBTileListBase : MYBMenuBase
@property(nonatomic,strong) NSArray<UILabel *> *tileValues;
@property(nonatomic,strong) UISegmentedControl *segment;
- (NSString *)heroSymbol;
- (MYBTone)heroTone;
- (NSArray<NSDictionary *> *)tileSpecs;      // @{label,tone,symbol}
- (NSArray<NSString *> *)tileValueTexts;     // one number per tile
- (NSArray<NSString *> *)segmentTitles;
- (void)tapTile:(NSInteger)index;
- (void)updateTiles;
@end
static inline NSString *MYBTileAppName(NSString *bundle){
 if(![bundle isKindOfClass:NSString.class]||!bundle.length)return @"Unknown app";
 Class cls=NSClassFromString(@"LSApplicationProxy");SEL sel=NSSelectorFromString(@"applicationProxyForIdentifier:");
 id proxy=[cls respondsToSelector:sel]?((id(*)(id,SEL,id))objc_msgSend)(cls,sel,bundle):nil;
 NSString *name=[proxy respondsToSelector:NSSelectorFromString(@"localizedName")]?[proxy valueForKey:@"localizedName"]:nil;return name.length?name:bundle;
}
static inline NSString *MYBTileClock(double wall){NSDateFormatter *f=[NSDateFormatter new];f.timeStyle=NSDateFormatterShortStyle;f.dateStyle=NSDateFormatterNoStyle;return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:wall]];}
static inline NSString *MYBTileAgo(double wall){NSRelativeDateTimeFormatter *f=[NSRelativeDateTimeFormatter new];f.unitsStyle=NSRelativeDateTimeFormatterUnitsStyleShort;return [f localizedStringForDate:[NSDate dateWithTimeIntervalSince1970:wall] relativeToDate:NSDate.date];}
// How long a saved permission lasts, in words a person can act on.
static inline NSString *MYBTileDuration(NSString *mode,double wallExpiry){
 if([mode isEqual:@"always"])return @"Always";
 if([mode isEqual:@"block"])return @"Always blocked";
 if([mode isEqual:@"once"])return wallExpiry>0?[NSString stringWithFormat:@"Once · expires by %@",MYBTileClock(wallExpiry)]:@"Once";
 return wallExpiry>0?[NSString stringWithFormat:@"15 minutes · until %@",MYBTileClock(wallExpiry)]:@"15 minutes";
}
// A cell for an empty list or a plain action row.
static inline MYBPrismCell *MYBTileInfoCell(UITableView *t,NSString *title,NSString *detail,NSString *symbol,MYBTone tone,BOOL tappable){
 MYBPrismCell *cell=[MYBPrismCell cellForTable:t];cell.selectionStyle=tappable?UITableViewCellSelectionStyleDefault:UITableViewCellSelectionStyleNone;
 cell.mybTitleLabel.text=title;cell.mybTitleLabel.numberOfLines=2;cell.mybDetailLabel.text=detail;cell.mybIconView.image=[UIImage systemImageNamed:symbol];cell.tone=tone;[cell refreshContent];return cell;
}
