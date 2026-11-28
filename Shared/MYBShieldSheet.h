#pragma once
// Branded UIKit sheet for Shield permission prompts (popup options in browsers, App Store / app-redirect prompts in
// SpringBoard). A real view controller, not a UIAlertController, so it carries the MYbloXX identity, the glass material,
// and the same accessibility behaviour on every surface. Permission semantics are the caller's: this file decides how a
// choice LOOKS and is announced, never what it grants. Each action's handler runs exactly once; the sheet never grants
// anything by itself, and a sheet that fails to appear reports that to the caller (see +present:...).
//
//  * Reduce Transparency / Darker System Colors: opaque panel, no blur.     * Reduce Motion: no animation at all.
//  * Dynamic Type to the largest accessibility sizes: the card scrolls instead of clipping.
//  * Rotation / iPad widths: the card is at most 520 pt wide, centred, inside the safe area.
//  * VoiceOver: the sheet is modal, announces its title, and every action is a >= 44 pt labelled button.
//  * Stacked prompts: callers present only when nothing else is presented; a sheet never replaces another.
#import <UIKit/UIKit.h>
#import "MYBShieldTheme.h"
#import "MYBShieldMark.h"
#ifndef MYB_SHEET_CLASS
#define MYB_SHEET_CLASS MYBShieldSheet
#endif
#ifndef MYB_SHEET_TEST
#define MYB_SHEET_TEST 0
#endif

typedef NS_ENUM(NSInteger,MYBShieldActionStyle){MYBShieldActionPrimary,MYBShieldActionSecondary,MYBShieldActionCancel,MYBShieldActionDestructive};

@interface MYBShieldAction : NSObject
@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *detail;                 // optional second line, e.g. the scope of the permission
@property(nonatomic) MYBShieldActionStyle style;
@property(nonatomic,copy) void(^handler)(void);             // runs once, when chosen
@property(nonatomic,copy) NSDictionary *(^result)(void);    // optional: runs once, its {title,message,ok} replaces the sheet's content
+ (instancetype)title:(NSString *)title detail:(NSString *)detail style:(MYBShieldActionStyle)style handler:(void(^)(void))handler;
@end
@implementation MYBShieldAction
+ (instancetype)title:(NSString *)title detail:(NSString *)detail style:(MYBShieldActionStyle)style handler:(void(^)(void))handler{MYBShieldAction *a=[self new];a.title=title;a.detail=detail;a.style=style;a.handler=handler;return a;}
@end

static BOOL MYBSheetSolid(void){return UIAccessibilityIsReduceTransparencyEnabled()||UIAccessibilityDarkerSystemColorsEnabled()||(MYB_SHEET_TEST&&getenv("MYB_SHEET_SOLID"));}
static BOOL MYBSheetStill(void){return UIAccessibilityIsReduceMotionEnabled()||(MYB_SHEET_TEST&&getenv("MYB_SHEET_STILL"));}

@interface MYB_SHEET_CLASS : UIViewController
@property(nonatomic,copy) NSString *kicker,*heading,*message;   // kicker: the small brand line, default "MYBLOXX® SHIELD"
@property(nonatomic,copy) NSString *symbol;                      // the status glyph (an SF Symbol), default the Shield hand
@property(nonatomic,strong) UIColor *tone;                       // the glyph colour, default the warning amber
@property(nonatomic) NSTimeInterval autoClose;                   // > 0 with no actions: a confirmation that closes itself, or on any tap
@property(nonatomic,copy) NSArray<NSArray<NSString *> *> *facts;   // [label, value] pairs, shown as rows
@property(nonatomic,copy) NSArray<MYBShieldAction *> *actions;
@property(nonatomic) BOOL dismissOnBackdrop;                      // tapping outside = the Cancel action
@property(nonatomic,copy) void(^onGone)(void);                    // runs once after the sheet has left the screen, by any route
@property(nonatomic,readonly) NSArray<UIButton *> *buttons;
@property(nonatomic,readonly) UIView *card;
@property(nonatomic,readonly) NSUInteger handlerRuns;
@end

@implementation MYB_SHEET_CLASS{
 UIStackView *_content;UILabel *_headingLabel,*_messageLabel;UIView *_card,*_blur,*_tile;UIImageView *_glyph;NSMutableArray<UIButton *> *_buttons;BOOL _fired,_gone,_success;NSUInteger _runs;
}
- (NSArray<UIButton *> *)buttons{return _buttons;}
- (UIView *)card{return _card;}
- (NSUInteger)handlerRuns{return _runs;}
static UILabel *MYBSheetLabel(NSString *text,UIFontTextStyle style,UIFontWeight weight,UIColor *color){
 UILabel *l=[UILabel new];l.numberOfLines=0;l.adjustsFontForContentSizeCategory=YES;l.textColor=color;l.text=text;
 UIFont *base=[UIFont preferredFontForTextStyle:style];l.font=[UIFont systemFontOfSize:base.pointSize weight:weight];return l;
}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.view.backgroundColor=[UIColor colorWithWhite:0 alpha:MYBSheetSolid()?.72:.58];
 UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped:)];[self.view addGestureRecognizer:tap];
 _card=[UIView new];_card.translatesAutoresizingMaskIntoConstraints=NO;_card.layer.cornerRadius=MYBShieldSheetRadius;_card.layer.cornerCurve=kCACornerCurveContinuous;_card.layer.masksToBounds=YES;_card.layer.borderWidth=.5;
 _card.accessibilityViewIsModal=YES;[self.view addSubview:_card];
 [self applyMaterial];
 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.alwaysBounceVertical=NO;scroll.showsVerticalScrollIndicator=NO;[_card addSubview:scroll];
 // Brand row: the identity tile and "MYbloXX® Shield".
 _tile=[UIView new];_tile.translatesAutoresizingMaskIntoConstraints=NO;_tile.layer.cornerRadius=10;_tile.layer.cornerCurve=kCACornerCurveContinuous;_tile.isAccessibilityElement=NO;
 _glyph=[UIImageView new];_glyph.translatesAutoresizingMaskIntoConstraints=NO;_glyph.contentMode=UIViewContentModeScaleAspectFit;_glyph.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];[_tile addSubview:_glyph];
 [NSLayoutConstraint activateConstraints:@[[_tile.widthAnchor constraintEqualToConstant:40],[_tile.heightAnchor constraintEqualToConstant:40],[_glyph.centerXAnchor constraintEqualToAnchor:_tile.centerXAnchor],[_glyph.centerYAnchor constraintEqualToAnchor:_tile.centerYAnchor]]];
 UILabel *brand=MYBSheetLabel(self.kicker.length?self.kicker:@"MYBLOXX® SHIELD",UIFontTextStyleCaption2,UIFontWeightSemibold,MYBShieldAccent());brand.attributedText=[[NSAttributedString alloc] initWithString:brand.text attributes:@{NSKernAttributeName:@1.6,NSFontAttributeName:brand.font,NSForegroundColorAttributeName:MYBShieldAccent()}];
 UILabel *by=MYBSheetLabel(@"MYXXdev™",UIFontTextStyleCaption2,UIFontWeightMedium,MYBShieldMuted());
 UIStackView *words=[[UIStackView alloc] initWithArrangedSubviews:@[brand,by]];words.axis=UILayoutConstraintAxisVertical;words.spacing=2;
 // Identity: the MYbloXX shield, transparent, straight on the dark glass; the status glyph (the
 // security icon for this prompt) sits at the trailing edge.
 UIImageView *logo=[[UIImageView alloc] initWithImage:MYBShieldMarkImage()];logo.translatesAutoresizingMaskIntoConstraints=NO;logo.contentMode=UIViewContentModeScaleAspectFit;logo.isAccessibilityElement=NO;
 [NSLayoutConstraint activateConstraints:@[[logo.widthAnchor constraintEqualToConstant:36],[logo.heightAnchor constraintEqualToConstant:36]]];
 UIView *flex=[UIView new];[flex setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
 UIStackView *brandRow=[[UIStackView alloc] initWithArrangedSubviews:@[logo,words,flex,_tile]];brandRow.axis=UILayoutConstraintAxisHorizontal;brandRow.spacing=12;brandRow.alignment=UIStackViewAlignmentCenter;brandRow.isAccessibilityElement=NO;
 _headingLabel=MYBSheetLabel(nil,UIFontTextStyleTitle2,UIFontWeightBold,UIColor.whiteColor);_messageLabel=MYBSheetLabel(nil,UIFontTextStyleSubheadline,UIFontWeightRegular,MYBShieldMuted());
 _content=[[UIStackView alloc] initWithArrangedSubviews:@[brandRow,_headingLabel,_messageLabel]];_content.axis=UILayoutConstraintAxisVertical;_content.spacing=12;_content.translatesAutoresizingMaskIntoConstraints=NO;[_content setCustomSpacing:16 afterView:brandRow];
 [scroll addSubview:_content];
 NSLayoutConstraint *w=[_card.widthAnchor constraintEqualToConstant:520];w.priority=UILayoutPriorityDefaultHigh;
 [NSLayoutConstraint activateConstraints:@[
  w,[_card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
  [_card.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:14],[_card.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-14],
  [_card.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14],[_card.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14],
  [scroll.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:_card.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor],
  [_content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:22],[_content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-22],
  [_content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:22],[_content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20],
  [_content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-44]]];
 NSLayoutConstraint *fit=[scroll.heightAnchor constraintEqualToAnchor:_content.heightAnchor constant:42];fit.priority=UILayoutPriorityDefaultLow;fit.active=YES; // hug content, then scroll
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applyMaterial) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
 [self rebuild];
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)applyMaterial{
 BOOL solid=MYBSheetSolid();[_blur removeFromSuperview];_blur=nil;
 if(solid){_card.backgroundColor=MYBShieldPanel();_card.layer.borderColor=[UIColor colorWithWhite:1 alpha:.18].CGColor;}
 else{_card.backgroundColor=[UIColor colorWithRed:.13 green:.14 blue:.21 alpha:.30];_card.layer.borderColor=[UIColor colorWithWhite:1 alpha:.17].CGColor;
  UIVisualEffectView *v=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];v.frame=_card.bounds;v.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;v.userInteractionEnabled=NO;[_card insertSubview:v atIndex:0];_blur=v;}
 self.view.backgroundColor=[UIColor colorWithWhite:0 alpha:solid?.72:.58];
}
- (void)styleTile:(UIColor *)tone symbol:(NSString *)symbol{
 _tile.backgroundColor=[tone colorWithAlphaComponent:.14];_glyph.image=[UIImage systemImageNamed:symbol];_glyph.tintColor=tone;
}
- (void)rebuild{
 for(UIView *v in [_content.arrangedSubviews copy])if(v!=_content.arrangedSubviews[0]&&v!=_headingLabel&&v!=_messageLabel){[_content removeArrangedSubview:v];[v removeFromSuperview];}
 _headingLabel.text=self.heading;_messageLabel.text=self.message;_messageLabel.hidden=!self.message.length;_headingLabel.accessibilityTraits=UIAccessibilityTraitHeader;
 [self styleTile:self.tone?:MYBShieldWarning() symbol:self.symbol.length?self.symbol:@"hand.raised.fill"];
 if(self.facts.count){
  // Plain rows on the card itself: no second container, border or fill inside the card.
  UIStackView *rows=[UIStackView new];rows.axis=UILayoutConstraintAxisVertical;rows.spacing=0;
  for(NSArray *f in self.facts){
   UILabel *k=MYBSheetLabel(f[0],UIFontTextStyleFootnote,UIFontWeightRegular,MYBShieldMuted()),*val=MYBSheetLabel(f[1],UIFontTextStyleFootnote,UIFontWeightSemibold,UIColor.whiteColor);val.textAlignment=NSTextAlignmentRight;[k setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
   UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[k,val]];row.axis=UILayoutConstraintAxisHorizontal;row.spacing=12;row.alignment=UIStackViewAlignmentFirstBaseline;row.layoutMargins=UIEdgeInsetsMake(10,0,10,0);row.layoutMarginsRelativeArrangement=YES;row.isAccessibilityElement=YES;row.accessibilityLabel=[NSString stringWithFormat:@"%@, %@",f[0],f[1]];
   UIView *line=[UIView new];line.backgroundColor=MYBShieldHairline();[line.heightAnchor constraintEqualToConstant:1.0/UIScreen.mainScreen.scale].active=YES;[rows addArrangedSubview:line];[rows addArrangedSubview:row];
  }
  [_content addArrangedSubview:rows];
 }
 _buttons=[NSMutableArray array];UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=10;
 for(MYBShieldAction *a in self.actions){UIButton *b=[self buttonFor:a];[stack addArrangedSubview:b];[_buttons addObject:b];}
 [_content addArrangedSubview:stack];[_content setCustomSpacing:18 afterView:stack.superview?stack:_content.arrangedSubviews.lastObject];
 UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,_headingLabel);
}
- (UIButton *)buttonFor:(MYBShieldAction *)action{
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];UIButtonConfiguration *c=[UIButtonConfiguration plainButtonConfiguration];
 BOOL primary=action.style==MYBShieldActionPrimary,destructive=action.style==MYBShieldActionDestructive;UIColor *fg=primary?MYBShieldBackground():destructive?MYBShieldDanger():UIColor.whiteColor;
 c.background.backgroundColor=primary?MYBShieldAccent():destructive?[MYBShieldDanger() colorWithAlphaComponent:.16]:[UIColor colorWithWhite:1 alpha:action.style==MYBShieldActionCancel?.05:.10];c.background.cornerRadius=MYBShieldButtonRadius;
 c.contentInsets=NSDirectionalEdgeInsetsMake(13,16,13,16);c.titleAlignment=UIButtonConfigurationTitleAlignmentCenter;
 UIFont *tf=[UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline].pointSize weight:UIFontWeightSemibold];
 NSMutableAttributedString *t=[[NSMutableAttributedString alloc] initWithString:action.title attributes:@{NSFontAttributeName:tf,NSForegroundColorAttributeName:fg}];
 if(action.detail.length){[t appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:action.detail] attributes:@{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1],NSForegroundColorAttributeName:primary?[MYBShieldBackground() colorWithAlphaComponent:.72]:MYBShieldMuted()}]];}
 c.attributedTitle=t;b.configuration=c;b.titleLabel.numberOfLines=0;b.titleLabel.textAlignment=NSTextAlignmentCenter;
 b.accessibilityLabel=action.detail.length?[NSString stringWithFormat:@"%@. %@",action.title,action.detail]:action.title;b.accessibilityTraits=UIAccessibilityTraitButton;
 NSLayoutConstraint *min=[b.heightAnchor constraintGreaterThanOrEqualToConstant:50];min.priority=999;min.active=YES;
 __weak typeof(self) weak=self;
 [b addAction:[UIAction actionWithHandler:^(__unused UIAction *x){[weak choose:action];}] forControlEvents:UIControlEventTouchUpInside];
 return b;
}
// Exactly once: a double tap, a tap during dismissal or a backdrop tap after a choice cannot run a second handler.
- (void)choose:(MYBShieldAction *)action{
 if(_fired)return;_fired=YES;_runs++;
 for(UIButton *b in _buttons)b.enabled=NO;
 if(action.handler)action.handler();
 NSDictionary *r=action.result?action.result():nil;
 if(r){
  BOOL ok=[r[@"ok"] boolValue];_headingLabel.text=r[@"title"];_messageLabel.text=r[@"message"];_messageLabel.hidden=NO;
  [self styleTile:ok?MYBShieldPositive():MYBShieldDanger() symbol:ok?@"checkmark.shield.fill":@"xmark.shield.fill"];
  for(UIView *v in [_content.arrangedSubviews copy])if(v!=_content.arrangedSubviews[0]&&v!=_headingLabel&&v!=_messageLabel){[_content removeArrangedSubview:v];[v removeFromSuperview];}
  __weak typeof(self) weak=self; // _fired stays set: the choice is final
  if(ok){ _buttons=[NSMutableArray array]; // success needs no button: it confirms and dismisses itself (longer with VoiceOver or long text)
   _success=YES; // a tap anywhere now dismisses it at once
   NSTimeInterval wait=MIN(3.0,MAX(1.4,1.2+[r[@"message"] length]/60.0));if(UIAccessibilityIsVoiceOverRunning())wait=MAX(wait,4.5);
   UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,_headingLabel);
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weak finish];});return;
  }
  MYBShieldAction *okAction=[MYBShieldAction title:@"OK" detail:nil style:MYBShieldActionPrimary handler:nil];
  UIButton *b=[self buttonFor:okAction];[b removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];[b addAction:[UIAction actionWithHandler:^(__unused UIAction *x){[weak finish];}] forControlEvents:UIControlEventTouchUpInside];
  _buttons=[NSMutableArray arrayWithObject:b];[_content addArrangedSubview:b];
  UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,_headingLabel);return;
 }
 [self finish];
}
- (void)finish{
 if(_gone)return;_gone=YES;
 __weak typeof(self) weak=self;
 [self dismissViewControllerAnimated:!MYBSheetStill() completion:^{typeof(self) s=weak;if(s&&s.onGone){void(^g)(void)=s.onGone;s.onGone=nil;g();}}];
}
- (void)backdropTapped:(UITapGestureRecognizer *)tap{
 if(_gone)return;
 if(_success){[self finish];return;} // the confirmation after a choice: tapping away (or on it) closes it straight away
 if(!self.dismissOnBackdrop||_fired)return;if(CGRectContainsPoint(_card.frame,[tap locationInView:self.view]))return;
 for(MYBShieldAction *a in self.actions)if(a.style==MYBShieldActionCancel){[self choose:a];return;}
 [self finish];
}
- (void)viewWillAppear:(BOOL)animated{
 [super viewWillAppear:animated];
 if(!MYBSheetStill()){_card.alpha=0;_card.transform=CGAffineTransformMakeTranslation(0,28);[UIView animateWithDuration:.4 delay:0 usingSpringWithDamping:.86 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{self->_card.alpha=1;self->_card.transform=CGAffineTransformIdentity;} completion:nil];}
}
// A sheet taken down by something other than its own buttons (the host went away, the system dismissed it) still reports
// that it is gone, once, so whatever was waiting on it can clear its state.
- (void)viewDidDisappear:(BOOL)animated{
 [super viewDidDisappear:animated];
 if(!_gone&&self.isBeingDismissed){_gone=YES;if(self.onGone){void(^g)(void)=self.onGone;self.onGone=nil;g();}}
}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];_card.alpha=1;_card.transform=CGAffineTransformIdentity; // hard end state
 if(self.autoClose>0&&!self.actions.count&&!_gone){ // a confirmation: a tap anywhere closes it at once, otherwise it closes by itself (longer with VoiceOver)
  _success=YES;NSTimeInterval wait=UIAccessibilityIsVoiceOverRunning()?MAX(self.autoClose,3.5):self.autoClose;__weak typeof(self) weak=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weak finish];});
 }
}
// Presents over `host` without animation under Reduce Motion. Returns NO (and calls nothing) when something is already
// presented, so prompts never stack; the caller decides what that means for the transition it was protecting.
+ (BOOL)present:(MYB_SHEET_CLASS *)sheet from:(UIViewController *)host completion:(void(^)(BOOL shown))completion{
 if(!host||host.presentedViewController){return NO;}
 sheet.modalPresentationStyle=UIModalPresentationOverFullScreen;sheet.modalTransitionStyle=UIModalTransitionStyleCrossDissolve;
 [host presentViewController:sheet animated:!MYBSheetStill() completion:^{if(completion)completion(host.presentedViewController==sheet);}];return YES;
}
@end
