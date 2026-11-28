// What marks a device as managed by someone else. iOS keeps unrelated bookkeeping keys (CloudConfigurationUIComplete and similar) in
// CloudConfigurationDetails.plist even on an ordinary, unmanaged iPhone, so their presence means nothing. An organisation, enrolment or MDM key does.
#import <Foundation/Foundation.h>
static inline BOOL MYBSupervisionHasManagementKeys(NSDictionary *details){
 if(![details isKindOfClass:NSDictionary.class])return NO;
 for(id key in details){
  if(![key isKindOfClass:NSString.class])return YES;
  NSString *k=key;
  if([k hasPrefix:@"Organization"]||[k hasPrefix:@"ConfigurationURL"]||[k hasPrefix:@"ConfigurationSource"]||[k hasPrefix:@"SupervisorHost"]||[k hasPrefix:@"MDM"]||[k hasPrefix:@"Support"])return YES;
 }
 return NO;
}
