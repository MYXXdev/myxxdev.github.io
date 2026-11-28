// Focused check of Shared/MYBCleanupRules.h: narrow selectors, validated updates with a last-working fallback, per-site exceptions, pause (GNU runtime friendly).
#import "../Shared/MYBCleanupRules.h"
static int fails=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL %s\n",m);fails++;}}while(0)
static NSDictionary *Cfg(BOOL cookies,BOOL app,BOOL chat,BOOL news){return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:cookies],@"CleanupCookies",[NSNumber numberWithBool:app],@"CleanupOpenInApp",[NSNumber numberWithBool:chat],@"CleanupChat",[NSNumber numberWithBool:news],@"CleanupNewsletter",nil];}
int main(void){@autoreleasepool{
 NSDictionary *rules=MYBCleanupDefaultRules();
 for(NSString *cat in MYBCleanupCategories())for(NSString *s in [rules objectForKey:cat])CHECK(MYBCleanupSelectorOK(s),"every built-in selector passes the validator");
 CHECK(!MYBCleanupSelectorOK(@"body")==NO&&MYBCleanupSelectorOK(@"div.banner"),"plain element selectors are accepted");
 CHECK(!MYBCleanupSelectorOK(@"a{color:red}")&&!MYBCleanupSelectorOK(@".x;.y")&&!MYBCleanupSelectorOK(@"\\3a")&&!MYBCleanupSelectorOK(@"@import")&&!MYBCleanupSelectorOK(@"."),"selectors that could break out of a rule are refused");
 CHECK(MYBCleanupRuleJSON(rules,Cfg(NO,NO,NO,NO),1)==nil,"nothing is applied until a category is switched on");
 NSString *json=MYBCleanupRuleJSON(rules,Cfg(YES,NO,NO,NO),1);
 CHECK(json&&[json containsString:@"css-display-none"]&&[json containsString:@"onetrust"]&&![json containsString:@"smartbanner"],"only the switched-on category is in the rule");
 CHECK(![json containsString:@"click"]&&![json containsString:@"accept"],"nothing clicks or accepts anything");
 id parsed=[NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];CHECK([parsed isKindOfClass:NSArray.class]&&[parsed count]==1,"the rule list is valid JSON with one rule");
 NSMutableDictionary *withEx=[Cfg(YES,YES,NO,NO) mutableCopy];[withEx setObject:[NSArray arrayWithObjects:@"https://www.Bank.example/login?x=1",@"shop.example.org",@"nonsense",nil] forKey:@"CleanupExceptions"];
 NSString *ex=MYBCleanupRuleJSON(rules,withEx,1);CHECK([ex containsString:@"unless-domain"]&&[ex containsString:@"*bank.example"]&&[ex containsString:@"*shop.example.org"]&&![ex containsString:@"nonsense"],"exceptions skip the site and its subdomains; junk is dropped");
 NSMutableDictionary *paused=[Cfg(YES,YES,YES,YES) mutableCopy];[paused setObject:[NSNumber numberWithDouble:500] forKey:@"CleanupPausedUntil"];
 CHECK(MYBCleanupRuleJSON(rules,paused,100)==nil&&MYBCleanupRuleJSON(rules,paused,600)!=nil,"pause turns cleanup off until its time ends");
 CHECK([MYBCleanupHost(@"https://WWW.Example.com/a?b=1#c")isEqual:@"example.com"]&&MYBCleanupHost(@"not a host")==nil&&MYBCleanupHost(@"localhost")==nil,"hosts are normalized and junk is refused");
 // validated updates
 NSString *dir=@"/tmp/mybloxx-cleanup-test";[NSFileManager.defaultManager removeItemAtPath:dir error:NULL];[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *update=[dir stringByAppendingPathComponent:@"rules.json"],*good=[dir stringByAppendingPathComponent:@"good.json"];NSString *src=nil;
 CHECK([MYBCleanupLoad(update,good,&src) isEqual:rules]&&[src isEqualToString:@"built-in"],"no update: built-in rules");
 [@"{\"categories\":{\"cookies\":[\"#only-this\"]}}" writeToFile:update atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 NSDictionary *got=MYBCleanupLoad(update,good,&src);CHECK([[got objectForKey:@"cookies"] isEqual:[NSArray arrayWithObject:@"#only-this"]]&&[src isEqualToString:@"update"],"a valid update is used");
 [@"{\"categories\":{\"cookies\":[\"a{x:y}\"]}}" writeToFile:update atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 got=MYBCleanupLoad(update,good,&src);CHECK([[got objectForKey:@"cookies"] isEqual:[NSArray arrayWithObject:@"#only-this"]]&&[src isEqualToString:@"last-working"],"a bad update keeps the last working set");
 [@"not json at all" writeToFile:update atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 got=MYBCleanupLoad(update,good,&src);CHECK([src isEqualToString:@"last-working"],"unreadable update keeps the last working set");
 [NSFileManager.defaultManager removeItemAtPath:good error:NULL];got=MYBCleanupLoad(update,good,&src);CHECK([got isEqual:rules]&&[src isEqualToString:@"built-in"],"bad update with nothing remembered falls back to built-in");
 [@"{\"categories\":{\"evil\":[\"#x\"]}}" writeToFile:update atomically:YES encoding:NSUTF8StringEncoding error:NULL];CHECK(MYBCleanupValidate([NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:update] options:0 error:NULL])==nil,"unknown categories are refused");
 if(fails){fprintf(stderr,"%d failed\n",fails);return 1;}puts("cleanup-rules-native ok");return 0;}}
