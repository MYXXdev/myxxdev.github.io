// The welcome screen. It shows once after an install or upgrade, on the first unlocked Home Screen, and says plainly whether MYbloXX® is ready or
// whether a MYbloXX® profile that is already installed is in the way, with one button that fixes it. Nothing here runs unless the installer left the
// marker file, and the marker is removed the moment the screen has been shown.
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <sys/wait.h>
#import <objc/message.h>
#import <errno.h>
#import <notify.h>
#import "../../Shared/MYBMYbloXXProfile.h"
extern char **environ;
static UIWindow *welcomeWindow;
static NSString *welcomeMarker(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/WelcomePending");}
static NSString *welcomeFile(NSString *name){return MYBRuleFile([@"var/mobile/Library/MYbloXX/" stringByAppendingString:name]);}
static void welcomeClose(void){
 UIWindow *window=welcomeWindow;if(!window)return;
 [UIView animateWithDuration:.28 animations:^{window.alpha=0;} completion:^(BOOL done){(void)done;window.hidden=YES;if(welcomeWindow==window)welcomeWindow=nil;}];
}
// The open goes to LaunchServices, which then asks SpringBoard (this process) to launch the app. Calling it from SpringBoard’s main thread makes the
// main thread wait on a reply that only the main thread can give, so the Home Screen froze until the request timed out. It runs on its own queue instead.
static void welcomeOpen(NSString *url){
 NSURL *target=[NSURL URLWithString:url];if(!target)return;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  id workspace=nil;Class cls=NSClassFromString(@"LSApplicationWorkspace");SEL dflt=NSSelectorFromString(@"defaultWorkspace");
  if([cls respondsToSelector:dflt])workspace=((id(*)(id,SEL))objc_msgSend)(cls,dflt);
  SEL sensitive=NSSelectorFromString(@"openSensitiveURL:withOptions:");
  if([workspace respondsToSelector:sensitive])((BOOL(*)(id,SEL,id,id))objc_msgSend)(workspace,sensitive,target,nil);
  else dispatch_async(dispatch_get_main_queue(),^{[UIApplication.sharedApplication openURL:target options:@{} completionHandler:nil];});
 });
}
// ---- The tour -------------------------------------------------------------------------------------------------------------------------------
// One visual idea and one short message per page. The opening is the shield drawing itself, turning into the MYbloXX® mark with a light sweep, and
// the card rising out of the light. Each page then shows a small contained demonstration (a blocked ad, stopped pop-ups, an app that has to ask)
// that plays inside the card and nowhere else. Everything can be interrupted: a tap during the opening jumps to the first page, Skip is always
// there, and a swipe turns the page. Reduce Motion shows each demonstration as its finished picture.
typedef NS_ENUM(NSInteger,MYBTourPage){MYBTourWelcome=0,MYBTourBlocked,MYBTourPopups,MYBTourApps,MYBTourRecommended,MYBTourDone,MYBTourPageCount};
@interface MYBWelcomeController:UIViewController
@property(nonatomic,strong) UIView *card,*logoGroup,*slot,*badge;
@property(nonatomic,strong) UIImageView *glyph;
@property(nonatomic,strong) NSLayoutConstraint *textMin;
@property(nonatomic,assign) CGFloat measuredWidth;
@property(nonatomic,copy) NSString *measuredSize;
@property(nonatomic,strong) UIImageView *logo;
@property(nonatomic,strong) CAShapeLayer *shield,*check,*ring;
@property(nonatomic,strong) UILabel *wordmark,*heading,*detail;
@property(nonatomic,strong) UIButton *primary,*secondary;
@property(nonatomic,strong) UIPageControl *dots;
@property(nonatomic,strong) CAGradientLayer *glowA,*glowB;
@property(nonatomic,assign) BOOL profileInstalled,introDone,introSkipped,opening;
@property(nonatomic,assign) NSInteger page,swapGen,pulseGen;
@property(nonatomic,strong) UIColor *tone;
@property(nonatomic,strong) NSLayoutConstraint *cardY;
@end
@implementation MYBWelcomeController
static UIColor *wc(CGFloat r,CGFloat g,CGFloat b,CGFloat a){return [UIColor colorWithRed:r green:g blue:b alpha:a];}
static UIBezierPath *welcomeShieldPath(CGFloat s){ // a shield outline in a square of side s
 UIBezierPath *p=[UIBezierPath bezierPath];
 [p moveToPoint:CGPointMake(.5*s,.04*s)];
 [p addLineToPoint:CGPointMake(.9*s,.18*s)];
 [p addLineToPoint:CGPointMake(.9*s,.5*s)];
 [p addCurveToPoint:CGPointMake(.5*s,.96*s) controlPoint1:CGPointMake(.9*s,.74*s) controlPoint2:CGPointMake(.7*s,.88*s)];
 [p addCurveToPoint:CGPointMake(.1*s,.5*s) controlPoint1:CGPointMake(.3*s,.88*s) controlPoint2:CGPointMake(.1*s,.74*s)];
 [p addLineToPoint:CGPointMake(.1*s,.18*s)];[p closePath];return p;
}
static BOOL tourCalm(void){return UIAccessibilityIsReduceMotionEnabled();}
static BOOL tourBigText(void){return UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory);}
static UIFont *tourFont(UIFontTextStyle style,CGFloat size,UIFontWeight weight){return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight] maximumPointSize:size*2.2];}
- (UIButton *)buttonTitle:(NSString *)title filled:(BOOL)filled action:(SEL)action{
 UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];[b setTitle:title forState:UIControlStateNormal];b.titleLabel.font=tourFont(UIFontTextStyleHeadline,filled?16:15,UIFontWeightSemibold);b.titleLabel.adjustsFontForContentSizeCategory=YES;b.titleLabel.numberOfLines=0;b.titleLabel.textAlignment=NSTextAlignmentCenter;
 b.layer.cornerRadius=14;b.layer.cornerCurve=kCACornerCurveContinuous;b.translatesAutoresizingMaskIntoConstraints=NO;
 [b setTitleColor:filled?UIColor.blackColor:wc(.78,.80,.98,1) forState:UIControlStateNormal];b.backgroundColor=filled?wc(.66,.60,1,1):UIColor.clearColor;
 [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
 [b addTarget:self action:@selector(pressDown:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];
 [b addTarget:self action:@selector(pressUp:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];
 [b.heightAnchor constraintGreaterThanOrEqualToConstant:filled?48:44].active=YES;return b;
}
- (void)pressDown:(UIButton *)b{if(tourCalm())return;[UIView animateWithDuration:.12 animations:^{b.transform=CGAffineTransformMakeScale(.96,.96);}];}
- (void)pressUp:(UIButton *)b{if(tourCalm()){b.transform=CGAffineTransformIdentity;return;}[UIView animateWithDuration:.3 delay:0 usingSpringWithDamping:.6 initialSpringVelocity:.8 options:0 animations:^{b.transform=CGAffineTransformIdentity;} completion:nil];}
// The pages. Words are short on purpose: one message each.
- (NSArray<NSDictionary *> *)tour{
 return @[
  @{@"s":@"hand.wave.fill",@"c":wc(.58,.52,1,1),@"h":@"Welcome",@"t":@"You are protected now. Take a 30 second tour?"},
  @{@"s":@"xmark.shield.fill",@"c":wc(.40,.72,1,1),@"h":@"Sites get blocked first",@"t":@"Ads and trackers are stopped before they load."},
  @{@"s":@"macwindow.on.rectangle",@"c":wc(1,.45,.55,1),@"h":@"Pop-ups stay closed",@"t":@"New windows wait until you allow the site."},
  @{@"s":@"arrow.triangle.branch",@"c":wc(.74,.58,1,1),@"h":@"Apps have to ask",@"t":@"A link that opens the App Store or another app waits for your OK."},
  @{@"s":@"star.fill",@"c":wc(1,.76,.30,1),@"h":@"Recommended",@"t":@"MYXXdev™ suggests blockAdSense. It also blocks graph.facebook.com, which can stop Facebook and Messenger sign-in. Your choice."},
  @{@"s":@"checkmark.seal.fill",@"c":wc(.40,.86,.62,1),@"h":@"You are set",@"t":@"Check protection or fix problems any time in Help & Repair."}];
}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.view.backgroundColor=wc(.012,.010,.030,.94);
 // Light and depth: two soft radial glows behind everything; they fade in once and then stay still.
 CAGradientLayer *(^glow)(CGFloat,CGFloat,CGFloat,CGFloat)=^CAGradientLayer *(CGFloat r,CGFloat g,CGFloat b,CGFloat a){CAGradientLayer *l=[CAGradientLayer layer];l.type=kCAGradientLayerRadial;l.colors=@[(id)wc(r,g,b,a).CGColor,(id)wc(r,g,b,0).CGColor];l.startPoint=CGPointMake(.5,.5);l.endPoint=CGPointMake(1,1);return l;};
 self.glowA=glow(.45,.38,1,.36);self.glowB=glow(.20,.34,1,.20);self.glowA.opacity=0;self.glowB.opacity=0;
 [self.view.layer addSublayer:self.glowB];[self.view.layer addSublayer:self.glowA];
 // The card: compact, dark, opaque, as in the older tour.
 UIView *card=[UIView new];card.backgroundColor=wc(.07,.07,.13,1);card.layer.cornerRadius=26;card.layer.cornerCurve=kCACornerCurveContinuous;card.layer.borderWidth=.8;card.layer.borderColor=wc(.55,.50,1,.30).CGColor;
 card.layer.shadowColor=wc(.45,.40,1,1).CGColor;card.layer.shadowOpacity=.4;card.layer.shadowRadius=30;card.layer.shadowOffset=CGSizeMake(0,10);
 card.translatesAutoresizingMaskIntoConstraints=NO;card.alpha=0;[self.view addSubview:card];self.card=card;
 // One picture slot of a fixed size: a round badge with the page's symbol. Its one-shot flourish plays inside this slot and nowhere else.
 UIView *host=[UIView new];host.translatesAutoresizingMaskIntoConstraints=NO;self.slot=host;
 UIView *badge=[UIView new];badge.frame=CGRectMake(0,0,60,60);badge.layer.cornerRadius=19;badge.layer.cornerCurve=kCACornerCurveContinuous;badge.layer.borderWidth=1;badge.isAccessibilityElement=NO;[host addSubview:badge];self.badge=badge;
 UIImageView *glyph=[[UIImageView alloc] initWithFrame:CGRectMake(13,13,34,34)];glyph.contentMode=UIViewContentModeScaleAspectFit;glyph.isAccessibilityElement=NO;[badge addSubview:glyph];self.glyph=glyph;
 UILabel *heading=[UILabel new];heading.font=tourFont(UIFontTextStyleTitle2,21,UIFontWeightBold);heading.adjustsFontForContentSizeCategory=YES;heading.textColor=UIColor.whiteColor;heading.textAlignment=NSTextAlignmentCenter;heading.numberOfLines=0;heading.accessibilityTraits|=UIAccessibilityTraitHeader;self.heading=heading;
 UILabel *detail=[UILabel new];detail.font=tourFont(UIFontTextStyleBody,15,UIFontWeightRegular);detail.adjustsFontForContentSizeCategory=YES;detail.textColor=wc(.76,.78,.90,1);detail.textAlignment=NSTextAlignmentCenter;detail.numberOfLines=0;self.detail=detail;
 UIPageControl *dots=[UIPageControl new];dots.numberOfPages=MYBTourPageCount;dots.userInteractionEnabled=NO;dots.pageIndicatorTintColor=wc(1,1,1,.2);dots.currentPageIndicatorTintColor=wc(.74,.70,1,1);self.dots=dots;
 self.primary=[self buttonTitle:@"" filled:YES action:@selector(primaryTapped)];self.secondary=[self buttonTitle:@"" filled:NO action:@selector(secondaryTapped)];
 UIStackView *textBlock=[[UIStackView alloc] initWithArrangedSubviews:@[heading,detail]];textBlock.axis=UILayoutConstraintAxisVertical;textBlock.spacing=6;textBlock.alignment=UIStackViewAlignmentFill;self.textMin=[textBlock.heightAnchor constraintGreaterThanOrEqualToConstant:60];self.textMin.active=YES;
 UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[host,textBlock,dots,self.primary,self.secondary]];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=10;[stack setCustomSpacing:12 afterView:host];[stack setCustomSpacing:2 afterView:textBlock];[stack setCustomSpacing:14 afterView:dots];
 stack.translatesAutoresizingMaskIntoConstraints=NO;[card addSubview:stack];
 // The logo group sits above the card; during the opening it is in the middle of the screen and large.
 UIView *group=[UIView new];group.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:group];self.logoGroup=group;
 NSString *path=jbroot(@"/Library/PreferenceBundles/MYbloXXDiagnostics.bundle/MYBIcon.png");UIImage *icon=[UIImage imageWithContentsOfFile:path];
 UIImageView *logo=[[UIImageView alloc] initWithImage:icon];logo.contentMode=UIViewContentModeScaleAspectFill;logo.layer.cornerRadius=26;logo.layer.cornerCurve=kCACornerCurveContinuous;logo.clipsToBounds=YES;logo.layer.borderWidth=.8;logo.layer.borderColor=wc(.62,.56,1,.5).CGColor;logo.translatesAutoresizingMaskIntoConstraints=NO;logo.alpha=0;[group addSubview:logo];self.logo=logo;
 UILabel *word=[UILabel new];word.text=@"MYbloXX®";word.font=[UIFont systemFontOfSize:22 weight:UIFontWeightBold];word.textColor=UIColor.whiteColor;word.translatesAutoresizingMaskIntoConstraints=NO;word.alpha=0;[group addSubview:word];self.wordmark=word;
 [NSLayoutConstraint activateConstraints:@[
  [card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],(self.cardY=[card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:88]),
  [card.widthAnchor constraintLessThanOrEqualToConstant:340],[card.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],[card.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20],
  [card.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:56],[card.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
  [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],[stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],[stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],[stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
  [host.heightAnchor constraintEqualToConstant:84],
  [group.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[group.bottomAnchor constraintEqualToAnchor:card.topAnchor constant:-22],[group.widthAnchor constraintEqualToConstant:112],[group.heightAnchor constraintEqualToConstant:150],
  [logo.topAnchor constraintEqualToAnchor:group.topAnchor],[logo.centerXAnchor constraintEqualToAnchor:group.centerXAnchor],[logo.widthAnchor constraintEqualToConstant:104],[logo.heightAnchor constraintEqualToConstant:104],
  [word.centerXAnchor constraintEqualToAnchor:group.centerXAnchor],[word.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:12]]];
 // The shield that is drawn first, a check, and a ring that bursts when the shield becomes the logo.
 CAShapeLayer *ring=[CAShapeLayer layer];ring.fillColor=nil;ring.strokeColor=wc(.70,.66,1,1).CGColor;ring.lineWidth=2;ring.opacity=0;self.ring=ring;
 CAShapeLayer *shield=[CAShapeLayer layer];shield.fillColor=wc(.58,.52,1,0).CGColor;shield.strokeColor=wc(.80,.76,1,1).CGColor;shield.lineWidth=5;shield.lineCap=kCALineCapRound;shield.lineJoin=kCALineJoinRound;shield.strokeEnd=0;shield.shadowColor=wc(.58,.52,1,1).CGColor;shield.shadowOpacity=.9;shield.shadowRadius=14;shield.shadowOffset=CGSizeZero;self.shield=shield;
 CAShapeLayer *check=[CAShapeLayer layer];check.fillColor=nil;check.strokeColor=UIColor.whiteColor.CGColor;check.lineWidth=6;check.lineCap=kCALineCapRound;check.lineJoin=kCALineJoinRound;check.strokeEnd=0;self.check=check;
 [group.layer addSublayer:ring];[group.layer addSublayer:shield];[group.layer addSublayer:check];
 // Gestures: a tap during the opening jumps ahead; a swipe turns the page.
 UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped)];tap.cancelsTouchesInView=NO;[self.view addGestureRecognizer:tap];
 for(NSNumber *d in @[@(UISwipeGestureRecognizerDirectionLeft),@(UISwipeGestureRecognizerDirectionRight)]){UISwipeGestureRecognizer *swipe=[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swiped:)];swipe.direction=(UISwipeGestureRecognizerDirection)d.integerValue;[self.view addGestureRecognizer:swipe];}
 // VoiceOver: the card is one modal group, the logo has a name, drawing is hidden.
 self.view.accessibilityViewIsModal=YES;logo.isAccessibilityElement=YES;logo.accessibilityLabel=@"MYbloXX";logo.accessibilityTraits=UIAccessibilityTraitImage;
 [self showPage];
}
- (void)viewDidLayoutSubviews{
 [super viewDidLayoutSubviews];
 CGFloat S=104;CGRect box=CGRectMake(4,0,S,S);
 for(CAShapeLayer *l in @[self.shield,self.check,self.ring]){l.frame=box;}
 self.glowA.frame=CGRectInset(self.view.bounds,-80,-80);self.glowB.frame=CGRectOffset(CGRectInset(self.view.bounds,-120,-120),60,120);
 self.shield.path=welcomeShieldPath(S).CGPath;
 UIBezierPath *cp=[UIBezierPath bezierPath];[cp moveToPoint:CGPointMake(.33*S,.5*S)];[cp addLineToPoint:CGPointMake(.45*S,.63*S)];[cp addLineToPoint:CGPointMake(.69*S,.36*S)];self.check.path=cp.CGPath;
 self.ring.path=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(-6,-6,S+12,S+12) cornerRadius:34].CGPath;
 self.badge.center=CGPointMake(self.slot.bounds.size.width/2,self.slot.bounds.size.height/2);
 // The card keeps one size on every page: the text area is as tall as the longest page needs, measured once per width and text size.
 NSString *size=UIApplication.sharedApplication.preferredContentSizeCategory;CGFloat w=self.card.bounds.size.width;
 if(w>0&&(fabs(w-self.measuredWidth)>.5||![size isEqual:self.measuredSize])){
  self.measuredWidth=w;self.measuredSize=size;
  UIView *block=self.heading.superview;CGFloat tallest=60;NSInteger saveHeading=0;(void)saveHeading;
  for(NSInteger i=0;i<=MYBTourDone+1;i++){
   BOOL warn=(i==MYBTourDone+1);[self applyWordsForPage:warn?MYBTourWelcome:i warn:warn];
   CGFloat h=[block systemLayoutSizeFittingSize:CGSizeMake(w-40,UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
   if(h>tallest)tallest=h;
  }
  [self applyWordsForPage:self.page warn:self.profileInstalled&&self.page==MYBTourWelcome];
  if(fabs(self.textMin.constant-tallest)>.5){self.textMin.constant=tallest;[self.view setNeedsLayout];}
 }
 // The mark and the card are centred on the screen as one block (mark 150 + gap 26 + card). When that block does not fit, or at the largest text
 // sizes, the mark gives way and the card alone is centred.
 CGFloat room=self.view.bounds.size.height-self.view.safeAreaInsets.top-self.view.safeAreaInsets.bottom-16;
 BOOL tight=tourBigText()||self.card.bounds.size.height+176>room;
 CGFloat y=tight?0:88+(self.view.safeAreaInsets.top-self.view.safeAreaInsets.bottom)/2;
 if(fabs(self.cardY.constant-y)>.5){self.cardY.constant=y;[self.view setNeedsLayout];}
 if(self.introDone)self.logoGroup.alpha=tight?0:1;
}
// ---- Words and colours for the current page ---------------------------------------------------------------------------------------------
// Words only. Used by showPage and by the one-time measuring that keeps the card the same size on every page.
- (void)applyWordsForPage:(NSInteger)page warn:(BOOL)warn{
 NSDictionary *p=self.tour[(NSUInteger)page];NSInteger last=(NSInteger)self.tour.count-1;
 if(warn){
  self.heading.text=@"One thing to fix first";
  self.detail.text=@"A MYbloXX® profile is installed on this iPhone, so MYbloXX® cannot protect you the normal way. Tap below and it is removed and native protection turns on. Your settings stay.";
  [self.primary setTitle:@"Fix It in Settings" forState:UIControlStateNormal];[self.secondary setTitle:@"Show Me Around First" forState:UIControlStateNormal];
 }else{
  self.heading.text=p[@"h"];self.detail.text=p[@"t"];BOOL end=page==last;
  [self.primary setTitle:end?@"Open MYbloXX® Settings":(page==MYBTourWelcome?@"Show Me":@"Next") forState:UIControlStateNormal];
  [self.secondary setTitle:end?@"Done":@"Skip" forState:UIControlStateNormal];
 }
}
- (void)showPage{
 BOOL warn=self.profileInstalled&&self.page==MYBTourWelcome;NSArray *tour=self.tour;
 NSDictionary *p=tour[(NSUInteger)self.page];
 self.dots.currentPage=self.page;self.dots.accessibilityLabel=[NSString stringWithFormat:@"Page %ld of %lu",(long)self.page+1,(unsigned long)tour.count];
 if(self.page==MYBTourRecommended)[@"1" writeToFile:welcomeFile(@"TourSawRecommendation") atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 [self applyWordsForPage:self.page warn:warn];
 UIColor *tone=warn?wc(1,.72,.30,1):p[@"c"];self.tone=tone;
 self.slot.hidden=tourBigText();
 self.badge.backgroundColor=[tone colorWithAlphaComponent:.16];self.badge.layer.borderColor=[tone colorWithAlphaComponent:.45].CGColor;
 self.glyph.image=[[UIImage systemImageNamed:warn?@"exclamationmark.triangle.fill":(p[@"s"]?:@"shield.fill")] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];self.glyph.tintColor=tone;
 [self tintLight:tone];
 [self.view setNeedsLayout];
}
// The light behind the card takes the colour of the page, softly.
- (void)tintLight:(UIColor *)tone{
 CGFloat r=0,g=0,b=0,a=0;[tone getRed:&r green:&g blue:&b alpha:&a];
 NSArray *to=@[(id)wc(r*.8+.1,g*.8+.1,b*.8+.1,.34).CGColor,(id)wc(r*.8+.1,g*.8+.1,b*.8+.1,0).CGColor];
 if(!tourCalm()&&self.introDone){CABasicAnimation *c=[CABasicAnimation animationWithKeyPath:@"colors"];c.fromValue=self.glowA.presentationLayer?((CAGradientLayer *)self.glowA.presentationLayer).colors:self.glowA.colors;c.toValue=to;c.duration=.6;[self.glowA addAnimation:c forKey:@"tint"];}
 self.glowA.colors=to;
}
// One flourish for the page's badge, played once: the badge springs in, a ring and a few sparks leave it, the symbol does its small move.
- (void)playBadge{
 self.pulseGen++;
 for(CALayer *l in [self.slot.layer.sublayers copy])if([l.name isEqual:@"flourish"])[l removeFromSuperlayer];
 [self.badge.layer removeAllAnimations];[self.glyph.layer removeAllAnimations];self.badge.transform=CGAffineTransformIdentity;self.glyph.transform=CGAffineTransformIdentity;
 if(tourCalm()||self.slot.hidden)return;
 CGPoint c=self.badge.center;UIColor *tone=self.tone?:wc(.7,.64,1,1);
 CAShapeLayer *ring=[CAShapeLayer layer];ring.name=@"flourish";ring.bounds=CGRectMake(0,0,60,60);ring.position=c;ring.path=[UIBezierPath bezierPathWithRoundedRect:ring.bounds cornerRadius:19].CGPath;ring.fillColor=nil;ring.strokeColor=[tone colorWithAlphaComponent:.85].CGColor;ring.lineWidth=2;ring.opacity=0;[self.slot.layer insertSublayer:ring below:self.badge.layer];
 CABasicAnimation *grow=[CABasicAnimation animationWithKeyPath:@"transform.scale"];grow.fromValue=@1;grow.toValue=@1.4;
 CABasicAnimation *fade=[CABasicAnimation animationWithKeyPath:@"opacity"];fade.fromValue=@.85;fade.toValue=@0;
 CAAnimationGroup *g=[CAAnimationGroup animation];g.animations=@[grow,fade];g.duration=.75;g.beginTime=CACurrentMediaTime()+.12;g.fillMode=kCAFillModeBackwards;g.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];[ring addAnimation:g forKey:@"pulse"];
 for(int i=0;i<8;i++){
  CGFloat ang=i*M_PI/4+M_PI/8;CALayer *spark=[CALayer layer];spark.name=@"flourish";spark.bounds=CGRectMake(0,0,5,5);spark.cornerRadius=2.5;spark.backgroundColor=tone.CGColor;spark.position=c;spark.opacity=0;[self.slot.layer insertSublayer:spark below:self.badge.layer];
  CABasicAnimation *move=[CABasicAnimation animationWithKeyPath:@"position"];move.fromValue=[NSValue valueWithCGPoint:CGPointMake(c.x+cos(ang)*26,c.y+sin(ang)*26)];move.toValue=[NSValue valueWithCGPoint:CGPointMake(c.x+cos(ang)*40,c.y+sin(ang)*40)];
  CABasicAnimation *f=[CABasicAnimation animationWithKeyPath:@"opacity"];f.fromValue=@1;f.toValue=@0;
  CAAnimationGroup *sg=[CAAnimationGroup animation];sg.animations=@[move,f];sg.duration=.6;sg.beginTime=CACurrentMediaTime()+.14;sg.fillMode=kCAFillModeBackwards;sg.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];[spark addAnimation:sg forKey:@"spark"];
 }
 self.badge.transform=CGAffineTransformMakeScale(.55,.55);
 [UIView animateWithDuration:.7 delay:0 usingSpringWithDamping:.58 initialSpringVelocity:.9 options:UIViewAnimationOptionAllowUserInteraction animations:^{self.badge.transform=CGAffineTransformIdentity;} completion:nil];
 CAKeyframeAnimation *move=nil;
 if(self.page==MYBTourWelcome){move=[CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];move.values=@[@0,@(.38),@(-.28),@(.2),@(-.1),@0];move.keyTimes=@[@0,@.2,@.45,@.65,@.82,@1];move.duration=.9;move.beginTime=CACurrentMediaTime()+.25;move.fillMode=kCAFillModeBackwards;}
 else{move=[CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];move.values=@[@1,@1.22,@1];move.keyTimes=@[@0,@.4,@1];move.duration=.5;move.beginTime=CACurrentMediaTime()+.3;move.fillMode=kCAFillModeBackwards;move.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];}
 [self.glyph.layer addAnimation:move forKey:@"move"];
}
// ---- Opening ----------------------------------------------------------------------------------------------------------------------------
// The final layout, immediately. Used by Reduce Motion and by a tap during the opening.
- (void)settleIntro{
 self.introSkipped=YES;self.introDone=YES;
 [self.shield removeAllAnimations];[self.check removeAllAnimations];[self.ring removeAllAnimations];[self.logo.layer removeAllAnimations];[self.logoGroup.layer removeAllAnimations];[self.card.layer removeAllAnimations];
 for(CALayer *l in @[self.shield,self.check,self.ring])l.opacity=0;
 [UIView animateWithDuration:tourCalm()?0:.25 animations:^{
  self.logoGroup.transform=CGAffineTransformIdentity;self.card.transform=CGAffineTransformIdentity;self.card.alpha=1;self.logo.alpha=1;self.logo.transform=CGAffineTransformIdentity;self.wordmark.alpha=1;self.wordmark.transform=CGAffineTransformIdentity;
  self.glowA.opacity=1;self.glowB.opacity=1;
 }];
 for(UIView *v in self.card.subviews)v.alpha=1;
 [self playBadge];
 UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,self.heading);
}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];
 [self.view layoutIfNeeded];
 __weak typeof(self) weak=self;
 // Is a MYbloXX profile really installed? Asked in the background; if iOS does not say, nothing is claimed and the tour simply continues.
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSDictionary *seen=MYBInstalledMYbloXXProfileSync();BOOL yes=[seen[@"known"] boolValue]&&[seen[@"installed"] boolValue];
  dispatch_async(dispatch_get_main_queue(),^{typeof(self) me=weak;if(!me||!yes)return;me.profileInstalled=YES;if(me.page==MYBTourWelcome)[me swapPage:0];});
 });
 if(tourCalm()){[self settleIntro];return;}
 // The sequence: 1) light comes up and the shield draws itself, 2) it fills and gets a check, 3) it turns into the MYbloXX logo with a ring burst
 // and a sweep of light, 4) the name appears, 5) the logo settles above the glass card and the first page appears. Nothing loops except the glow.
 CGFloat dy=CGRectGetMidY(self.view.bounds)-self.logoGroup.center.y-10;
 self.logoGroup.transform=CGAffineTransformMakeTranslation(0,dy);self.card.transform=CGAffineTransformMakeTranslation(0,70);
 for(UIView *v in self.card.subviews)v.alpha=0;
 CABasicAnimation *lightIn=[CABasicAnimation animationWithKeyPath:@"opacity"];lightIn.fromValue=@0;lightIn.toValue=@1;lightIn.duration=1.2;self.glowA.opacity=1;self.glowB.opacity=1;[self.glowA addAnimation:lightIn forKey:@"in"];[self.glowB addAnimation:lightIn forKey:@"in"];
 CABasicAnimation *draw=[CABasicAnimation animationWithKeyPath:@"strokeEnd"];draw.fromValue=@0;draw.toValue=@1;draw.duration=.8;draw.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];draw.fillMode=kCAFillModeForwards;draw.removedOnCompletion=NO;
 [self.shield addAnimation:draw forKey:@"draw"];self.shield.strokeEnd=1;
 CABasicAnimation *tick=[CABasicAnimation animationWithKeyPath:@"strokeEnd"];tick.fromValue=@0;tick.toValue=@1;tick.duration=.35;tick.beginTime=CACurrentMediaTime()+.8;tick.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];tick.fillMode=kCAFillModeBoth;tick.removedOnCompletion=NO;
 [self.check addAnimation:tick forKey:@"tick"];self.check.strokeEnd=1;
 CABasicAnimation *fill=[CABasicAnimation animationWithKeyPath:@"fillColor"];fill.fromValue=(id)wc(.58,.52,1,0).CGColor;fill.toValue=(id)wc(.58,.52,1,.35).CGColor;fill.duration=.35;fill.beginTime=CACurrentMediaTime()+.75;fill.fillMode=kCAFillModeBoth;fill.removedOnCompletion=NO;
 [self.shield addAnimation:fill forKey:@"fill"];
 // Step 3: the shield becomes the logo.
 [self introAfter:1.25 block:^{
  typeof(self) me=weak;
  [[UIImpactFeedbackGenerator new] impactOccurred];
  CABasicAnimation *burst=[CABasicAnimation animationWithKeyPath:@"transform.scale"];burst.fromValue=@1;burst.toValue=@1.9;burst.duration=.7;
  CABasicAnimation *fade=[CABasicAnimation animationWithKeyPath:@"opacity"];fade.fromValue=@.9;fade.toValue=@0;fade.duration=.7;
  CAAnimationGroup *g=[CAAnimationGroup animation];g.animations=@[burst,fade];g.duration=.7;g.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];[me.ring addAnimation:g forKey:@"burst"];
  [UIView animateWithDuration:.3 animations:^{for(CALayer *l in @[me.shield,me.check]){l.opacity=0;}}];
  me.logo.transform=CGAffineTransformMakeScale(.45,.45);
  [UIView animateWithDuration:.8 delay:.08 usingSpringWithDamping:.55 initialSpringVelocity:.9 options:0 animations:^{me.logo.alpha=1;me.logo.transform=CGAffineTransformIdentity;} completion:nil];
  // A band of light crosses the mark once.
  CAGradientLayer *sheen=[CAGradientLayer layer];sheen.frame=me.logo.bounds;sheen.colors=@[(id)wc(1,1,1,0).CGColor,(id)wc(1,1,1,.55).CGColor,(id)wc(1,1,1,0).CGColor];sheen.startPoint=CGPointMake(0,.4);sheen.endPoint=CGPointMake(1,.6);sheen.locations=@[@0,@.5,@1];
  [me.logo.layer addSublayer:sheen];CABasicAnimation *sweep=[CABasicAnimation animationWithKeyPath:@"transform.translation.x"];sweep.fromValue=@(-120);sweep.toValue=@(120);sweep.duration=.7;sweep.beginTime=CACurrentMediaTime()+.35;sweep.fillMode=kCAFillModeBackwards;[sheen addAnimation:sweep forKey:@"sweep"];
  [me introAfter:1.2 block:^{[sheen removeFromSuperlayer];}];
  me.wordmark.transform=CGAffineTransformMakeTranslation(0,12);
  [UIView animateWithDuration:.5 delay:.4 usingSpringWithDamping:.8 initialSpringVelocity:.2 options:0 animations:^{me.wordmark.alpha=1;me.wordmark.transform=CGAffineTransformIdentity;} completion:nil];
 }];
 // Step 5: the logo moves up, the card rises out of the light, the first page appears.
 [self introAfter:2.4 block:^{
  typeof(self) me=weak;
  [UIView animateWithDuration:.75 delay:0 usingSpringWithDamping:.82 initialSpringVelocity:.3 options:0 animations:^{me.logoGroup.transform=CGAffineTransformIdentity;me.card.alpha=1;me.card.transform=CGAffineTransformIdentity;} completion:^(BOOL f){(void)f;me.introDone=YES;[me playBadge];}];
  NSUInteger i=0;for(UIView *v in me.card.subviews){
   v.transform=CGAffineTransformMakeTranslation(0,12);
   [UIView animateWithDuration:.5 delay:.3+.06*i usingSpringWithDamping:.85 initialSpringVelocity:.3 options:0 animations:^{v.alpha=1;v.transform=CGAffineTransformIdentity;} completion:nil];i++;}
  UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,me.heading);
 }];
}
// A delayed step of the opening that does nothing if a tap already jumped ahead or the screen is gone.
- (void)introAfter:(NSTimeInterval)delay block:(void(^)(void))block{
 __weak typeof(self) weak=self;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{typeof(self) me=weak;if(!me||me.introSkipped||!me.view.window)return;block();});
}
- (void)viewTapped{if(!self.introDone&&!self.introSkipped)[self settleIntro];}
// ---- Pages ------------------------------------------------------------------------------------------------------------------------------
// Moves to another page: the picture and words slide out one way and in from the other, so the pages feel like one continuous scene.
- (void)swapPage:(NSInteger)direction{
 if(tourCalm()||!self.introDone){self.swapGen++;[self showPage];UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification,self.heading);return;}
 NSInteger gen=++self.swapGen;NSArray *moving=@[self.slot,self.heading,self.detail];CGFloat shift=direction>=0?-22:22;
 [UIView animateWithDuration:.14 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseIn animations:^{for(UIView *v in moving){v.alpha=0;v.transform=CGAffineTransformMakeTranslation(shift,0);}} completion:^(BOOL done){(void)done;
  if(gen!=self.swapGen)return; // a newer turn already took over
  [self showPage];[self playBadge];UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification,self.heading);
  for(UIView *v in moving)v.transform=CGAffineTransformMakeTranslation(-shift,0);
  [UIView animateWithDuration:.38 delay:0 usingSpringWithDamping:.9 initialSpringVelocity:.2 options:UIViewAnimationOptionBeginFromCurrentState animations:^{for(UIView *v in moving){v.alpha=1;v.transform=CGAffineTransformIdentity;}} completion:nil];
 }];
}
- (void)goToPage:(NSInteger)page{
 if(page<0||page>=MYBTourPageCount||page==self.page)return;
 NSInteger direction=page>self.page?1:-1;self.page=page;[self swapPage:direction];
}
- (void)swiped:(UISwipeGestureRecognizer *)g{
 if(!self.introDone){[self settleIntro];return;}
 if(self.profileInstalled&&self.page==MYBTourWelcome&&g.direction==UISwipeGestureRecognizerDirectionLeft){[self goToPage:1];return;}
 [self goToPage:self.page+(g.direction==UISwipeGestureRecognizerDirectionLeft?1:-1)];
}
// Opens Settings without looking frozen: the button says so at once, then the welcome fades out while Settings comes up.
- (void)openSettingsFlow:(BOOL)fix{
 if(self.opening)return;self.opening=YES;
 if(fix)[@"1" writeToFile:welcomeFile(@"WelcomeFix") atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 [self.primary setTitle:@"Opening Settings..." forState:UIControlStateNormal];self.primary.enabled=NO;self.secondary.enabled=NO;
 UIActivityIndicatorView *spin=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];spin.color=UIColor.blackColor;spin.translatesAutoresizingMaskIntoConstraints=NO;[self.primary addSubview:spin];
 [NSLayoutConstraint activateConstraints:@[[spin.centerYAnchor constraintEqualToAnchor:self.primary.centerYAnchor],[spin.leadingAnchor constraintEqualToAnchor:self.primary.leadingAnchor constant:18]]];[spin startAnimating];
 welcomeOpen(@"prefs:root=MYbloXX%C2%AE");
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{welcomeClose();});
}
- (void)primaryTapped{
 if(!self.introDone){[self settleIntro];return;}
 if(self.profileInstalled&&self.page==MYBTourWelcome){[self openSettingsFlow:YES];return;}
 if(self.page>=MYBTourPageCount-1){[self openSettingsFlow:NO];return;}
 [[UISelectionFeedbackGenerator new] selectionChanged];[self goToPage:self.page+1];
}
- (void)secondaryTapped{
 if(self.profileInstalled&&self.page==MYBTourWelcome){[self goToPage:1];return;}
 welcomeClose();
}
- (void)secondaryClose{welcomeClose();}
@end
// Shown at most once per install: the marker is removed before anything is presented.
static void welcomeShowNow(void){
 if(welcomeWindow)return;
 NSString *marker=welcomeMarker();if(![NSFileManager.defaultManager fileExistsAtPath:marker])return;
 // Shown once per install: the marker names the install, and SpringBoard remembers which one it has already shown, so a marker it is not allowed to delete cannot bring the screen back.
 NSString *label=[NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:NULL]?:@"";
 NSString *shown=[NSUserDefaults.standardUserDefaults stringForKey:@"MYBWelcomeShown"];
 [NSFileManager.defaultManager removeItemAtPath:marker error:NULL];
 if([shown isEqual:label])return;
 [NSUserDefaults.standardUserDefaults setObject:label forKey:@"MYBWelcomeShown"];[NSUserDefaults.standardUserDefaults synchronize];
 UIWindowScene *scene=nil;for(UIScene *c in UIApplication.sharedApplication.connectedScenes){if([c isKindOfClass:UIWindowScene.class]){scene=(UIWindowScene *)c;if(c.activationState==UISceneActivationStateForegroundActive)break;}}
 UIWindow *window=scene?[[UIWindow alloc] initWithWindowScene:scene]:[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];if(!window)return;
 MYBWelcomeController *controller=[MYBWelcomeController new];[controller loadViewIfNeeded]; // built before the window shows, so a cold start does not stutter
 window.windowLevel=UIWindowLevelAlert+2;window.rootViewController=controller;window.hidden=NO;[window makeKeyAndVisible];welcomeWindow=window;
}
// Replay from Help & Repair: Settings writes a fresh WelcomePending marker (its text is new every time, so the once-per-install guard lets it through) and posts this
// notification; SpringBoard shows the tour straight away because the person is using the phone. Nothing here runs without that marker.
static void welcomeReplayArrived(CFNotificationCenterRef c,void *o,CFNotificationName n,const void *obj,CFDictionaryRef u){
 (void)c;(void)o;(void)n;(void)obj;(void)u;
 dispatch_async(dispatch_get_main_queue(),^{welcomeShowNow();});
}
static void welcomeObserveReplay(void){
 CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,welcomeReplayArrived,CFSTR("net.myxxdev.mybloxx.welcome.replay"),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
}
// Waits for an unlocked Home Screen; stops by itself as soon as the marker is gone.
static void welcomeStart(void(^unlocked)(BOOL *ready)){
 if(![NSFileManager.defaultManager fileExistsAtPath:welcomeMarker()])return;
 [NSTimer scheduledTimerWithTimeInterval:4 repeats:YES block:^(NSTimer *t){
  if(![NSFileManager.defaultManager fileExistsAtPath:welcomeMarker()]){[t invalidate];return;}
  BOOL ready=NO;unlocked(&ready);if(ready){[t invalidate];welcomeShowNow();}
 }];
}
