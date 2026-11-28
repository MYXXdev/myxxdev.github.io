#import "MYBTileBase.h"
@implementation MYBTileListBase
- (NSString *)heroEyebrow{return @"MYbloXX®";}
- (NSString *)heroSymbol{return @"shield.fill";}
- (MYBTone)heroTone{return MYBToneRose;}
- (NSArray<NSDictionary *> *)tileSpecs{return @[];}
- (NSArray<NSString *> *)tileValueTexts{return @[];}
- (NSArray<NSString *> *)segmentTitles{return @[];}
- (void)tapTile:(NSInteger)index{(void)index;}
- (void)tileTapped:(UITapGestureRecognizer *)tap{
 if(tap.state!=UIGestureRecognizerStateEnded)return;
 MYBPressPulse(tap.view);[[UIImpactFeedbackGenerator new] impactOccurred];
 [self tapTile:tap.view.tag-1000];
}
- (void)segmentChanged{[self mybRebuildKeepingOffset];}
- (UIView *)makeHero{
 UISegmentedControl *segment=nil;NSArray *values=nil;
 UIView *hero=MYBStatHero(self.heroSymbol,self.heroTone,self.heroTitle,self.heroDetail,self.tileSpecs,self.segmentTitles,self.segment?self.segment.selectedSegmentIndex:0,self,@selector(tileTapped:),@selector(segmentChanged),&values,&segment);
 self.tileValues=values;self.segment=segment;return hero;
}
- (void)updateTiles{NSArray *texts=self.tileValueTexts;for(NSUInteger i=0;i<self.tileValues.count&&i<texts.count;i++){MYBCountUp(self.tileValues[i],[texts[i] integerValue]);UIView *tile=[self.tableView.tableHeaderView viewWithTag:1000+i];if(tile)tile.accessibilityValue=texts[i];}}
@end
