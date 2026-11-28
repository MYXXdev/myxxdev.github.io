#pragma once
// Bulk Custom Rules: turns pasted or file text into a PREVIEW (what would be added, what is skipped and why) and, after the person
// confirms, one list that is applied by the existing single-transaction `localcustom` action. Nothing here writes a file or runs the
// helper; it is pure so it can be tested natively. Undo records the lists before and after an import and refuses to run when
// the rules have changed since, so it can never overwrite a later edit.
#import <Foundation/Foundation.h>
#define MYB_BULK_LIMIT 20000        // a technical ceiling only (the helper receives each list as one argument); nothing in the UI mentions it
#define MYB_BULK_MAX_INPUT 400000   // characters read from a paste or file
#define MYB_BULK_EXAMPLES 4         // skipped entries named in the preview
static inline BOOL MYBBulkAllDigitsAndDots(NSString *s){
 if(!s.length)return NO;for(NSUInteger i=0;i<s.length;i++){unichar c=[s characterAtIndex:i];if(!((c>='0'&&c<='9')||c=='.'))return NO;}return YES;
}
// One entry to a bare lower-case domain, or nil with a short reason. Accepts a domain, an http(s) address, an Adblock-style
// ||domain^ and a leading *. or dot; drops the path, query, port and trailing dot. Refuses IP addresses and anything else.
static inline NSString *MYBBulkNormalize(NSString *raw,NSString **why){
 NSString *s=[[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
 if(!s.length)return nil;
 for(NSUInteger i=0;i<s.length;i++)if([s characterAtIndex:i]>127){if(why)*why=@"Use the ASCII (xn--) form";return nil;}
 if([s hasPrefix:@"||"])s=[s substringFromIndex:2];
 if([s hasSuffix:@"^"])s=[s substringToIndex:s.length-1];
 NSRange scheme=[s rangeOfString:@"://"];
 if(scheme.location!=NSNotFound){NSString *name=[s substringToIndex:scheme.location];if(![name isEqual:@"http"]&&![name isEqual:@"https"]){if(why)*why=@"Not a website address";return nil;}s=[s substringFromIndex:NSMaxRange(scheme)];}
 NSRange cut=[s rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
 if(cut.location!=NSNotFound)s=[s substringToIndex:cut.location];
 if([s containsString:@"@"]){if(why)*why=@"Contains a user name";return nil;}
 NSRange colon=[s rangeOfString:@":"];
 if(colon.location!=NSNotFound){
  NSString *port=[s substringFromIndex:colon.location+1];
  if(!port.length||port.length>5||[port rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location!=NSNotFound){if(why)*why=@"Not a domain";return nil;}
  s=[s substringToIndex:colon.location];
 }
 while([s hasPrefix:@"*."])s=[s substringFromIndex:2];
 while([s hasPrefix:@"."])s=[s substringFromIndex:1];
 while([s hasSuffix:@"."])s=[s substringToIndex:s.length-1];
 if(!s.length||s.length>253){if(why)*why=s.length?@"Too long":@"Not a domain";return nil;}
 if(MYBBulkAllDigitsAndDots(s)){if(why)*why=@"IP addresses are not domain rules";return nil;}
 if([s rangeOfString:@"."].location==NSNotFound){if(why)*why=@"Needs a dot, like example.com";return nil;}
 NSCharacterSet *safe=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-"];
 for(NSString *label in [s componentsSeparatedByString:@"."]){
  if(!label.length||label.length>63||[label hasPrefix:@"-"]||[label hasSuffix:@"-"]||[label rangeOfCharacterFromSet:safe.invertedSet].location!=NSNotFound){if(why)*why=@"Not a valid domain";return nil;}
 }
 return s;
}
// Splits text into entries: one per line; commas, semicolons and spaces also separate; # ! and // comment lines are ignored; a hosts-file
// line (an IP address followed by names) contributes its names.
static inline NSArray<NSString *> *MYBBulkTokens(NSString *text,NSUInteger *comments){
 NSMutableArray *tokens=[NSMutableArray array];NSUInteger skipped=0;
 NSString *flat=[[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
 NSCharacterSet *breaks=[NSCharacterSet characterSetWithCharactersInString:@" \t,;"];
 for(NSString *line in [flat componentsSeparatedByString:@"\n"]){
  NSString *t=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if(!t.length)continue;
  if([t hasPrefix:@"#"]||[t hasPrefix:@"!"]||[t hasPrefix:@"//"]){skipped++;continue;}
  NSRange hash=[t rangeOfString:@" #"];if(hash.location!=NSNotFound)t=[t substringToIndex:hash.location];
  NSMutableArray *parts=[NSMutableArray array];
  for(NSString *p in [t componentsSeparatedByCharactersInSet:breaks])if(p.length)[parts addObject:p];
  if(parts.count>1&&(MYBBulkAllDigitsAndDots(parts[0])||[parts[0] hasPrefix:@"::"]))[parts removeObjectAtIndex:0];
  [tokens addObjectsFromArray:parts];
 }
 if(comments)*comments=skipped;return tokens;
}
// The preview. `toAllow` picks the list the entries are added to. Entries already in the other list are skipped, never moved.
static inline NSDictionary *MYBBulkPlan(NSString *text,BOOL toAllow,NSArray<NSString *> *blocked,NSArray<NSString *> *allowed){
 NSMutableArray *adds=[NSMutableArray array],*invalid=[NSMutableArray array],*conflicts=[NSMutableArray array],*existing=[NSMutableArray array];
 NSUInteger duplicates=0,overflow=0,comments=0;
 BOOL tooLarge=![text isKindOfClass:NSString.class]||text.length>MYB_BULK_MAX_INPUT;
 NSArray *target=toAllow?allowed:blocked,*other=toAllow?blocked:allowed;
 NSSet *inTarget=[NSSet setWithArray:target?:@[]],*inOther=[NSSet setWithArray:other?:@[]];NSMutableSet *seen=[NSMutableSet set];
 if(!tooLarge){
  for(NSString *token in MYBBulkTokens(text,&comments)){
   NSString *why=nil;NSString *d=MYBBulkNormalize(token,&why);
   if(!d){if(why)[invalid addObject:@{@"text":token.length>60?[token substringToIndex:60]:token,@"reason":why}];continue;}
   if([seen containsObject:d]){duplicates++;continue;}[seen addObject:d];
   if([inTarget containsObject:d]){[existing addObject:d];continue;}
   if([inOther containsObject:d]){[conflicts addObject:d];continue;}
   if((target.count+adds.count)>=MYB_BULK_LIMIT){overflow++;continue;}
   [adds addObject:d];
  }
 }
 NSMutableArray *newTarget=[(target?:@[]) mutableCopy];[newTarget addObjectsFromArray:adds];
 return @{@"add":adds,@"invalid":invalid,@"conflicts":conflicts,@"existing":existing,@"duplicates":@(duplicates),@"overflow":@(overflow),@"comments":@(comments),@"tooLarge":@(tooLarge),
  @"toAllow":@(toAllow),@"blockedAfter":toAllow?(blocked?:@[]):newTarget,@"allowedAfter":toAllow?newTarget:(allowed?:@[])};
}
// Plain-language preview text: counts first, then a few examples of what is skipped. Never more than a handful of entries.
static inline NSString *MYBBulkSummary(NSDictionary *plan){
 BOOL allow=[plan[@"toAllow"] boolValue];NSString *list=allow?@"Allowed":@"Blocked";NSMutableArray *lines=[NSMutableArray array];
 if([plan[@"tooLarge"] boolValue])return @"That text is too large to import. Split it into smaller parts.";
 NSUInteger add=[plan[@"add"] count];
 [lines addObject:add?[NSString stringWithFormat:@"%lu new %@ will be added to %@.",(unsigned long)add,add==1?@"domain":@"domains",list]:[NSString stringWithFormat:@"Nothing new to add to %@.",list]];
 NSUInteger n=[plan[@"existing"] count];if(n)[lines addObject:[NSString stringWithFormat:@"%lu already in %@.",(unsigned long)n,list]];
 n=[plan[@"duplicates"] unsignedIntegerValue];if(n)[lines addObject:[NSString stringWithFormat:@"%lu repeated in the text.",(unsigned long)n]];
 NSArray *conflicts=plan[@"conflicts"];
 if(conflicts.count){NSMutableArray *names=[NSMutableArray array];for(NSUInteger i=0;i<conflicts.count&&i<MYB_BULK_EXAMPLES;i++)[names addObject:conflicts[i]];
  [lines addObject:[NSString stringWithFormat:@"%lu skipped because %@ is in the other list: %@%@.",(unsigned long)conflicts.count,conflicts.count==1?@"it":@"they",[names componentsJoinedByString:@", "],conflicts.count>names.count?@" and more":@""]];}
 NSArray *invalid=plan[@"invalid"];
 if(invalid.count){NSMutableArray *names=[NSMutableArray array];for(NSUInteger i=0;i<invalid.count&&i<MYB_BULK_EXAMPLES;i++)[names addObject:[NSString stringWithFormat:@"%@ (%@)",invalid[i][@"text"],invalid[i][@"reason"]]];
  [lines addObject:[NSString stringWithFormat:@"%lu not valid: %@%@.",(unsigned long)invalid.count,[names componentsJoinedByString:@", "],invalid.count>names.count?@" and more":@""]];}
 n=[plan[@"overflow"] unsignedIntegerValue];if(n)[lines addObject:[NSString stringWithFormat:@"%lu not added because the list is full.",(unsigned long)n]];
 return [lines componentsJoinedByString:@"\n"];
}
// The comma-separated form the helper's transaction takes.
static inline NSString *MYBBulkCSV(NSArray<NSString *> *items){return [items componentsJoinedByString:@","];}
// ---- undo ---------------------------------------------------------------------------------------------------------
static inline NSDictionary *MYBBulkUndoRecord(NSArray *beforeBlocked,NSArray *beforeAllowed,NSDictionary *plan){
 return @{@"beforeBlocked":beforeBlocked?:@[],@"beforeAllowed":beforeAllowed?:@[],@"afterBlocked":plan[@"blockedAfter"]?:@[],@"afterAllowed":plan[@"allowedAfter"]?:@[],@"count":@([plan[@"add"] count]),@"toAllow":plan[@"toAllow"]?:@(NO),@"when":[NSDate date]};
}
// Undo is offered only while the rules are exactly what the import left; any later change makes it unavailable, so it cannot overwrite it.
static inline BOOL MYBBulkUndoAvailable(NSDictionary *record,NSArray *currentBlocked,NSArray *currentAllowed){
 if(![record isKindOfClass:NSDictionary.class]||![record[@"count"] integerValue])return NO;
 return [record[@"afterBlocked"] isEqual:currentBlocked?:@[]]&&[record[@"afterAllowed"] isEqual:currentAllowed?:@[]]&&!([record[@"beforeBlocked"] isEqual:record[@"afterBlocked"]]&&[record[@"beforeAllowed"] isEqual:record[@"afterAllowed"]]);
}
