#import "MYBMenuBase.h"
// Custom Rules (phone-wide) and the browser website rules that live inside Pop-Up Control share this editor, storage and validation.
@interface MYBRulesController : MYBMenuBase
@property(nonatomic,strong) NSMutableArray<NSMutableArray<NSString *> *> *lists;
@property(nonatomic,strong) NSMutableDictionary *shield;
@property(nonatomic,assign) NSInteger selectedList;   // 0 Blocked, 1 Allowed, 2 URLs (browser rules): the tile that is bright
- (NSInteger)tileSelection;
- (BOOL)isShieldRules;
- (BOOL)usesStatHero;   // YES: Activity-style header with tiles and the list selector. NO: the subclass puts its own selector in the page.
- (BOOL)usesSearch;     // YES: search field and + button in the navigation bar
- (void)loadRules;
- (void)saveRules;
- (void)editKind:(NSInteger)kind row:(NSInteger)row wildcard:(BOOL)wildcard;
@end
