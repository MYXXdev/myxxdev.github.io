#pragma once
// MYbloXX® Clean Link: removes well-understood tracking parameters from a link the user chose to share. It works on the text of the link itself, so
// unknown parameters, their order, their original percent-encoding and the #fragment stay exactly as they were. Nothing is fetched and nothing is logged.
#import <Foundation/Foundation.h>

// Result keys: clean (NSString), removed (NSArray of parameter NAMES only, never values), changed (NSNumber), note (NSString, why it was left alone, or @"").
static inline NSSet *MYBCleanLinkTrackers(void){
 static NSSet *s;
 if(!s)s=[NSSet setWithArray:@[@"fbclid",@"gclid",@"gclsrc",@"dclid",@"gbraid",@"wbraid",@"msclkid",@"yclid",@"twclid",@"ttclid",@"li_fat_id",@"igshid",@"igsh",@"mc_eid",@"mc_cid",@"_hsenc",@"_hsmi",@"mkt_tok",@"vero_id",@"s_cid",@"cmpid",@"ocid",@"spm",@"scm"]];
 return s;}
// Names that are only tracking on certain sites ("si" is a share tag on YouTube and Spotify, an unrelated value elsewhere).
static inline BOOL MYBCleanLinkSiteTracker(NSString *name,NSString *host){
 if([name isEqualToString:@"si"])return [host hasSuffix:@"youtube.com"]||[host hasSuffix:@"youtu.be"]||[host hasSuffix:@"spotify.com"];
 if([name isEqualToString:@"feature"])return [host hasSuffix:@"youtube.com"]||[host hasSuffix:@"youtu.be"];
 if([name isEqualToString:@"ref_src"]||[name isEqualToString:@"ref_url"]||[name isEqualToString:@"s"]||[name isEqualToString:@"t"])return [host hasSuffix:@"twitter.com"]||[host hasSuffix:@"x.com"];
 return NO;}
// Signed, authenticated, checkout and invitation links are never touched: removing a parameter can break or change them.
static inline BOOL MYBCleanLinkProtected(NSString *name){
 NSString *n=name.lowercaseString;
 if([n hasPrefix:@"x-amz-"]||[n hasPrefix:@"x-goog-"]||[n hasPrefix:@"sig"]||[n hasPrefix:@"token"]||[n hasPrefix:@"auth"]||[n hasPrefix:@"access"]||[n hasPrefix:@"expires"]||[n hasPrefix:@"signature"])return YES;
 for(NSString *k in @[@"key",@"code",@"state",@"nonce",@"session",@"sessionid",@"sid",@"jwt",@"invite",@"invitation",@"password",@"secret",@"hmac",@"policy",@"checksum",@"magic",@"otp"])if([n isEqualToString:k])return YES;
 return NO;}
static inline BOOL MYBCleanLinkProtectedPath(NSString *path){
 NSString *p=path.lowercaseString;
 for(NSString *k in @[@"/checkout",@"/cart",@"/payment",@"/pay/",@"/login",@"/signin",@"/sign-in",@"/oauth",@"/auth",@"/invite",@"/join/",@"/reset",@"/verify",@"/confirm",@"/unsubscribe",@"/billing"])if([p containsString:k])return YES;
 return NO;}
static inline NSDictionary *MYBCleanLinkSame(NSString *input,NSString *note){return @{@"clean":input?:@"",@"removed":@[],@"changed":[NSNumber numberWithBool:NO],@"note":note};}
static inline NSDictionary *MYBCleanLink(NSString *input){
 NSString *text=[input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSString *lower=text.lowercaseString;
 if(!([lower hasPrefix:@"http://"]||[lower hasPrefix:@"https://"])||[text rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location!=NSNotFound)return MYBCleanLinkSame(input,@"Not a web link, left as it was.");
 NSString *fragment=@"",*rest=text;
 NSRange hash=[rest rangeOfString:@"#"];
 if(hash.location!=NSNotFound){fragment=[rest substringFromIndex:hash.location];rest=[rest substringToIndex:hash.location];}
 NSRange q=[rest rangeOfString:@"?"];
 if(q.location==NSNotFound)return MYBCleanLinkSame(input,@"No tracking parameters found.");
 NSString *base=[rest substringToIndex:q.location],*query=[rest substringFromIndex:q.location+1];
 NSString *afterScheme=[base substringFromIndex:[base rangeOfString:@"://"].location+3];
 NSRange slash=[afterScheme rangeOfString:@"/"];
 NSString *authority=slash.location==NSNotFound?afterScheme:[afterScheme substringToIndex:slash.location];
 NSString *path=slash.location==NSNotFound?@"":[afterScheme substringFromIndex:slash.location];
 if([authority containsString:@"@"])return MYBCleanLinkSame(input,@"Link contains a sign-in, left as it was.");
 NSString *host=[[[authority componentsSeparatedByString:@":"] firstObject] lowercaseString];
 if(MYBCleanLinkProtectedPath(path))return MYBCleanLinkSame(input,@"Sign-in, checkout or invitation link, left as it was.");
 NSArray *pairs=[query componentsSeparatedByString:@"&"];
 for(NSString *pair in pairs){NSString *name=[[pair componentsSeparatedByString:@"="] firstObject];NSString *decoded=name.stringByRemovingPercentEncoding?:name;if(MYBCleanLinkProtected(decoded))return MYBCleanLinkSame(input,@"Signed or private link, left as it was.");}
 NSMutableArray *kept=[NSMutableArray array],*removed=[NSMutableArray array];
 for(NSString *pair in pairs){
  NSString *name=[[pair componentsSeparatedByString:@"="] firstObject];
  NSString *decoded=(name.stringByRemovingPercentEncoding?:name).lowercaseString;
  BOOL track=[decoded hasPrefix:@"utm_"]||[MYBCleanLinkTrackers() containsObject:decoded]||MYBCleanLinkSiteTracker(decoded,host);
  if(track)[removed addObject:decoded];else if(pair.length)[kept addObject:pair];}
 if(!removed.count)return MYBCleanLinkSame(input,@"No tracking parameters found.");
 NSString *clean=kept.count?[NSString stringWithFormat:@"%@?%@%@",base,[kept componentsJoinedByString:@"&"],fragment]:[NSString stringWithFormat:@"%@%@",base,fragment];
 return @{@"clean":clean,@"removed":removed,@"changed":[NSNumber numberWithBool:YES],@"note":@""};}
