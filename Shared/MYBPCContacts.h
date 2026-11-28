#pragma once
// MYbloXX® Private Calls: the contact name for a private number, read from the phone's own contacts, only when the process is already allowed to
// read them (Phone is). Nothing is requested, stored, logged or sent anywhere; no match, or an unclear one, simply means the number is shown.
#import <Contacts/Contacts.h>
static inline NSString *MYBPCContactName(NSString *key){
 if(![key isKindOfClass:NSString.class]||!key.length)return nil;
 if([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts]!=CNAuthorizationStatusAuthorized)return nil;
 NSString *digits=[key hasPrefix:@"+"]?key:[[key componentsSeparatedByString:@":"] lastObject];
 @try{
  CNContactStore *store=[CNContactStore new];
  NSArray *found=[store unifiedContactsMatchingPredicate:[CNContact predicateForContactsMatchingPhoneNumber:[CNPhoneNumber phoneNumberWithStringValue:digits]] keysToFetch:@[[CNContactFormatter descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName]] error:NULL];
  if(found.count!=1)return nil;                                                 // none, or two contacts share it: show the number
  NSString *name=[CNContactFormatter stringFromContact:found.firstObject style:CNContactFormatterStyleFullName];
  return name.length?name:nil;
 }@catch(NSException *e){return nil;}
}
// The same person under another number: the contacts a number belongs to are compared. Used only to decide that a call from another number of a contact that
// is already private is private too. Nothing is stored or sent; answers are remembered in memory for a short time.
static inline NSSet *MYBPCContactIds(NSString *key){
 static NSMutableDictionary *cache;static NSObject *lock;static dispatch_once_t once;
 dispatch_once(&once,^{cache=[NSMutableDictionary dictionary];lock=[NSObject new];});
 if(![key isKindOfClass:NSString.class]||!key.length)return nil;
 if([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts]!=CNAuthorizationStatusAuthorized)return nil;
 NSTimeInterval now=[NSDate timeIntervalSinceReferenceDate];
 @synchronized(lock){NSDictionary *c=cache[key];if(c&&now-[c[@"t"] doubleValue]<120)return c[@"ids"];if(cache.count>400)[cache removeAllObjects];}
 NSMutableSet *ids=[NSMutableSet set];
 @try{
  NSString *digits=[key hasPrefix:@"+"]?key:[[key componentsSeparatedByString:@":"] lastObject];
  NSArray *found=[[CNContactStore new] unifiedContactsMatchingPredicate:[CNContact predicateForContactsMatchingPhoneNumber:[CNPhoneNumber phoneNumberWithStringValue:digits]] keysToFetch:@[CNContactIdentifierKey] error:NULL];
  for(CNContact *c in found)if(c.identifier.length)[ids addObject:c.identifier];
 }@catch(NSException *e){return nil;}
 @synchronized(lock){cache[key]=@{@"ids":ids,@"t":@(now)};}
 return ids;
}
static inline NSDictionary *MYBPCContactEntry(NSArray *effective,NSArray *people,NSString *region){
 NSDictionary *found=nil;
 for(NSArray *forms in people){
  NSMutableSet *ids=[NSMutableSet set];
  for(NSString *form in forms){NSString *key=MYBPCKey(form,region);if(key)[ids unionSet:MYBPCContactIds(key)?:[NSSet set]];}
  if(!ids.count)return nil;                                                     // a person who is not in Contacts: only the number can match
  NSDictionary *hit=nil;
  for(NSDictionary *e in effective){NSSet *theirs=MYBPCContactIds([e objectForKey:@"k"]);if(theirs&&[theirs intersectsSet:ids]){hit=e;break;}}
  if(!hit)return nil;
  if(!found)found=hit;
 }
 return found;
}
