// The native glass layer, kept restrained: glass only on floating sheets, a fixed backdrop glow, a one-shot status pop,
// a short row reveal and haptics. Built only from UIKit that exists on iOS 15/16 (UIVisualEffectView materials, CAGradientLayer,
// CABasicAnimation). Rules every effect follows:
//  * Reduce Transparency (and Increase Contrast / Darker System Colors): solid opaque surfaces, no blur, no ambient field.
//  * Reduce Motion, Low Power Mode, app in background, or screen not visible: nothing animates; the static look remains.
//  * No animation ever delays an action: rows are interactive while they reveal, and every reveal has a hard end state.
#import "MYBDesign.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#if MYB_PREVIEW_HARNESS
static int gOverrideTransparency=-1,gOverrideMotion=-1;
void MYBSetAccessibilityOverride(int transparency,int motion){gOverrideTransparency=transparency;gOverrideMotion=motion;[NSNotificationCenter.defaultCenter postNotificationName:MYBMotionStateChanged object:nil];[NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];}
#endif
NSString *const MYBMotionStateChanged=@"MYBMotionStateChanged";

BOOL MYBReduceTransparency(void){
#if MYB_PREVIEW_HARNESS
 if(gOverrideTransparency>=0)return gOverrideTransparency==1;
#endif
 return UIAccessibilityIsReduceTransparencyEnabled()||UIAccessibilityDarkerSystemColorsEnabled();
}
BOOL MYBReduceMotion(void){
#if MYB_PREVIEW_HARNESS
 if(gOverrideMotion>=0)return gOverrideMotion==1;
#endif
 return UIAccessibilityIsReduceMotionEnabled();
}

#pragma mark - Motion gate

static NSInteger gVisible=0;static BOOL gBackground=NO;
// Motion runs unless the person turned on Reduce Motion or the app is in the background. (It used to also wait for a screen-visible counter that nothing ever raised, so it never ran at all.)
BOOL MYBMotionAllowed(void){return !gBackground&&!MYBReduceMotion();}
static void postMotion(void){[NSNotificationCenter.defaultCenter postNotificationName:MYBMotionStateChanged object:nil];}
void MYBMotionScreenAppeared(void){gVisible++;postMotion();}
void MYBMotionScreenDisappeared(void){if(gVisible>0)gVisible--;postMotion();}
__attribute__((constructor)) static void MYBMotionObserve(void){
 NSNotificationCenter *c=NSNotificationCenter.defaultCenter;
 [c addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *n){(void)n;gBackground=YES;postMotion();}];
 [c addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification *n){(void)n;gBackground=NO;postMotion();}];
 [c addObserverForName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *n){(void)n;postMotion();}];
 [c addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *n){(void)n;postMotion();}];
}

#pragma mark - Materials

// Grouped rows: a translucent tint over the fixed backdrop glow (no blur, no border per row, so adjacent rows read as one
// surface). Solid when transparency is reduced.
UIColor *MYBGroupFill(void){return MYBReduceTransparency()?MYBPanel():[UIColor colorWithRed:.10 green:.105 blue:.165 alpha:.68];}
UIColor *MYBGlassFill(void){return MYBReduceTransparency()?MYBPanel():[UIColor colorWithRed:.13 green:.14 blue:.21 alpha:.56];}

@interface MYBGlassView ()
@property(nonatomic,strong) UIVisualEffectView *blur;
@property(nonatomic,strong) CAGradientLayer *sheen;
@end
@implementation MYBGlassView
- (instancetype)initWithFrame:(CGRect)frame{
 if((self=[super initWithFrame:frame])){
  self.userInteractionEnabled=NO;self.layer.cornerCurve=kCACornerCurveContinuous;self.layer.masksToBounds=YES;self.layer.borderWidth=.5;
  self.radius=28;
  self.blur=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];self.blur.frame=self.bounds;self.blur.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self addSubview:self.blur];
  self.sheen=[CAGradientLayer layer];self.sheen.colors=@[(id)[UIColor colorWithWhite:1 alpha:.07].CGColor,(id)[UIColor colorWithWhite:1 alpha:0].CGColor];self.sheen.locations=@[@0,@.45];self.sheen.startPoint=CGPointMake(.5,0);self.sheen.endPoint=CGPointMake(.5,1);[self.layer addSublayer:self.sheen];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
  [self refresh];
 }return self;
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)setRadius:(CGFloat)radius{_radius=radius;self.layer.cornerRadius=radius;}
- (BOOL)solid{return MYBReduceTransparency();}
- (void)refresh{
 BOOL solid=self.solid;
 self.blur.hidden=solid;self.sheen.hidden=solid;
 self.backgroundColor=solid?MYBPanel():[UIColor colorWithRed:.045 green:.045 blue:.09 alpha:.92]; // deep, nearly opaque: a popup matches the dark of the rest of the app instead of turning light grey over bright content
 self.layer.borderColor=(solid?[UIColor colorWithWhite:1 alpha:.16]:[UIColor colorWithRed:.55 green:.50 blue:1 alpha:.28]).CGColor;
}
- (void)layoutSubviews{[super layoutSubviews];[CATransaction begin];[CATransaction setDisableActions:YES];self.sheen.frame=self.bounds;[CATransaction commit];}
@end

#pragma mark - Static backdrop

// One quiet violet glow at the top of the screen, fixed. Nothing here ever animates: motion is reserved for things that
// respond to the user or report a change. Reduce Transparency removes the glow and leaves the plain background.
@implementation MYBBackdropView{CAGradientLayer *_glow;}
- (instancetype)initWithFrame:(CGRect)frame{
 if((self=[super initWithFrame:frame])){
  self.userInteractionEnabled=NO;self.backgroundColor=MYBBackground();self.isAccessibilityElement=NO;
  _glow=[CAGradientLayer layer];_glow.type=kCAGradientLayerRadial;_glow.startPoint=CGPointMake(.5,.5);_glow.endPoint=CGPointMake(1,1);
  UIColor *c=MYBToneDeepColor(MYBToneViolet);_glow.colors=@[(id)[c colorWithAlphaComponent:.30].CGColor,(id)[c colorWithAlphaComponent:0].CGColor];
  [self.layer addSublayer:_glow];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
  [self refresh];
 }return self;
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)refresh{_glow.hidden=MYBReduceTransparency();}
- (BOOL)glowVisible{return !_glow.hidden;}
- (void)layoutSubviews{
 [super layoutSubviews];CGFloat w=self.bounds.size.width;
 [CATransaction begin];[CATransaction setDisableActions:YES];_glow.frame=CGRectMake(-.25*w,-.55*w,1.5*w,1.5*w);[CATransaction commit];
}
@end

#pragma mark - Feedback, reveal, haptics

// One-shot confirmation of a status change: a brief scale pop. Never repeats; skipped when motion is not allowed.
void MYBStatusPop(UIView *view){
 if(!view||!MYBMotionAllowed())return;
 [view.layer removeAnimationForKey:@"mybPop"];
 CAKeyframeAnimation *a=[CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];a.values=@[@1,@1.35,@1];a.keyTimes=@[@0,@.4,@1];a.duration=.45;a.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
 [view.layer addAnimation:a forKey:@"mybPop"];
}

void MYBRevealRows(UITableView *table){
 if(!MYBMotionAllowed())return; // Reduce Motion / background / low power: rows simply appear, finished
 NSArray<UITableViewCell *> *cells=table.visibleCells;NSUInteger shown=0;
 for(UITableViewCell *cell in cells){
  if(shown>=10)break;
  cell.alpha=0;cell.transform=CGAffineTransformMakeTranslation(0,8);
  [UIView animateWithDuration:.4 delay:.03*shown usingSpringWithDamping:.88 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState animations:^{cell.alpha=1;cell.transform=CGAffineTransformIdentity;} completion:nil];
  shown++;
 }
 // Hard end state: whatever happens to the animations, no row is ever left faded or displaced.
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{for(UITableViewCell *cell in table.visibleCells){cell.alpha=1;cell.transform=CGAffineTransformIdentity;}});
}

void MYBHaptic(MYBHapticKind kind){
 if(MYBReduceMotion())return; // the system-wide reduction preference also quiets decorative feedback
 if(kind==MYBHapticSuccess||kind==MYBHapticFailure){UINotificationFeedbackGenerator *g=[UINotificationFeedbackGenerator new];[g notificationOccurred:kind==MYBHapticSuccess?UINotificationFeedbackTypeSuccess:UINotificationFeedbackTypeError];}
 else{UIImpactFeedbackGenerator *g=[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];[g impactOccurred];}
}
