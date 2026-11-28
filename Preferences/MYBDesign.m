#import "MYBDesign.h"
#import "../Shared/MYBSheetFlowModel.h"
#import <roothide.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Tokens

UIColor *MYBAccent(void){return [UIColor colorWithRed:.71 green:.62 blue:1 alpha:1];}
UIColor *MYBBackground(void){return [UIColor colorWithRed:.035 green:.043 blue:.063 alpha:1];}
UIColor *MYBPanel(void){return [UIColor colorWithRed:.075 green:.084 blue:.113 alpha:1];}
UIColor *MYBPanelHighlight(void){return [UIColor colorWithRed:.118 green:.128 blue:.170 alpha:1];}
UIColor *MYBMuted(void){return [UIColor colorWithRed:.52 green:.57 blue:.66 alpha:1];}
UIColor *MYBHairline(void){return [UIColor colorWithWhite:1 alpha:.07];}
UIColor *MYBPositive(void){return [UIColor colorWithRed:.40 green:.88 blue:.68 alpha:1];}
UIColor *MYBWarning(void){return [UIColor colorWithRed:1 green:.76 blue:.36 alpha:1];}
UIColor *MYBDanger(void){return [UIColor colorWithRed:1 green:.48 blue:.56 alpha:1];}

UIColor *MYBToneColor(MYBTone tone){
 switch(tone){
  case MYBToneViolet:return [UIColor colorWithRed:.71 green:.62 blue:1 alpha:1];
  case MYBToneIndigo:return [UIColor colorWithRed:.52 green:.60 blue:1 alpha:1];
  case MYBToneBlue:return [UIColor colorWithRed:.38 green:.72 blue:1 alpha:1];
  case MYBToneTeal:return [UIColor colorWithRed:.36 green:.85 blue:.90 alpha:1];
  case MYBToneGreen:return [UIColor colorWithRed:.40 green:.88 blue:.68 alpha:1];
  case MYBToneAmber:return [UIColor colorWithRed:1 green:.76 blue:.36 alpha:1];
  case MYBToneRose:return [UIColor colorWithRed:1 green:.52 blue:.60 alpha:1];
  case MYBToneSlate:return [UIColor colorWithRed:.66 green:.70 blue:.80 alpha:1];
 }return MYBAccent();
}
UIColor *MYBToneDeepColor(MYBTone tone){
 switch(tone){
  case MYBToneViolet:return [UIColor colorWithRed:.50 green:.38 blue:.90 alpha:1];
  case MYBToneIndigo:return [UIColor colorWithRed:.33 green:.38 blue:.90 alpha:1];
  case MYBToneBlue:return [UIColor colorWithRed:.20 green:.50 blue:.92 alpha:1];
  case MYBToneTeal:return [UIColor colorWithRed:.18 green:.62 blue:.76 alpha:1];
  case MYBToneGreen:return [UIColor colorWithRed:.18 green:.66 blue:.52 alpha:1];
  case MYBToneAmber:return [UIColor colorWithRed:.93 green:.54 blue:.16 alpha:1];
  case MYBToneRose:return [UIColor colorWithRed:.88 green:.30 blue:.44 alpha:1];
  case MYBToneSlate:return [UIColor colorWithRed:.44 green:.48 blue:.60 alpha:1];
 }return MYBAccent();
}

UIFont *MYBFont(CGFloat size,UIFontWeight weight){return [UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:size weight:weight]];}
UIFont *MYBRoundedFont(CGFloat size,UIFontWeight weight){
 UIFont *base=[UIFont systemFontOfSize:size weight:weight];
 UIFontDescriptor *rounded=[base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
 return [UIFontMetrics.defaultMetrics scaledFontForFont:rounded?[UIFont fontWithDescriptor:rounded size:size]:base];
}

#pragma mark - Paths

NSString *MYBMobileFile(NSString *path){if([path hasPrefix:@"/var/mobile/Containers/"])return path;return jbroot(path);}
NSString *MYBPath(NSString *relativePath){
#if MYB_PREVIEW_HARNESS
 return [NSHomeDirectory() stringByAppendingPathComponent:[@"Documents/fixture" stringByAppendingString:relativePath]];
#endif
 NSString *bundle=[[NSBundle bundleForClass:NSClassFromString(@"MYBModernController")] bundlePath];
 NSRange marker=[bundle rangeOfString:@"/Library/PreferenceBundles/"];
 NSString *trimmed=[relativePath stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
 if(marker.location!=NSNotFound)return [[bundle substringToIndex:marker.location] stringByAppendingPathComponent:trimmed];
 return [@"/var/jb" stringByAppendingPathComponent:trimmed];
}
// The in-app mark is opaque square artwork; this view clips it once, with the iOS continuous curve scaled to its size
// (22.37% of the width), so the corner is correct at every size instead of a fixed 13 pt.
@interface MYBMarkView : UIImageView @end
@implementation MYBMarkView
- (void)layoutSubviews{[super layoutSubviews];CGFloat side=MIN(self.bounds.size.width,self.bounds.size.height);self.layer.cornerRadius=side*.2237;self.layer.cornerCurve=kCACornerCurveContinuous;self.clipsToBounds=YES;
 // Subtle frame so the dark artwork does not dissolve into the dark background; the artwork itself is untouched.
 self.layer.borderWidth=.75;self.layer.borderColor=[UIColor colorWithWhite:1 alpha:.24].CGColor;}
@end
UIImage *MYBMark(void){return [UIImage imageNamed:@"MYBIcon" inBundle:[NSBundle bundleForClass:NSClassFromString(@"MYBMenuBase")] compatibleWithTraitCollection:nil];}

#pragma mark - Small builders

static UILabel *label(NSString *text,CGFloat size,UIFontWeight weight,UIColor *color){
 UILabel *view=[UILabel new];view.text=text;view.font=MYBFont(size,weight);view.textColor=color;view.numberOfLines=0;view.adjustsFontForContentSizeCategory=YES;return view;
}
static NSAttributedString *tracked(NSString *text,CGFloat size,UIFontWeight weight,UIColor *color,CGFloat kern){
 return [[NSAttributedString alloc] initWithString:text.uppercaseString attributes:@{NSFontAttributeName:MYBFont(size,weight),NSForegroundColorAttributeName:color,NSKernAttributeName:@(kern)}];
}
#pragma mark - Headers

// Secondary screens: the navigation bar carries the title, so the header is only an optional one-paragraph summary.
// (Earlier builds repeated the title here at 34 pt with an eyebrow line, which made every screen start with a tall block.)
UIView *MYBHero(NSString *eyebrow,NSString *title,NSString *detail,BOOL compact){
 (void)eyebrow;(void)title;(void)compact;
 UIView *outer=[UIView new];
 if(!detail.length){UIView *gap=[UIView new];gap.translatesAutoresizingMaskIntoConstraints=NO;[gap.heightAnchor constraintEqualToConstant:4].active=YES;[outer addSubview:gap];[NSLayoutConstraint activateConstraints:@[[gap.topAnchor constraintEqualToAnchor:outer.topAnchor],[gap.bottomAnchor constraintEqualToAnchor:outer.bottomAnchor],[gap.leadingAnchor constraintEqualToAnchor:outer.leadingAnchor],[gap.trailingAnchor constraintEqualToAnchor:outer.trailingAnchor]]];return outer;}
 UILabel *summary=label(detail,14,UIFontWeightRegular,MYBMuted());summary.translatesAutoresizingMaskIntoConstraints=NO;[outer addSubview:summary];
 NSLayoutConstraint *bottom=[summary.bottomAnchor constraintEqualToAnchor:outer.bottomAnchor constant:-4];bottom.priority=999;
 [NSLayoutConstraint activateConstraints:@[[summary.leadingAnchor constraintEqualToAnchor:outer.leadingAnchor constant:MYBTextInset],[summary.trailingAnchor constraintEqualToAnchor:outer.trailingAnchor constant:-MYBTextInset],[summary.topAnchor constraintEqualToAnchor:outer.topAnchor constant:6],bottom]];
 return outer;
}

// ---- Badge header, summary tiles and one-shot motion --------------------------------------------------------------------------
@interface MYBGradientView : UIView @end
@implementation MYBGradientView
+ (Class)layerClass{return CAGradientLayer.class;}
@end
@interface MYBBadgeView : MYBGradientView @property(nonatomic,assign) BOOL settled; @end
@implementation MYBBadgeView
- (void)didMoveToWindow{
 [super didMoveToWindow];
 if(!self.window||self.settled)return;self.settled=YES;
 if(MYBReduceMotion())return;
 self.transform=CGAffineTransformMakeScale(.82,.82);
 [UIView animateWithDuration:.55 delay:.05 usingSpringWithDamping:.62 initialSpringVelocity:.4 options:0 animations:^{self.transform=CGAffineTransformIdentity;} completion:nil];
}
@end
UIView *MYBHeroBadge(NSString *symbol,MYBTone tone,NSString *title,NSString *detail){
 UIView *outer=[UIView new];
 MYBBadgeView *badge=[MYBBadgeView new];badge.translatesAutoresizingMaskIntoConstraints=NO;
 CAGradientLayer *g=(CAGradientLayer *)badge.layer;g.colors=@[(id)MYBToneColor(tone).CGColor,(id)MYBToneDeepColor(tone).CGColor];g.startPoint=CGPointMake(0,0);g.endPoint=CGPointMake(1,1);
 badge.layer.cornerRadius=17;badge.layer.cornerCurve=kCACornerCurveContinuous;
 badge.layer.shadowColor=MYBToneDeepColor(tone).CGColor;badge.layer.shadowOpacity=.45;badge.layer.shadowRadius=14;badge.layer.shadowOffset=CGSizeMake(0,6);
 UIImageView *glyph=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol?:@"circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:25 weight:UIImageSymbolWeightSemibold]]];
 glyph.tintColor=UIColor.whiteColor;glyph.contentMode=UIViewContentModeCenter;glyph.translatesAutoresizingMaskIntoConstraints=NO;[badge addSubview:glyph];
 UILabel *name=label(title,26,UIFontWeightBold,UIColor.whiteColor);name.font=MYBRoundedFont(26,UIFontWeightBold);name.adjustsFontSizeToFitWidth=YES;name.minimumScaleFactor=.7;name.numberOfLines=1;
 UILabel *summary=label(detail,14,UIFontWeightRegular,MYBMuted());
 UIStackView *text=[[UIStackView alloc] initWithArrangedSubviews:detail.length?@[name,summary]:@[name]];text.axis=UILayoutConstraintAxisVertical;text.spacing=3;text.translatesAutoresizingMaskIntoConstraints=NO;
 [outer addSubview:badge];[outer addSubview:text];
 NSLayoutConstraint *bottom=[text.bottomAnchor constraintLessThanOrEqualToAnchor:outer.bottomAnchor constant:-8];bottom.priority=999;
 NSLayoutConstraint *badgeBottom=[badge.bottomAnchor constraintLessThanOrEqualToAnchor:outer.bottomAnchor constant:-8];badgeBottom.priority=999;
 NSLayoutConstraint *height=[outer.heightAnchor constraintGreaterThanOrEqualToAnchor:badge.heightAnchor constant:16];height.priority=999;
 [NSLayoutConstraint activateConstraints:@[
  [badge.leadingAnchor constraintEqualToAnchor:outer.leadingAnchor constant:MYBMargin],[badge.topAnchor constraintEqualToAnchor:outer.topAnchor constant:6],[badge.widthAnchor constraintEqualToConstant:56],[badge.heightAnchor constraintEqualToConstant:56],
  [glyph.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],[glyph.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
  [text.leadingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:14],[text.trailingAnchor constraintEqualToAnchor:outer.trailingAnchor constant:-MYBMargin],[text.topAnchor constraintEqualToAnchor:outer.topAnchor constant:6],bottom,badgeBottom,height]];
 return outer;
}
UIView *MYBSummaryTile(NSString *symbol,MYBTone tone,NSString *caption,UILabel *__autoreleasing *valueOut){
 MYBGradientView *tile=[MYBGradientView new];
 CAGradientLayer *g=(CAGradientLayer *)tile.layer;g.colors=@[(id)[MYBToneColor(tone) colorWithAlphaComponent:.24].CGColor,(id)[MYBToneDeepColor(tone) colorWithAlphaComponent:.08].CGColor];g.startPoint=CGPointMake(0,0);g.endPoint=CGPointMake(1,1);
 tile.layer.cornerRadius=20;tile.layer.cornerCurve=kCACornerCurveContinuous;tile.layer.borderWidth=1;tile.layer.borderColor=[MYBToneColor(tone) colorWithAlphaComponent:.28].CGColor;
 UILabel *value=[UILabel new];value.font=MYBRoundedFont(30,UIFontWeightBold);value.textColor=UIColor.whiteColor;value.text=@"0";value.adjustsFontSizeToFitWidth=YES;value.minimumScaleFactor=.6;
 UILabel *cap=label(caption,12,UIFontWeightSemibold,MYBToneColor(tone));cap.numberOfLines=1;
 UIImageView *glyph=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol?:@"circle" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]]];glyph.tintColor=MYBToneColor(tone);glyph.contentMode=UIViewContentModeScaleAspectFit;glyph.translatesAutoresizingMaskIntoConstraints=NO;[glyph.widthAnchor constraintEqualToConstant:16].active=YES;[glyph.heightAnchor constraintEqualToConstant:16].active=YES; // every tile glyph occupies the same 16 pt square, so none sits higher or lower than the others
 UIStackView *top=[[UIStackView alloc] initWithArrangedSubviews:@[glyph,cap]];top.axis=UILayoutConstraintAxisHorizontal;top.spacing=6;top.alignment=UIStackViewAlignmentCenter;
 UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[top,value]];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=4;stack.translatesAutoresizingMaskIntoConstraints=NO;[tile addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:tile.topAnchor constant:13],[stack.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor constant:-13],[stack.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14],[stack.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-12]]];
 tile.isAccessibilityElement=YES;tile.accessibilityTraits=UIAccessibilityTraitButton;tile.accessibilityLabel=caption;
 if(valueOut)*valueOut=value;return tile;
}
// The stats header shared by Activity and the rule lists: a badge, up to three tappable tiles with counts, and an optional segmented control.
UIView *MYBTileStrip(NSArray<NSDictionary *> *tileSpecs,NSInteger selected,id target,SEL tileAction,NSArray<UILabel *> **valuesOut){
 NSMutableArray *tiles=[NSMutableArray array],*values=[NSMutableArray array];NSInteger n=0;
 for(NSDictionary *spec in tileSpecs){
  UILabel *value=nil;UIView *tile=MYBSummaryTile(spec[@"symbol"],(MYBTone)[spec[@"tone"] integerValue],spec[@"label"],&value);
  tile.tag=1000+n++;[tile addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:target action:tileAction]];
  [tiles addObject:tile];[values addObject:value];
 }
 UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:tiles];row.axis=UILayoutConstraintAxisHorizontal;row.distribution=UIStackViewDistributionFillEqually;row.spacing=10;
 MYBTileApplySelection(row,selected);
 if(valuesOut)*valuesOut=values;return row;
}
// Bright for the selected tile, dim for the rest. The state is also spoken: the selected tile carries the Selected trait and its count is its value.
void MYBTileApplySelection(UIView *container,NSInteger selected){
 for(NSInteger i=0;i<8;i++){
  UIView *tile=[container viewWithTag:1000+i];if(!tile)break;
  BOOL on=selected<0||i==selected;
  tile.alpha=on?1:.55;
  tile.accessibilityTraits=(selected>=0&&i==selected)?(UIAccessibilityTraitButton|UIAccessibilityTraitSelected):UIAccessibilityTraitButton;
 }
}
UIView *MYBStatHero(NSString *symbol,MYBTone tone,NSString *title,NSString *detail,NSArray<NSDictionary *> *tileSpecs,NSArray<NSString *> *segmentTitles,NSInteger selected,id target,SEL tileAction,SEL segmentAction,NSArray<UILabel *> **valuesOut,UISegmentedControl **segmentOut){
 UIView *summary=MYBHeroBadge(symbol,tone,title,detail);
 NSMutableArray *parts=[NSMutableArray arrayWithObject:summary];NSMutableArray *values=[NSMutableArray array];
 if(tileSpecs.count){
  NSArray *strip=nil;UIStackView *row=(UIStackView *)MYBTileStrip(tileSpecs,segmentTitles.count?-1:selected,target,tileAction,&strip);[values addObjectsFromArray:strip];
  UIView *wrap=[UIView new];row.translatesAutoresizingMaskIntoConstraints=NO;[wrap addSubview:row];
  [NSLayoutConstraint activateConstraints:@[[row.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:14],[row.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],[row.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:MYBMargin],[row.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-MYBMargin]]];
  [parts addObject:wrap];
 }
 UISegmentedControl *segment=nil;
 if(segmentTitles.count){
  segment=[[UISegmentedControl alloc] initWithItems:segmentTitles];segment.selectedSegmentIndex=selected;
  segment.selectedSegmentTintColor=MYBAccent();[segment setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:1 alpha:.75],NSFontAttributeName:MYBFont(14,UIFontWeightSemibold)} forState:UIControlStateNormal];
  [segment setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.blackColor,NSFontAttributeName:MYBFont(14,UIFontWeightBold)} forState:UIControlStateSelected];
  [segment addTarget:target action:segmentAction forControlEvents:UIControlEventValueChanged];
  UIView *wrap=[UIView new];segment.translatesAutoresizingMaskIntoConstraints=NO;[wrap addSubview:segment];
  [NSLayoutConstraint activateConstraints:@[[segment.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:16],[segment.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-4],[segment.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:MYBMargin],[segment.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-MYBMargin],[segment.heightAnchor constraintEqualToConstant:38]]];
  [parts addObject:wrap];
 }
 UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:parts];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=0;
 UIView *outer=[UIView new];stack.translatesAutoresizingMaskIntoConstraints=NO;[outer addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:outer.topAnchor],[stack.bottomAnchor constraintEqualToAnchor:outer.bottomAnchor constant:-6],[stack.leadingAnchor constraintEqualToAnchor:outer.leadingAnchor],[stack.trailingAnchor constraintEqualToAnchor:outer.trailingAnchor]]];
 if(valuesOut)*valuesOut=values;if(segmentOut)*segmentOut=segment;
 return outer;
}
// One-shot count-up: a short display-link run that ends by itself (never continuous).
@interface MYBCountDriver : NSObject
@property(nonatomic,weak) UILabel *label;@property(nonatomic,assign) NSInteger from,to;@property(nonatomic,assign) CFTimeInterval start;@property(nonatomic,strong) CADisplayLink *link;
@end
@implementation MYBCountDriver
- (void)tick:(CADisplayLink *)link{
 double t=MIN(1,(CACurrentMediaTime()-self.start)/.55),eased=1-pow(1-t,3);
 self.label.text=[NSString stringWithFormat:@"%ld",(long)llround(self.from+(self.to-self.from)*eased)];
 if(t>=1||!self.label){[link invalidate];self.link=nil;objc_setAssociatedObject(self.label,"mybcount",nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
}
@end
void MYBCountUp(UILabel *label,NSInteger target){
 if(!label)return;
 MYBCountDriver *running=objc_getAssociatedObject(label,"mybcount");if(running){[running.link invalidate];running.link=nil;}
 NSInteger from=label.text.integerValue;
 if(from==target||MYBReduceMotion()||!label.window){label.text=[NSString stringWithFormat:@"%ld",(long)target];objc_setAssociatedObject(label,"mybcount",nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;}
 MYBCountDriver *driver=[MYBCountDriver new];driver.label=label;driver.from=from;driver.to=target;driver.start=CACurrentMediaTime();
 driver.link=[CADisplayLink displayLinkWithTarget:driver selector:@selector(tick:)];[driver.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
 objc_setAssociatedObject(label,"mybcount",driver,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
void MYBPressPulse(UIView *view){
 if(!view||MYBReduceMotion())return;
 [UIView animateWithDuration:.1 animations:^{view.transform=CGAffineTransformMakeScale(.95,.95);} completion:^(BOOL f){(void)f;[UIView animateWithDuration:.45 delay:0 usingSpringWithDamping:.55 initialSpringVelocity:.6 options:0 animations:^{view.transform=CGAffineTransformIdentity;} completion:nil];}];
}

// The dashboard header: mark, name and ONE status line. No card, no pills, no byline; the mode lives in its own row below
// and the long explanation lives on the Status page. The explanation is shown here only when something needs attention.
#define MYBStatusDotTag 91
UIView *MYBDashboardHero(NSString *title,NSString *detail,NSString *tone,NSString *mode){
 (void)mode;
 BOOL active=[tone isEqual:@"positive"];
 UIView *outer=[UIView new];
 MYBMarkView *mark=[[MYBMarkView alloc] initWithImage:MYBMark()];mark.contentMode=UIViewContentModeScaleAspectFill;mark.translatesAutoresizingMaskIntoConstraints=NO;mark.isAccessibilityElement=NO;
 UILabel *name=[UILabel new];name.text=@"MYbloXX®";name.font=MYBRoundedFont(32,UIFontWeightBold);name.textColor=UIColor.whiteColor;name.adjustsFontForContentSizeCategory=YES;name.adjustsFontSizeToFitWidth=YES;name.minimumScaleFactor=.7;name.accessibilityTraits=UIAccessibilityTraitHeader;
 UIColor *stateColor=active?MYBPositive():[tone isEqual:@"warning"]?MYBWarning():MYBMuted();
 UIView *dot=[UIView new];dot.translatesAutoresizingMaskIntoConstraints=NO;dot.backgroundColor=stateColor;dot.layer.cornerRadius=4;dot.tag=MYBStatusDotTag;dot.isAccessibilityElement=NO;
 [NSLayoutConstraint activateConstraints:@[[dot.widthAnchor constraintEqualToConstant:8],[dot.heightAnchor constraintEqualToConstant:8]]];
 UILabel *state=label(title.length?title:@"Status unavailable",14,UIFontWeightSemibold,stateColor);state.numberOfLines=0;
 UIStackView *stateRow=[[UIStackView alloc] initWithArrangedSubviews:@[dot,state]];stateRow.axis=UILayoutConstraintAxisHorizontal;stateRow.spacing=8;stateRow.alignment=UIStackViewAlignmentCenter;
 UILabel *by=label(@"by MYXXdev\u2122",12,UIFontWeightMedium,MYBMuted());by.numberOfLines=1;
 NSMutableArray *lines=[NSMutableArray arrayWithObjects:name,by,stateRow,nil];
 if(!active&&detail.length){UILabel *why=label(detail,12.5,UIFontWeightRegular,MYBMuted());[lines addObject:why];}
 UIStackView *words=[[UIStackView alloc] initWithArrangedSubviews:lines];words.axis=UILayoutConstraintAxisVertical;words.spacing=3;
 UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[mark,words]];row.axis=UILayoutConstraintAxisHorizontal;row.spacing=16;row.alignment=UIStackViewAlignmentCenter;row.translatesAutoresizingMaskIntoConstraints=NO;[outer addSubview:row];
 NSLayoutConstraint *bottom=[row.bottomAnchor constraintEqualToAnchor:outer.bottomAnchor constant:-6];bottom.priority=999;
 [NSLayoutConstraint activateConstraints:@[[mark.widthAnchor constraintEqualToConstant:64],[mark.heightAnchor constraintEqualToConstant:64],[row.leadingAnchor constraintEqualToAnchor:outer.leadingAnchor constant:MYBMargin],[row.trailingAnchor constraintEqualToAnchor:outer.trailingAnchor constant:-MYBMargin],[row.topAnchor constraintEqualToAnchor:outer.topAnchor constant:14],bottom]];
 return outer;
}

@implementation MYBSectionHeaderView
- (instancetype)initWithReuseIdentifier:(NSString *)identifier{
 if((self=[super initWithReuseIdentifier:identifier])){
  self.backgroundConfiguration=[UIBackgroundConfiguration clearConfiguration];self.contentView.backgroundColor=UIColor.clearColor;
  _label=[UILabel new];_label.translatesAutoresizingMaskIntoConstraints=NO;_label.numberOfLines=0;_label.adjustsFontForContentSizeCategory=YES;_label.accessibilityTraits=UIAccessibilityTraitHeader;
  [self.contentView addSubview:_label];
  NSLayoutConstraint *bottom=[_label.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-9];bottom.priority=999;
  [NSLayoutConstraint activateConstraints:@[[_label.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:MYBTextInset],[_label.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-MYBTextInset],[_label.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:26],bottom]];
 }return self;
}
- (void)setTitle:(NSString *)title{_label.attributedText=tracked(title,11,UIFontWeightSemibold,MYBMuted(),1.4);}
@end

@implementation MYBSectionFooterView
- (instancetype)initWithReuseIdentifier:(NSString *)identifier{
 if((self=[super initWithReuseIdentifier:identifier])){
  self.backgroundConfiguration=[UIBackgroundConfiguration clearConfiguration];self.contentView.backgroundColor=UIColor.clearColor;
  _label=label(nil,12.5,UIFontWeightRegular,MYBMuted());_label.translatesAutoresizingMaskIntoConstraints=NO;
  [self.contentView addSubview:_label];
  NSLayoutConstraint *bottom=[_label.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6];bottom.priority=999;
  [NSLayoutConstraint activateConstraints:@[[_label.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:MYBTextInset],[_label.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-MYBTextInset],[_label.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],bottom]];
 }return self;
}
- (void)setText:(NSString *)text{_label.text=text;}
@end

#pragma mark - Table and navigation

void MYBStyleTable(UITableView *table){
 table.backgroundColor=MYBBackground();table.backgroundView=[MYBBackdropView new];
 // Rows draw their own hairlines inside the card. The system separator must be off: it is a full-width line that cuts across the
 // background and the gaps between groups (RC5.1 lost this line to a comment that swallowed it).
 table.separatorStyle=UITableViewCellSeparatorStyleNone;
 table.rowHeight=UITableViewAutomaticDimension;table.estimatedRowHeight=72;
 table.sectionHeaderHeight=UITableViewAutomaticDimension;table.estimatedSectionHeaderHeight=48;
 table.sectionFooterHeight=UITableViewAutomaticDimension;table.estimatedSectionFooterHeight=36;
 table.tintColor=MYBAccent();table.sectionHeaderTopPadding=0;table.cellLayoutMarginsFollowReadableWidth=NO;
 table.contentInset=UIEdgeInsetsMake(0,0,28,0);table.showsVerticalScrollIndicator=YES;table.indicatorStyle=UIScrollViewIndicatorStyleWhite;
}
void MYBStyleCell(UITableViewCell *view){if([view isKindOfClass:MYBPrismCell.class])[(MYBPrismCell *)view refreshContent];}

void MYBStyleNavigationItem(UIViewController *owner);
void MYBStyleNavigation(UIViewController *owner){
 MYBStyleNavigationItem(owner);
 owner.view.tintColor=MYBAccent();
 for(UIBarButtonItem *button in owner.navigationItem.rightBarButtonItems)button.tintColor=MYBAccent();
 UINavigationItem *item=owner.navigationItem;UISearchController *search=item.searchController;
 if(search){
  search.searchBar.searchBarStyle=UISearchBarStyleMinimal;search.searchBar.tintColor=MYBAccent();search.searchBar.barStyle=UIBarStyleBlack;
  search.searchBar.searchTextField.backgroundColor=MYBPanel();search.searchBar.searchTextField.font=MYBFont(15,UIFontWeightRegular);search.searchBar.searchTextField.textColor=UIColor.whiteColor;
  search.searchBar.searchTextField.attributedPlaceholder=[[NSAttributedString alloc] initWithString:search.searchBar.placeholder?:@"Search" attributes:@{NSForegroundColorAttributeName:MYBMuted()}];
 }
}
// The navigation item’s own bar look. The bar reads it when the screen is pushed, before viewDidLoad and viewWillAppear, so a screen with a
// branded header calls this as early as the object exists; that is what keeps the stock title from ever being drawn at the start of the push.
void MYBStyleNavigationItem(UIViewController *owner){
 // Everything here is attached to owner.navigationItem, so it is dropped
 // automatically when the screen leaves and never touches the shared Settings bar.
 UIImage *chevron=[[UIImage systemImageNamed:@"chevron.left" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold]] imageWithTintColor:MYBAccent() renderingMode:UIImageRenderingModeAlwaysOriginal];
 // The screen’s own background runs behind the status and navigation bars: at rest the bar is transparent, so there is no
 // separate black band; once content scrolls under it a dark blur of the same colour keeps the title readable.
 UINavigationBarAppearance *top=[UINavigationBarAppearance new];[top configureWithTransparentBackground];
 top.shadowColor=UIColor.clearColor;
 // The dashboard has its own branded header, so its bar title only appears once that header scrolls away; every other screen
 // shows the same white bar title at rest and scrolled.
 BOOL brandedHeader=[owner respondsToSelector:NSSelectorFromString(@"mybHasBrandedHeader")]||([owner respondsToSelector:NSSelectorFromString(@"mybRevealsTitle")]&&((BOOL(*)(id,SEL))objc_msgSend)(owner,NSSelectorFromString(@"mybRevealsTitle")));
 top.titleTextAttributes=@{NSForegroundColorAttributeName:brandedHeader?UIColor.clearColor:UIColor.whiteColor,NSFontAttributeName:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]};
 [top setBackIndicatorImage:chevron transitionMaskImage:chevron];
 UINavigationBarAppearance *scrolled=[top copy];
 scrolled.backgroundEffect=MYBReduceTransparency()?nil:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
 scrolled.backgroundColor=[MYBBackground() colorWithAlphaComponent:MYBReduceTransparency()?1:.62];
 scrolled.shadowColor=UIColor.clearColor; // no line under the bar, scrolled or not
 scrolled.titleTextAttributes=@{NSForegroundColorAttributeName:brandedHeader?UIColor.clearColor:UIColor.whiteColor,NSFontAttributeName:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]};
 UINavigationItem *item=owner.navigationItem;
 // The bar title is always visible and identical on every screen.
 item.standardAppearance=scrolled;item.compactAppearance=scrolled;item.scrollEdgeAppearance=top;item.compactScrollEdgeAppearance=top;
 item.backButtonDisplayMode=UINavigationItemBackButtonDisplayModeMinimal;
 item.largeTitleDisplayMode=UINavigationItemLargeTitleDisplayModeNever;
}

#pragma mark - Sheets

typedef NS_ENUM(NSInteger,MYBSheetKind){MYBSheetInfo,MYBSheetSuccess,MYBSheetFailure,MYBSheetAllowed,MYBSheetBlocked,MYBSheetProgress};
typedef NS_ENUM(NSInteger,MYBButtonStyle){MYBButtonPrimary,MYBButtonSecondary,MYBButtonDestructive};

static UIButton *sheetButton(NSString *title,MYBButtonStyle style,void(^action)(void)){
 UIButton *view=[UIButton buttonWithType:UIButtonTypeSystem];
 UIButtonConfiguration *config=[UIButtonConfiguration plainButtonConfiguration];
 config.contentInsets=NSDirectionalEdgeInsetsMake(15,18,15,18);
 UIColor *foreground=style==MYBButtonSecondary?UIColor.whiteColor:MYBBackground();
 if(style==MYBButtonPrimary){config.background.backgroundColor=MYBAccent();}
 else if(style==MYBButtonDestructive){config.background.backgroundColor=MYBDanger();}
 else config.background.backgroundColor=[UIColor colorWithWhite:1 alpha:.08];
 config.background.cornerRadius=16;
 config.attributedTitle=[[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName:MYBFont(16,UIFontWeightSemibold),NSForegroundColorAttributeName:foreground}];
 view.configuration=config;view.tintColor=foreground;
 NSLayoutConstraint *minimum=[view.heightAnchor constraintGreaterThanOrEqualToConstant:50];minimum.priority=999;minimum.active=YES;
 [view addAction:[UIAction actionWithHandler:^(__unused UIAction *a){if(action)action();}] forControlEvents:UIControlEventTouchUpInside];
 return view;
}

@interface MYBSheet : UIViewController<UITextFieldDelegate,UIGestureRecognizerDelegate>
@property(copy) NSString *heading;
@property(copy) NSString *detail;
@property(strong) NSArray *fields;
@property(strong) NSArray *choices;
@property(copy) NSString *primaryTitle;
@property(copy) void(^completion)(NSArray *);
@property(copy) void(^selection)(NSUInteger);
@property(copy) void(^gone)(void);   // called once when this sheet has left the screen (the coordinator then runs what waited for it)
@property MYBSheetKind kind;
@property BOOL destructive;
@property(strong) UIView *card;
@property(strong) UIStackView *content;
@property(strong) UILabel *headingLabel;
@property(strong) UILabel *detailLabel;
@property(strong) UIView *badge;
@property(strong) UIImageView *glyph;
@property(strong) UIActivityIndicatorView *spinner;
@property(strong) NSMutableArray<UITextField *> *inputs;
@property(strong) UIButton *primary;
@property(strong) UIButton *cancel;
@property(copy) void(^cancelled)(void);
@property NSUInteger generation;
@property BOOL queued;   // presentation requested but not yet started
@end

@implementation MYBSheet
- (BOOL)progress{return self.kind==MYBSheetProgress;}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.view.backgroundColor=[UIColor colorWithWhite:0 alpha:.60];
 UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped)];tap.delegate=self;[self.view addGestureRecognizer:tap];

 MYBGlassView *card=[MYBGlassView new];card.translatesAutoresizingMaskIntoConstraints=NO;card.userInteractionEnabled=YES;self.card=card;
 card.accessibilityViewIsModal=YES;[self.view addSubview:card];

 self.badge=[UIView new];self.badge.translatesAutoresizingMaskIntoConstraints=NO;self.badge.layer.cornerRadius=16;self.badge.layer.cornerCurve=kCACornerCurveContinuous;self.badge.layer.borderWidth=.5;
 self.glyph=[UIImageView new];self.glyph.translatesAutoresizingMaskIntoConstraints=NO;self.glyph.contentMode=UIViewContentModeScaleAspectFit;self.glyph.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];
 self.spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];self.spinner.translatesAutoresizingMaskIntoConstraints=NO;self.spinner.color=MYBAccent();self.spinner.hidesWhenStopped=YES;
 [self.badge addSubview:self.glyph];[self.badge addSubview:self.spinner];
 [NSLayoutConstraint activateConstraints:@[[self.badge.widthAnchor constraintEqualToConstant:56],[self.badge.heightAnchor constraintEqualToConstant:56],[self.glyph.centerXAnchor constraintEqualToAnchor:self.badge.centerXAnchor],[self.glyph.centerYAnchor constraintEqualToAnchor:self.badge.centerYAnchor],[self.spinner.centerXAnchor constraintEqualToAnchor:self.badge.centerXAnchor],[self.spinner.centerYAnchor constraintEqualToAnchor:self.badge.centerYAnchor]]];
 // One shared layout for every message, status and progress sheet: icon, title and text are all centred on the card’s axis.
 UIView *symbol=[UIView new];symbol.translatesAutoresizingMaskIntoConstraints=NO;[symbol addSubview:self.badge];
 [NSLayoutConstraint activateConstraints:@[[self.badge.centerXAnchor constraintEqualToAnchor:symbol.centerXAnchor],[self.badge.topAnchor constraintEqualToAnchor:symbol.topAnchor],[self.badge.bottomAnchor constraintEqualToAnchor:symbol.bottomAnchor]]];

 self.headingLabel=[UILabel new];self.headingLabel.font=MYBRoundedFont(24,UIFontWeightBold);self.headingLabel.textColor=UIColor.whiteColor;self.headingLabel.numberOfLines=0;self.headingLabel.adjustsFontForContentSizeCategory=YES;self.headingLabel.accessibilityTraits=UIAccessibilityTraitHeader;
 self.detailLabel=label(nil,14,UIFontWeightRegular,MYBMuted());
 self.headingLabel.textAlignment=NSTextAlignmentCenter;self.detailLabel.textAlignment=NSTextAlignmentCenter;
 self.content=[[UIStackView alloc] initWithArrangedSubviews:@[symbol,self.headingLabel,self.detailLabel]];self.content.translatesAutoresizingMaskIntoConstraints=NO;self.content.axis=UILayoutConstraintAxisVertical;self.content.alignment=UIStackViewAlignmentFill;self.content.spacing=14;[self.content setCustomSpacing:8 afterView:self.headingLabel];

 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.showsVerticalScrollIndicator=NO;scroll.alwaysBounceVertical=NO;scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;[card addSubview:scroll];[scroll addSubview:self.content];

 self.inputs=[NSMutableArray array];
 for(NSDictionary *spec in self.fields){
  UITextField *input=[UITextField new];input.backgroundColor=MYBBackground();input.textColor=UIColor.whiteColor;input.tintColor=MYBAccent();input.font=MYBFont(16,UIFontWeightRegular);input.adjustsFontForContentSizeCategory=YES;
  input.layer.cornerRadius=14;input.layer.cornerCurve=kCACornerCurveContinuous;input.layer.borderWidth=.5;input.layer.borderColor=[UIColor colorWithWhite:1 alpha:.12].CGColor;
  input.text=spec[@"value"];input.attributedPlaceholder=[[NSAttributedString alloc] initWithString:spec[@"placeholder"]?:@"" attributes:@{NSForegroundColorAttributeName:MYBMuted()}];
  input.keyboardType=spec[@"keyboard"]?[spec[@"keyboard"] integerValue]:UIKeyboardTypeURL;input.secureTextEntry=[spec[@"secure"] boolValue];input.autocapitalizationType=UITextAutocapitalizationTypeNone;input.autocorrectionType=UITextAutocorrectionTypeNo;input.spellCheckingType=UITextSpellCheckingTypeNo;
  input.returnKeyType=UIReturnKeyDone;input.clearButtonMode=UITextFieldViewModeWhileEditing;input.keyboardAppearance=UIKeyboardAppearanceDark;input.delegate=self;
  UIView *padding=[[UIView alloc] initWithFrame:CGRectMake(0,0,16,1)];input.leftView=padding;input.leftViewMode=UITextFieldViewModeAlways;
  [input.heightAnchor constraintGreaterThanOrEqualToConstant:52].active=YES;[self.content addArrangedSubview:input];[self.inputs addObject:input];
 }
 __weak MYBSheet *weak=self;
 for(NSUInteger i=0;i<self.choices.count;i++){
  UIButton *choice=sheetButton(self.choices[i],MYBButtonSecondary,^{MYBSheet *sheet=weak;[sheet dismissViewControllerAnimated:YES completion:^{if(sheet.selection)sheet.selection(i);}];});
  [self.content addArrangedSubview:choice];
 }
 self.primary=sheetButton(self.primaryTitle?:@"Done",self.destructive?MYBButtonDestructive:MYBButtonPrimary,^{[weak submit];});[self.content addArrangedSubview:self.primary];
 self.cancel=sheetButton(@"Cancel",MYBButtonSecondary,^{void(^gone)(void)=weak.cancelled;[weak dismissViewControllerAnimated:YES completion:^{if(gone)gone();}];});[self.content addArrangedSubview:self.cancel];

 NSLayoutConstraint *cardWidth=[card.widthAnchor constraintEqualToConstant:420];cardWidth.priority=UILayoutPriorityDefaultHigh;
 NSLayoutConstraint *leading=[card.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],*trailing=[card.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16];
 leading.priority=trailing.priority=UILayoutPriorityRequired-1;
 [NSLayoutConstraint activateConstraints:@[
  cardWidth,leading,trailing,
  [card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
  [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
  [card.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
  [card.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-16],
  [card.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
  [scroll.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:card.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
  [self.content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],[self.content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
  [self.content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:26],[self.content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
  [self.content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48]]];
 // The card hugs its content until it would leave the safe area; then the scroll view takes over.
 NSLayoutConstraint *fit=[scroll.heightAnchor constraintEqualToAnchor:self.content.heightAnchor constant:50];fit.priority=UILayoutPriorityDefaultLow;fit.active=YES;
 [self update];
}
- (void)viewWillAppear:(BOOL)animated{
 [super viewWillAppear:animated];
 if(MYBMotionAllowed()){self.card.alpha=0;self.card.transform=CGAffineTransformMakeScale(.94,.94);[UIView animateWithDuration:.42 delay:0 usingSpringWithDamping:.82 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{self.card.alpha=1;self.card.transform=CGAffineTransformIdentity;} completion:nil];}
}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];self.card.alpha=1;self.card.transform=CGAffineTransformIdentity; // hard end state
 UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,self.headingLabel);
 // The badge springs in and the glyph bounces; a result also taps the haptic engine (success or failure).
 if(MYBMotionAllowed()&&!self.progress){
  self.badge.transform=CGAffineTransformMakeScale(.7,.7);self.glyph.transform=CGAffineTransformMakeScale(.5,.5);
  [UIView animateWithDuration:.5 delay:.1 usingSpringWithDamping:.7 initialSpringVelocity:.5 options:0 animations:^{self.badge.transform=CGAffineTransformIdentity;} completion:nil];
  [UIView animateWithDuration:.5 delay:.18 usingSpringWithDamping:.65 initialSpringVelocity:.6 options:0 animations:^{self.glyph.transform=CGAffineTransformIdentity;} completion:nil];
 }
 if(self.kind==MYBSheetSuccess||self.kind==MYBSheetAllowed)MYBHaptic(MYBHapticSuccess);else if(self.kind==MYBSheetFailure)MYBHaptic(MYBHapticFailure);
 [self.inputs.firstObject becomeFirstResponder];
}
- (void)submit{
 NSMutableArray *values=[NSMutableArray array];for(UITextField *input in self.inputs)[values addObject:input.text?:@""];
 [self.view endEditing:YES];
 [self dismissViewControllerAnimated:YES completion:^{if(self.completion)self.completion(values);}];
}
- (void)viewDidDisappear:(BOOL)animated{
 [super viewDidDisappear:animated];
 if((self.isBeingDismissed||self.isMovingFromParentViewController||!self.presentingViewController)&&self.gone){void(^done)(void)=self.gone;self.gone=nil;done();}
}
- (BOOL)dismissable{return self.kind!=MYBSheetProgress;}
- (void)backgroundTapped{if(self.dismissable&&!self.isBeingDismissed)[self dismissViewControllerAnimated:YES completion:nil];}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch{(void)gesture;return touch.view==self.view;}
- (BOOL)textFieldShouldReturn:(UITextField *)field{
 NSUInteger index=[self.inputs indexOfObject:field];
 if(index!=NSNotFound&&index+1<self.inputs.count){[self.inputs[index+1] becomeFirstResponder];return NO;}
 [field resignFirstResponder];return NO;
}
- (void)update{
 if(!self.isViewLoaded)return;
 self.headingLabel.text=self.heading;self.detailLabel.text=self.detail;self.detailLabel.hidden=!self.detail.length;
 BOOL progress=self.progress;UIColor *tone=MYBAccent();NSString *symbol=@"info.circle.fill";
 switch(self.kind){
  case MYBSheetSuccess:tone=MYBPositive();symbol=@"checkmark.circle.fill";break;
  case MYBSheetFailure:tone=MYBDanger();symbol=@"exclamationmark.triangle.fill";break;
  case MYBSheetAllowed:tone=MYBPositive();symbol=@"checkmark.shield.fill";break;
  case MYBSheetBlocked:tone=MYBWarning();symbol=@"hand.raised.fill";break;
  default:break;
 }
 if(self.destructive&&self.kind==MYBSheetInfo){tone=MYBDanger();symbol=@"exclamationmark.triangle.fill";}
 self.badge.backgroundColor=[tone colorWithAlphaComponent:.14];self.badge.layer.borderColor=[tone colorWithAlphaComponent:.32].CGColor;
 self.glyph.image=[UIImage systemImageNamed:symbol];self.glyph.tintColor=tone;self.glyph.hidden=progress;
 self.spinner.color=tone;if(progress)[self.spinner startAnimating];else [self.spinner stopAnimating];
 self.primary.hidden=progress||self.choices.count>0||self.kind==MYBSheetSuccess; // success dismisses itself; decisions and failures keep their buttons
 self.cancel.hidden=progress||(!self.completion&&!self.selection);
 self.headingLabel.accessibilityLabel=self.heading;
}
@end

static char sheetKey;
static void whenPresentable(UIViewController *owner,int attempt,void(^block)(UIViewController *host)){
 // Never present into a transition: UIKit drops such a presentation silently.
 UIViewController *host=owner;
 while(host.presentedViewController&&!host.presentedViewController.isBeingDismissed)host=host.presentedViewController;
 BOOL transitioning=host.isBeingPresented||host.isBeingDismissed||owner.presentedViewController.isBeingDismissed||owner.presentedViewController.isBeingPresented;
 if(transitioning&&attempt<30){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{whenPresentable(owner,attempt+1,block);});return;}
 block(host);
}
static void presentSheet(UIViewController *owner,MYBSheet *sheet){
 sheet.modalPresentationStyle=UIModalPresentationOverFullScreen;sheet.modalTransitionStyle=UIModalTransitionStyleCrossDissolve;
 sheet.queued=YES;
 whenPresentable(owner,0,^(UIViewController *host){sheet.queued=NO;[host presentViewController:sheet animated:YES completion:nil];});
}
static MYBSheet *sheetFor(UIViewController *owner){
 MYBSheet *sheet=objc_getAssociatedObject(owner,&sheetKey);
 if(sheet&&!sheet.isBeingDismissed&&(sheet.presentingViewController||sheet.queued))return sheet;
 sheet=[MYBSheet new];objc_setAssociatedObject(owner,&sheetKey,sheet,OBJC_ASSOCIATION_RETAIN_NONATOMIC);presentSheet(owner,sheet);return sheet;
}
// ---- one presentation flow per screen -----------------------------------------------------------------------------------------
// Two kinds of sheet share a screen: STATUS (progress / result / message, one reusable sheet) and DECISION (confirm, choose, input).
// Rules, so an Apply/progress/success sheet can never cover or dismiss the options the person is choosing between:
//  * at most one decision sheet is on screen or queued; a second request waits for it to leave (a duplicate of the same title is ignored,
//    which also absorbs repeated taps);
//  * while a decision is up, status updates are held (latest one wins) and shown only after it has gone;
//  * a decision first removes any status sheet it would otherwise sit on top of, and no timer or dismissal ever dismisses a sheet that has
//    another sheet presented above it (UIKit would take that one down too).
@interface MYBSheetFlow : NSObject
@property(strong) MYBSheetFlowModel *model;            // the rules (Shared/MYBSheetFlowModel.h)
@property(strong) MYBSheet *decision;                  // the decision sheet that is queued or on screen
@property(strong) NSMutableArray<void(^)(void)> *waiting; // what starts each queued decision, in the model’s order
@property(strong) NSDictionary *heldStatus;
@end
@implementation MYBSheetFlow @end
static char flowKey;
static MYBSheetFlow *flowFor(UIViewController *owner){
 MYBSheetFlow *f=objc_getAssociatedObject(owner,&flowKey);
 if(!f){f=[MYBSheetFlow new];f.model=[MYBSheetFlowModel new];f.waiting=[NSMutableArray array];objc_setAssociatedObject(owner,&flowKey,f,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
 return f;
}
static BOOL sheetTopmost(MYBSheet *sheet){return sheet&&sheet.presentingViewController&&!sheet.isBeingDismissed&&!sheet.presentedViewController;}
static void showState(UIViewController *owner,MYBSheetKind kind,NSString *title,NSString *detail,BOOL autoDismiss);
static void startDecision(UIViewController *owner,MYBSheet *sheet);
static void decisionGone(UIViewController *owner){
 MYBSheetFlow *f=flowFor(owner);f.decision=nil;
 MYBFlowAction what=[f.model decisionGone];
 if(what==MYBFlowNextDecision&&f.waiting.count){void(^next)(void)=f.waiting.firstObject;[f.waiting removeObjectAtIndex:0];next();return;}
 if(what==MYBFlowShowHeld){NSDictionary *held=f.heldStatus;f.heldStatus=nil;
  if(held)showState(owner,(MYBSheetKind)[held[@"kind"] integerValue],held[@"title"],held[@"detail"],[held[@"auto"] boolValue]);}
}
static void showState(UIViewController *owner,MYBSheetKind kind,NSString *title,NSString *detail,BOOL autoDismiss){
 MYBSheetFlow *flow=flowFor(owner);
 if([flow.model requestStatus]==MYBFlowHoldStatus){flow.heldStatus=@{@"kind":@(kind),@"title":title?:@"",@"detail":detail?:@"",@"auto":@(autoDismiss)};return;}
 MYBSheet *sheet=sheetFor(owner);NSUInteger generation=++sheet.generation;
 sheet.heading=title;sheet.detail=detail;sheet.kind=kind;sheet.completion=nil;sheet.selection=nil;[sheet update];
 NSTimeInterval wait=MIN(4.5,MAX(1.8,1.6+detail.length/40.0));if(UIAccessibilityIsVoiceOverRunning())wait=MAX(wait,4.5);
 if(autoDismiss)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(sheet.generation==generation&&sheetTopmost(sheet))[sheet dismissViewControllerAnimated:YES completion:nil];});
}
void MYBProgress(UIViewController *owner,NSString *title){showState(owner,MYBSheetProgress,[title hasSuffix:@"..."]?title:[title stringByAppendingString:@"..."],@"Please wait a moment...",NO);}
void MYBComplete(UIViewController *owner,BOOL success,NSString *title,NSString *detail){MYBHaptic(success?MYBHapticSuccess:MYBHapticFailure);showState(owner,success?MYBSheetSuccess:MYBSheetFailure,title,detail,success);}
// Closes the status sheet (progress, result) that this screen owns, without a result; used when a PIN question takes over.
void MYBDismissStatus(UIViewController *owner){
 MYBSheet *sheet=objc_getAssociatedObject(owner,&sheetKey);if(!sheet)return;sheet.generation++;
 if(sheetTopmost(sheet))[sheet dismissViewControllerAnimated:NO completion:nil]; // never takes a sheet down that another sheet sits on
 flowFor(owner).heldStatus=nil;[flowFor(owner).model dropHeld];
}
void MYBMessage(UIViewController *owner,NSString *title,NSString *detail){showState(owner,MYBSheetInfo,title,detail,NO);}
void MYBDecision(UIViewController *owner,BOOL allowed,NSString *domain,NSString *reason){
 showState(owner,allowed?MYBSheetAllowed:MYBSheetBlocked,allowed?@"Website allowed":@"Website blocked",[NSString stringWithFormat:@"%@\n%@",domain?:@"",reason?:@""],NO);
}
static void startDecision(UIViewController *owner,MYBSheet *sheet){
 MYBSheetFlow *f=flowFor(owner);f.decision=sheet;
 __weak UIViewController *weakOwner=owner;sheet.gone=^{UIViewController *o=weakOwner;if(o)decisionGone(o);};
 // Take away a status sheet this decision would sit on top of: a later dismissal of that sheet would take the options with it.
 MYBSheet *status=objc_getAssociatedObject(owner,&sheetKey);status.generation++;
 if(sheetTopmost(status))[status dismissViewControllerAnimated:NO completion:nil];
 presentSheet(owner,sheet);
 // Safety net: if UIKit never shows the sheet, the flow must not stay blocked behind it.
 __weak MYBSheet *weakSheet=sheet;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(6*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  MYBSheet *x=weakSheet;UIViewController *o=weakOwner;
  if(o&&x&&flowFor(o).decision==x&&!x.queued&&!x.presentingViewController&&!x.isBeingPresented){x.gone=nil;decisionGone(o);}
 });
}
static void presentFresh(UIViewController *owner,NSString *title,NSString *detail,void(^configure)(MYBSheet *)){
 MYBSheet *sheet=[MYBSheet new];sheet.heading=title;sheet.detail=detail;if(configure)configure(sheet);
 MYBSheetFlow *f=flowFor(owner);
 MYBFlowAction what=[f.model requestDecision:title];
 if(what==MYBFlowIgnore)return; // the same question is already up or queued (a repeated tap)
 if(what==MYBFlowQueue){__weak UIViewController *weakOwner=owner;[f.waiting addObject:[^{UIViewController *o=weakOwner;if(o)startDecision(o,sheet);} copy]];return;}
 startDecision(owner,sheet);
}
void MYBConfirm(UIViewController *owner,NSString *title,NSString *detail,void(^action)(void)){
 presentFresh(owner,title,detail,^(MYBSheet *s){s.primaryTitle=@"Continue";s.completion=^(__unused NSArray *v){if(action)action();};});
}
void MYBConfirmWithButton(UIViewController *owner,NSString *title,NSString *detail,NSString *button,void(^action)(void)){
 presentFresh(owner,title,detail,^(MYBSheet *s){s.primaryTitle=button?:@"Continue";s.completion=^(__unused NSArray *v){if(action)action();};});
}
void MYBConfirmDestructive(UIViewController *owner,NSString *title,NSString *detail,NSString *button,void(^action)(void)){
 presentFresh(owner,title,detail,^(MYBSheet *s){s.primaryTitle=button?:@"Continue";s.destructive=YES;s.completion=^(__unused NSArray *v){if(action)action();};});
}
void MYBInput(UIViewController *owner,NSString *title,NSString *detail,NSArray *fields,NSString *titleButton,void(^action)(NSArray *)){
 presentFresh(owner,title,detail,^(MYBSheet *s){s.fields=fields;s.primaryTitle=titleButton;s.completion=action;});
}
void MYBInputCancellable(UIViewController *owner,NSString *title,NSString *detail,NSArray *fields,NSString *titleButton,void(^action)(NSArray *),void(^cancelled)(void)){
 presentFresh(owner,title,detail,^(MYBSheet *s){s.fields=fields;s.primaryTitle=titleButton;s.completion=action;s.cancelled=cancelled;});
}
void MYBChoose(UIViewController *owner,NSString *title,NSArray *choices,void(^action)(NSUInteger)){
 presentFresh(owner,title,nil,^(MYBSheet *s){s.choices=choices;s.selection=action;});
}
