#import "MYBDesign.h"
#import <QuartzCore/QuartzCore.h>

// The on-state fill is a gradient. Using layerClass makes the gradient the
// view’s own backing layer: it is sized by UIKit with the view, never needs a
// manual sublayer frame and can never be implicitly animated out of place.
@interface MYBSwitchFill : UIView @end
@implementation MYBSwitchFill
+ (Class)layerClass{return CAGradientLayer.class;}
@end

static const CGFloat kTrackW=50,kTrackH=30,kThumb=24,kThumbInset=3;

@interface MYBPrismSwitch ()
@property(nonatomic,strong) UIView *groove;
@property(nonatomic,strong) MYBSwitchFill *fill;
@property(nonatomic,strong) UIView *thumb;
@end

@implementation MYBPrismSwitch
- (instancetype)initWithFrame:(CGRect)frame{
 if(CGSizeEqualToSize(frame.size,CGSizeZero))frame.size=CGSizeMake(56,44);
 if((self=[super initWithFrame:frame])){
  self.isAccessibilityElement=YES;self.accessibilityLabel=@"Switch";
  self.onTintColor=MYBAccent();

  self.groove=[UIView new];self.groove.userInteractionEnabled=NO;
  self.groove.backgroundColor=[UIColor colorWithWhite:1 alpha:.085];
  self.groove.layer.borderWidth=1;self.groove.layer.borderColor=[UIColor colorWithWhite:1 alpha:.10].CGColor;
  self.groove.layer.cornerCurve=kCACornerCurveContinuous;
  [self addSubview:self.groove];

  self.fill=[MYBSwitchFill new];self.fill.userInteractionEnabled=NO;self.fill.alpha=0;
  self.fill.layer.cornerCurve=kCACornerCurveContinuous;
  CAGradientLayer *gradient=(CAGradientLayer *)self.fill.layer;gradient.startPoint=CGPointMake(0,0);gradient.endPoint=CGPointMake(1,1);
  [self addSubview:self.fill];

  self.thumb=[UIView new];self.thumb.userInteractionEnabled=NO;self.thumb.backgroundColor=UIColor.whiteColor;
  self.thumb.layer.shadowColor=UIColor.blackColor.CGColor;self.thumb.layer.shadowOpacity=.38;self.thumb.layer.shadowRadius=2.5;self.thumb.layer.shadowOffset=CGSizeMake(0,1.5);
  [self addSubview:self.thumb];

  [self addTarget:self action:@selector(toggleFromUser) forControlEvents:UIControlEventTouchUpInside];
  [self updateAccessibility];[self applyColors];
 }return self;
}
- (CGSize)intrinsicContentSize{return CGSizeMake(56,44);}
- (CGSize)sizeThatFits:(CGSize)size{(void)size;return self.intrinsicContentSize;}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event{
 // Generous touch target without enlarging the drawn control.
 return CGRectContainsPoint(CGRectInset(self.bounds,-4,-4),point)||[super pointInside:point withEvent:event];
}
- (void)setOn:(BOOL)value{[self setOn:value animated:NO];}
- (void)setOn:(BOOL)value animated:(BOOL)animated{
 if(_on==value)return;
 [self layoutIfNeeded];_on=value;[self updateAccessibility];[self setNeedsLayout];
 if(animated&&self.window&&!UIAccessibilityIsReduceMotionEnabled()){
  [UIView animateWithDuration:.34 delay:0 usingSpringWithDamping:.74 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{[self layoutIfNeeded];} completion:nil];
 }else [self layoutIfNeeded];
}
- (void)setEnabled:(BOOL)value{[super setEnabled:value];self.alpha=value?1:.42;[self updateAccessibility];}
- (void)setOnTintColor:(UIColor *)color{_onTintColor=color;[self applyColors];}
- (void)applyColors{
 UIColor *base=self.onTintColor?:MYBAccent();CGFloat h=0,s=0,b=0,a=1;
 UIColor *deep=base;if([base getHue:&h saturation:&s brightness:&b alpha:&a])deep=[UIColor colorWithHue:h saturation:MIN(1,s*1.08) brightness:b*.72 alpha:a];
 ((CAGradientLayer *)self.fill.layer).colors=@[(id)base.CGColor,(id)deep.CGColor];
}
- (void)updateAccessibility{
 self.accessibilityValue=self.on?@"On":@"Off";
 self.accessibilityTraits=UIAccessibilityTraitButton|(self.on?UIAccessibilityTraitSelected:0)|(!self.enabled?UIAccessibilityTraitNotEnabled:0);
}
- (void)toggleFromUser{
 MYBHaptic(MYBHapticLight);
 if(!self.enabled)return;
 [self setOn:!self.on animated:YES];[[UISelectionFeedbackGenerator new] selectionChanged];
 [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (BOOL)accessibilityActivate{if(!self.enabled)return NO;[self toggleFromUser];return YES;}
- (void)layoutSubviews{
 [super layoutSubviews];
 CGRect track=CGRectMake(round((self.bounds.size.width-kTrackW)/2),round((self.bounds.size.height-kTrackH)/2),kTrackW,kTrackH);
 self.groove.frame=track;self.groove.layer.cornerRadius=kTrackH/2;
 self.fill.frame=track;self.fill.layer.cornerRadius=kTrackH/2;self.fill.alpha=self.on?1:0;
 CGFloat x=self.on?CGRectGetMaxX(track)-kThumbInset-kThumb:CGRectGetMinX(track)+kThumbInset;
 self.thumb.frame=CGRectMake(x,CGRectGetMidY(track)-kThumb/2,kThumb,kThumb);
 self.thumb.layer.cornerRadius=kThumb/2;
 self.thumb.layer.shadowPath=[UIBezierPath bezierPathWithOvalInRect:self.thumb.bounds].CGPath;
}
@end
