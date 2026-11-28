#import "MYBDesign.h"
#import <QuartzCore/QuartzCore.h>

// Icon tile: a quiet glass square with a tone-coloured wash. The wash is the
// view’s own backing layer (layerClass), so there is no sublayer to size,
// clip or animate. The border is an ordinary layer border on a rounded view.
@interface MYBTileView : UIView
- (void)applyTone:(MYBTone)tone;
@end
@implementation MYBTileView
+ (Class)layerClass{return CAGradientLayer.class;}
- (instancetype)initWithFrame:(CGRect)frame{
 if((self=[super initWithFrame:frame])){
  CAGradientLayer *g=(CAGradientLayer *)self.layer;g.startPoint=CGPointMake(0,0);g.endPoint=CGPointMake(1,1);
  self.layer.cornerRadius=9;self.layer.cornerCurve=kCACornerCurveContinuous;self.layer.borderWidth=0; // flat tinted tile, no border
 }return self;
}
- (void)applyTone:(MYBTone)tone{
 UIColor *top=MYBToneColor(tone),*deep=MYBToneDeepColor(tone);
 ((CAGradientLayer *)self.layer).colors=@[(id)[top colorWithAlphaComponent:.18].CGColor,(id)[deep colorWithAlphaComponent:.14].CGColor];
}
@end

// SF Symbols carry optical alignment insets. Zero them so every symbol shares
// identical geometry inside its fixed tile.
@interface MYBCenteredIconView : UIImageView @end
@implementation MYBCenteredIconView
- (UIEdgeInsets)alignmentRectInsets{return UIEdgeInsetsZero;}
@end

@interface MYBPrismCell ()
@property(nonatomic,strong,readwrite) UILabel *mybTitleLabel;
@property(nonatomic,strong,readwrite) UILabel *mybDetailLabel;
@property(nonatomic,strong,readwrite) UIImageView *mybIconView;
@property(nonatomic,strong) UIImageView *appIconView;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) MYBTileView *iconBox;
@property(nonatomic,strong) UIView *separator;
@property(nonatomic,strong) UIView *topLight;
@property(nonatomic,strong) UIStackView *words;
@property(nonatomic,strong) UIStackView *row;
@property(nonatomic,strong) UIStackView *trailing;
@property(nonatomic,strong) UIImageView *chevron;
@end

@implementation MYBPrismCell
+ (instancetype)cellForTable:(UITableView *)table{
 MYBPrismCell *cell=[table dequeueReusableCellWithIdentifier:@"MYBPrismCell"];
 if(!cell)cell=[[MYBPrismCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MYBPrismCell"];
 return cell;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier{
 if((self=[super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])){
  (void)style;
  self.backgroundColor=UIColor.clearColor;self.contentView.backgroundColor=UIColor.clearColor;
  self.selectionStyle=UITableViewCellSelectionStyleDefault;
  // The card paints its own pressed state; suppress the system full-width selection fill.
  UIView *clear=[UIView new];clear.backgroundColor=UIColor.clearColor;self.selectedBackgroundView=clear;

  self.panel=[UIView new];self.panel.translatesAutoresizingMaskIntoConstraints=NO;self.panel.backgroundColor=MYBGroupFill(); // one translucent surface per group; no border, no blur, no per-row effects
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateHighlight) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
  self.panel.layer.cornerRadius=MYBCardRadius;self.panel.layer.cornerCurve=kCACornerCurveContinuous;
  [self.contentView addSubview:self.panel];

  self.topLight=[UIView new];self.topLight.translatesAutoresizingMaskIntoConstraints=NO;self.topLight.backgroundColor=[UIColor colorWithWhite:1 alpha:.09];self.topLight.userInteractionEnabled=NO;
  [self.panel addSubview:self.topLight];

  self.iconBox=[MYBTileView new];self.iconBox.translatesAutoresizingMaskIntoConstraints=NO;[self.iconBox applyTone:MYBToneViolet];
  self.mybIconView=[MYBCenteredIconView new];self.mybIconView.translatesAutoresizingMaskIntoConstraints=NO;self.mybIconView.contentMode=UIViewContentModeScaleAspectFit;self.mybIconView.tintColor=MYBToneColor(MYBToneViolet);
  self.mybIconView.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
  [self.iconBox addSubview:self.mybIconView];
  // Real app icon: fills the tile, clipped to a continuous rounded square; hidden unless an app icon is set.
  self.appIconView=[UIImageView new];self.appIconView.translatesAutoresizingMaskIntoConstraints=NO;self.appIconView.contentMode=UIViewContentModeScaleAspectFill;self.appIconView.clipsToBounds=YES;self.appIconView.layer.cornerRadius=9;self.appIconView.layer.cornerCurve=kCACornerCurveContinuous;self.appIconView.hidden=YES;self.appIconView.isAccessibilityElement=NO;
  [self.iconBox addSubview:self.appIconView];
  [NSLayoutConstraint activateConstraints:@[[self.appIconView.leadingAnchor constraintEqualToAnchor:self.iconBox.leadingAnchor],[self.appIconView.trailingAnchor constraintEqualToAnchor:self.iconBox.trailingAnchor],[self.appIconView.topAnchor constraintEqualToAnchor:self.iconBox.topAnchor],[self.appIconView.bottomAnchor constraintEqualToAnchor:self.iconBox.bottomAnchor]]];

  self.mybTitleLabel=[UILabel new];self.mybTitleLabel.font=MYBFont(16,UIFontWeightSemibold);self.mybTitleLabel.textColor=[UIColor colorWithWhite:.95 alpha:1];self.mybTitleLabel.numberOfLines=0;self.mybTitleLabel.adjustsFontForContentSizeCategory=YES;
  self.mybDetailLabel=[UILabel new];self.mybDetailLabel.font=MYBFont(12.5,UIFontWeightRegular);self.mybDetailLabel.textColor=MYBMuted();self.mybDetailLabel.numberOfLines=0;self.mybDetailLabel.adjustsFontForContentSizeCategory=YES;
  self.words=[[UIStackView alloc] initWithArrangedSubviews:@[self.mybTitleLabel,self.mybDetailLabel]];self.words.axis=UILayoutConstraintAxisVertical;self.words.spacing=3;
  [self.words setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

  self.trailing=[UIStackView new];self.trailing.axis=UILayoutConstraintAxisHorizontal;self.trailing.alignment=UIStackViewAlignmentCenter;
  [self.trailing setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [self.trailing setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

  self.chevron=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];self.chevron.contentMode=UIViewContentModeScaleAspectFit;
  self.chevron.tintColor=[MYBMuted() colorWithAlphaComponent:.7];
  self.chevron.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
  self.chevron.translatesAutoresizingMaskIntoConstraints=NO;
  [self.chevron.widthAnchor constraintEqualToConstant:18].active=YES;[self.chevron.heightAnchor constraintEqualToConstant:20].active=YES;

  self.row=[[UIStackView alloc] initWithArrangedSubviews:@[self.iconBox,self.words,self.trailing]];self.row.translatesAutoresizingMaskIntoConstraints=NO;
  self.row.axis=UILayoutConstraintAxisHorizontal;self.row.alignment=UIStackViewAlignmentCenter;self.row.spacing=MYBTileGap;
  [self.panel addSubview:self.row];

  // Separator starts exactly where the text starts, with or without an icon.
  self.separator=[UIView new];self.separator.translatesAutoresizingMaskIntoConstraints=NO;self.separator.backgroundColor=MYBHairline();self.separator.userInteractionEnabled=NO;
  [self.panel addSubview:self.separator];

  NSLayoutConstraint *tileW=[self.iconBox.widthAnchor constraintEqualToConstant:MYBTileSize],*tileH=[self.iconBox.heightAnchor constraintEqualToConstant:MYBTileSize];
  tileW.priority=tileH.priority=999;
  NSLayoutConstraint *minHeight=[self.row.heightAnchor constraintGreaterThanOrEqualToConstant:MYBTileSize];
  [NSLayoutConstraint activateConstraints:@[
   [self.panel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:MYBMargin],
   [self.panel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-MYBMargin],
   [self.panel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
   [self.panel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
   [self.row.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:MYBRowPadH],
   [self.row.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-MYBRowPadH],
   [self.row.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:MYBRowPadV],
   [self.row.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor constant:-MYBRowPadV],
   minHeight,tileW,tileH,
   [self.mybIconView.centerXAnchor constraintEqualToAnchor:self.iconBox.centerXAnchor],
   [self.mybIconView.centerYAnchor constraintEqualToAnchor:self.iconBox.centerYAnchor],
   [self.mybIconView.widthAnchor constraintEqualToConstant:20],
   [self.mybIconView.heightAnchor constraintEqualToConstant:20],
   [self.separator.leadingAnchor constraintEqualToAnchor:self.words.leadingAnchor],
   [self.separator.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-MYBRowPadH],
   [self.separator.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor],
   [self.separator.heightAnchor constraintEqualToConstant:1.0/UIScreen.mainScreen.scale],
   [self.topLight.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:MYBCardRadius],
   [self.topLight.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-MYBCardRadius],
   [self.topLight.topAnchor constraintEqualToAnchor:self.panel.topAnchor],
   [self.topLight.heightAnchor constraintEqualToConstant:1.0/UIScreen.mainScreen.scale]]];
  _tone=MYBToneViolet;_firstInGroup=YES;_lastInGroup=YES;
  [self applyPosition];[self refreshContent];
 }return self;
}

// Reuse reset: every property a controller may set is returned to its default
// so a recycled card can never leak a switch, tone, colour or position.
- (void)prepareForReuse{
 [super prepareForReuse];self.alpha=1;self.transform=CGAffineTransformIdentity;
 self.mybTitleLabel.text=nil;self.mybTitleLabel.textColor=[UIColor colorWithWhite:.95 alpha:1];self.mybTitleLabel.numberOfLines=0;self.mybTitleLabel.lineBreakMode=NSLineBreakByWordWrapping;
 self.mybDetailLabel.text=nil;self.mybDetailLabel.textColor=MYBMuted();self.mybDetailLabel.numberOfLines=0;
 self.mybIconView.image=nil;self.mybAppIcon=nil;self.tone=MYBToneViolet;
 self.mybAccessoryView=nil;self.mybAccessoryType=UITableViewCellAccessoryNone;
 self.selectionStyle=UITableViewCellSelectionStyleDefault;
 self.firstInGroup=YES;self.lastInGroup=YES;self.accessibilityTraits=UIAccessibilityTraitNone;
 [self updateHighlight];[self refreshContent];
}

- (void)setTone:(MYBTone)tone{_tone=tone;[self.iconBox applyTone:tone];self.mybIconView.tintColor=MYBToneColor(tone);}
- (void)setMybAccessoryView:(UIView *)view{
 if(_mybAccessoryView==view)return;
 for(UIView *v in self.trailing.arrangedSubviews){[self.trailing removeArrangedSubview:v];[v removeFromSuperview];}
 _mybAccessoryView=view;
 if(view){
  view.translatesAutoresizingMaskIntoConstraints=NO;[self.trailing addArrangedSubview:view];
  if([view isKindOfClass:MYBPrismSwitch.class]){[view.widthAnchor constraintEqualToConstant:56].active=YES;[view.heightAnchor constraintEqualToConstant:44].active=YES;}
  else if([view isKindOfClass:UILabel.class]){UILabel *value=(UILabel *)view;value.font=MYBFont(13,UIFontWeightMedium);value.textColor=MYBToneColor(MYBToneViolet);value.numberOfLines=0;value.textAlignment=NSTextAlignmentRight;value.adjustsFontForContentSizeCategory=YES;[view.widthAnchor constraintLessThanOrEqualToConstant:120].active=YES;}
 }
 [self refreshContent];
}
- (void)setMybAccessoryType:(UITableViewCellAccessoryType)type{
 _mybAccessoryType=type;
 BOOL check=type==UITableViewCellAccessoryCheckmark;
 self.chevron.image=[UIImage systemImageNamed:check?@"checkmark.circle.fill":@"chevron.right"];
 self.chevron.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:check?18:12 weight:check?UIImageSymbolWeightRegular:UIImageSymbolWeightSemibold];
 self.chevron.tintColor=check?MYBAccent():[MYBMuted() colorWithAlphaComponent:.7];
 [self refreshContent];
}
- (UIImage *)mybAppIcon{return self.appIconView.image;}
- (void)setMybAppIcon:(UIImage *)image{
 self.appIconView.image=image;self.appIconView.hidden=image==nil;self.mybIconView.hidden=image!=nil;
 // The icon is its own artwork: drop the tone wash behind it.
 if(image)((CAGradientLayer *)self.iconBox.layer).colors=nil;else [self.iconBox applyTone:self.tone];
}
- (void)refreshContent{
 BOOL hideDetail=!self.mybDetailLabel.text.length;if(self.mybDetailLabel.hidden!=hideDetail)self.mybDetailLabel.hidden=hideDetail;
 BOOL hideIcon=self.mybIconView.image==nil&&self.appIconView.image==nil;if(self.iconBox.hidden!=hideIcon)self.iconBox.hidden=hideIcon;
 if(!self.mybAccessoryView){
  BOOL show=self.mybAccessoryType!=UITableViewCellAccessoryNone;
  if(show&&self.chevron.superview!=self.trailing)[self.trailing addArrangedSubview:self.chevron];
  if(!show&&self.chevron.superview){[self.trailing removeArrangedSubview:self.chevron];[self.chevron removeFromSuperview];}
 }
 BOOL hideTrailing=!self.trailing.arrangedSubviews.count;if(self.trailing.hidden!=hideTrailing)self.trailing.hidden=hideTrailing;
 self.accessibilityLabel=[@[self.mybTitleLabel.text?:@"",self.mybDetailLabel.text?:@""] componentsJoinedByString:@". "];
 if([self.mybAccessoryView isKindOfClass:UIControl.class]){self.isAccessibilityElement=NO;self.mybAccessoryView.accessibilityLabel=self.accessibilityLabel;}
 else self.isAccessibilityElement=YES;
}

// Position inside a card. Only corner masking and the hairlines depend on it,
// so it is plain property state, applied immediately, independent of layout.
- (void)applyPosition{
 CACornerMask mask=0;
 if(self.firstInGroup)mask|=kCALayerMinXMinYCorner|kCALayerMaxXMinYCorner;
 if(self.lastInGroup)mask|=kCALayerMinXMaxYCorner|kCALayerMaxXMaxYCorner;
 self.panel.layer.maskedCorners=mask;
 self.separator.hidden=self.lastInGroup;
 self.topLight.hidden=!self.firstInGroup; // a single soft top edge per group gives depth; there are no other lines
}
- (void)setFirstInGroup:(BOOL)value{_firstInGroup=value;[self applyPosition];}
- (void)setLastInGroup:(BOOL)value{_lastInGroup=value;[self applyPosition];}
- (void)updateHighlight{self.panel.backgroundColor=(self.highlighted||self.selected)&&self.selectionStyle!=UITableViewCellSelectionStyleNone?MYBPanelHighlight():MYBGroupFill();}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (UIView *)mybPanelView{return self.panel;}
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated{[super setHighlighted:highlighted animated:animated];[UIView animateWithDuration:animated?.16:0 delay:0 usingSpringWithDamping:.8 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState animations:^{[self updateHighlight];if(!MYBReduceMotion())self.contentView.transform=highlighted?CGAffineTransformMakeScale(.975,.975):CGAffineTransformIdentity;} completion:nil];}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated{[super setSelected:selected animated:animated];[UIView animateWithDuration:animated?.25:0 animations:^{[self updateHighlight];}];}
@end
