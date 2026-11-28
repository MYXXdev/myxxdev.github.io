#import <UIKit/UIKit.h>

// ---------------------------------------------------------------------------
// MYbloXX design system
//
// One set of tokens, one cell, one switch, one header/footer pair, one sheet.
// Every screen is built from these so spacing, type and motion stay consistent.
// Cards are plain UIViews whose corners are chosen with maskedCorners, never
// hand-drawn shape layers, so nothing depends on bounds timing or cell reuse.
// ---------------------------------------------------------------------------

#define MYBMargin        20.0   // distance from screen edge to card edge
#define MYBCardRadius    20.0   // card corner radius (continuous curve)
#define MYBRowPadH       16.0   // card edge to row content
#define MYBRowPadV       12.0   // row content to card row edge
#define MYBTileSize      32.0   // icon tile (square)
#define MYBTileGap       14.0   // icon tile to text
#define MYBTextInset     (MYBMargin + MYBRowPadH) // section header/footer text inset

// Semantic tones for icon tiles. Quiet glass tile, tone-coloured glyph.
typedef NS_ENUM(NSInteger, MYBTone) {
 MYBToneViolet=0, MYBToneIndigo, MYBToneBlue, MYBToneTeal, MYBToneGreen, MYBToneAmber, MYBToneRose, MYBToneSlate
};
UIColor *MYBToneColor(MYBTone tone);        // glyph / emphasis colour
UIColor *MYBToneDeepColor(MYBTone tone);    // darker partner for gradients

UIColor *MYBAccent(void);
UIColor *MYBBackground(void);
UIColor *MYBPanel(void);
UIColor *MYBPanelHighlight(void);
UIColor *MYBMuted(void);
UIColor *MYBHairline(void);
UIColor *MYBPositive(void);
UIColor *MYBWarning(void);
UIColor *MYBDanger(void);
UIFont *MYBFont(CGFloat size,UIFontWeight weight);
UIFont *MYBRoundedFont(CGFloat size,UIFontWeight weight);
UIImage *MYBMark(void);
NSString *MYBMobileFile(NSString *path);
NSString *MYBPath(NSString *relativePath);

// Self-sizing screen header (kicker, title, optional detail).
UIView *MYBHero(NSString *eyebrow, NSString *title, NSString *detail, BOOL compact);
// Secondary screens: a compact header with a gradient symbol badge, the screen name and one summary line. The badge settles in once, with a short spring.
UIView *MYBHeroBadge(NSString *symbol, MYBTone tone, NSString *title, NSString *detail);
// A summary tile (gradient wash, symbol, big number, caption). Returns the view and the number label for updates.
UIView *MYBSummaryTile(NSString *symbol, MYBTone tone, NSString *caption, UILabel *__autoreleasing *valueOut);
// Counts a number label up to `target` once (about half a second); a label already showing it, or Reduce Motion, just shows it.
void MYBCountUp(UILabel *label, NSInteger target);
// The one tile pattern: tappable count tiles where the selected tile is bright and the others dim, announced to VoiceOver as selected.
// selected < 0 means none is selected (the tiles are plain buttons that navigate). Use it anywhere a screen switches between views of one list.
UIView *MYBTileStrip(NSArray<NSDictionary *> *tileSpecs,NSInteger selected,id target,SEL tileAction,NSArray<UILabel *> **valuesOut);
void MYBTileApplySelection(UIView *container,NSInteger selected);
UIView *MYBStatHero(NSString *symbol,MYBTone tone,NSString *title,NSString *detail,NSArray<NSDictionary *> *tileSpecs,NSArray<NSString *> *segmentTitles,NSInteger selected,id target,SEL tileAction,SEL segmentAction,NSArray<UILabel *> **valuesOut,UISegmentedControl **segmentOut);
// A quick press-and-release spring on a view, for taps on custom controls.
void MYBPressPulse(UIView *view);
// Dashboard identity header. `status` is the protection text; it is interpreted
// (active / paused / checking / needs attention) rather than shown verbatim.
// State comes from the structured model (Shared/MYBStatusModel.h): tone is positive | warning | neutral.
UIView *MYBDashboardHero(NSString *title,NSString *detail,NSString *tone,NSString *mode);

void MYBStyleCell(UITableViewCell *cell);
void MYBStyleTable(UITableView *table);
// Applies one navigation-bar treatment to `owner`'s navigation item only.
void MYBStyleNavigation(UIViewController *owner);
// Only the navigation item's appearance; safe to call before the view exists.
void MYBStyleNavigationItem(UIViewController *owner);

// Sheets: progress / result / message / confirm / input / choose.
void MYBProgress(UIViewController *owner, NSString *title);
void MYBComplete(UIViewController *owner, BOOL success, NSString *title, NSString *detail);
void MYBMessage(UIViewController *owner, NSString *title, NSString *detail);
void MYBDismissStatus(UIViewController *owner);
void MYBInputCancellable(UIViewController *owner,NSString *title,NSString *detail,NSArray *fields,NSString *titleButton,void(^action)(NSArray *),void(^cancelled)(void));
void MYBConfirm(UIViewController *owner,NSString *title,NSString *detail,void(^action)(void));
void MYBConfirmWithButton(UIViewController *owner,NSString *title,NSString *detail,NSString *button,void(^action)(void));
void MYBConfirmDestructive(UIViewController *owner,NSString *title,NSString *detail,NSString *button,void(^action)(void));
void MYBInput(UIViewController *owner,NSString *title,NSString *detail,NSArray<NSDictionary *> *fields,NSString *button,void(^action)(NSArray<NSString *> *));
void MYBChoose(UIViewController *owner,NSString *title,NSArray<NSString *> *choices,void(^action)(NSUInteger));
void MYBDecision(UIViewController *owner,BOOL allowed,NSString *domain,NSString *reason);

@interface MYBSectionHeaderView : UITableViewHeaderFooterView
@property(nonatomic,strong,readonly) UILabel *label;
- (void)setTitle:(NSString *)title;
@end

@interface MYBSectionFooterView : UITableViewHeaderFooterView
@property(nonatomic,strong,readonly) UILabel *label;
- (void)setText:(NSString *)text;
@end

@interface MYBPrismSwitch : UIControl
@property(nonatomic,getter=isOn) BOOL on;
@property(nonatomic,strong) UIColor *onTintColor;
// Stable identity of what this switch controls (bundle id, preference key...).
// Handlers read this instead of a table row index, which goes stale on reuse/search.
@property(nonatomic,copy) NSString *key;
- (void)setOn:(BOOL)value animated:(BOOL)animated;
@end

@interface MYBPrismCell : UITableViewCell
@property(nonatomic,strong,readonly) UILabel *mybTitleLabel;
@property(nonatomic,strong,readonly) UILabel *mybDetailLabel;
@property(nonatomic,strong,readonly) UIImageView *mybIconView;
// An installed app's own icon (replaces the symbol tile; nil returns to the symbol). Cleared on reuse.
@property(nonatomic,strong) UIImage *mybAppIcon;
@property(nonatomic,strong) UIView *mybAccessoryView;
@property(nonatomic,assign) UITableViewCellAccessoryType mybAccessoryType;
@property(nonatomic,assign) MYBTone tone;
@property(nonatomic,assign) BOOL firstInGroup;
@property(nonatomic,assign) BOOL lastInGroup;
// Dequeues (or creates) a reusable cell, fully reset.
+ (instancetype)cellForTable:(UITableView *)table;
- (void)refreshContent;
- (UIView *)mybPanelView; // the card surface (read by the glass tests)
@end

// ---------------------------------------------------------------------------
// Liquid-glass layer (Preferences/MYBGlass.m)
// ---------------------------------------------------------------------------
extern NSString *const MYBMotionStateChanged;
BOOL MYBReduceTransparency(void);   // Reduce Transparency or Darker System Colors: surfaces become solid
BOOL MYBReduceMotion(void);
BOOL MYBMotionAllowed(void);        // foreground && !Reduce Motion
void MYBMotionScreenAppeared(void);
void MYBMotionScreenDisappeared(void);
#if MYB_PREVIEW_HARNESS
void MYBSetAccessibilityOverride(int transparency,int motion); // -1 = system value
#endif
UIColor *MYBGroupFill(void);        // fill for grouped rows: translucent tint, or the opaque panel when transparency is reduced
UIColor *MYBGlassFill(void);        // translucent sheet fill, or the opaque panel when transparency is reduced

@interface MYBGlassView : UIView   // blur + tint + sheen + hairline; solid when transparency is reduced
@property(nonatomic) CGFloat radius;
@property(nonatomic,readonly) BOOL solid;
@end
@interface MYBBackdropView : UIView // fixed background glow; never animates, plain colour when transparency is reduced
- (BOOL)glowVisible;
@end
void MYBStatusPop(UIView *view);    // one-shot scale pop for a status change; never repeats
void MYBRevealRows(UITableView *table); // short entrance for the first visible rows, once per screen; interactive throughout
typedef NS_ENUM(NSInteger,MYBHapticKind){MYBHapticLight,MYBHapticSuccess,MYBHapticFailure};
void MYBHaptic(MYBHapticKind kind);
