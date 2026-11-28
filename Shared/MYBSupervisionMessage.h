#pragma once
// Branded supervision message (Settings), decided here so it can be tested without UIKit.
//
// Scope: only the supervision MYbloXX® itself created (Legacy Mode's Spoof Supervision). The message is branded only when ALL of these hold:
//   * the MYbloXX supervision record says MYbloXX switched supervision on (owned), and
//   * the supervision file reads as supervised, and
//   * that file carries no organisation or enrolment key (Organization*, ConfigurationURL, ConfigurationSource, SupervisorHost*, MDM*,
//     Support*). Such a key means the notice could be a genuine employer, school or MDM notice, so iOS's own text is left exactly as it is.
//     Other bookkeeping keys iOS keeps there do not matter: the file was not supervised before MYbloXX switched it on (that is what
//     the ownership record proves), so nothing else can have made it a genuine notice.
// An unsupervised device never gets a message from here: when the file does not say supervised there is nothing to brand.
#import <Foundation/Foundation.h>
#import "MYBSupervisionKeys.h"

#define MYB_SUPERVISION_TEXT_ON @"This device is supervised and shielded by MYbloXX®"
#define MYB_SUPERVISION_TEXT_OFF @"MYbloXX® protection is disabled."
// A device that was already supervised before MYbloXX® (or by something else): the text says only what MYbloXX® is doing, never that it supervises the device.
#define MYB_SUPERVISION_TEXT_EXISTING_ON @"This device is supervised. MYbloXX® protection is on."
#define MYB_SUPERVISION_TEXT_EXISTING_LEGACY @"This device is supervised. A MYbloXX® Legacy profile is protecting it."
#define MYB_SUPERVISION_TEXT_LEGACY @"This device is supervised and protected by a MYbloXX® Legacy profile."

static inline BOOL MYBSupervisionBrandable(NSDictionary *details,NSDictionary *record){
 if(![details isKindOfClass:NSDictionary.class]||![record isKindOfClass:NSDictionary.class])return NO;
 if(![record[@"owner"] isEqual:@"net.myxxdev.mybloxx"])return NO;
 if(![details[@"IsSupervised"] boolValue])return NO;
 // iOS keeps unrelated bookkeeping keys in this file, so "only the flag" is not required. What marks a genuine employer, school or MDM
 // notice is an organisation or enrolment key; any of those means the notice is not ours to rewrite.
 for(id key in details){
  if(![key isKindOfClass:NSString.class])return NO;
  NSString *k=key;
  if([k hasPrefix:@"Organization"]||[k hasPrefix:@"ConfigurationURL"]||[k hasPrefix:@"ConfigurationSource"]||[k hasPrefix:@"SupervisorHost"]||[k hasPrefix:@"MDM"]||[k hasPrefix:@"Support"])return NO;
 }
 return YES;
}
// Real protection: native blocking switched on, or a MYbloXX® Legacy profile that iOS reports as installed.
static inline BOOL MYBSupervisionProtected(NSDictionary *state,NSDictionary *profileRecord){
 if([state isKindOfClass:NSDictionary.class]&&[state[@"enabled"] boolValue])return YES;
 NSDictionary *check=[profileRecord isKindOfClass:NSDictionary.class]?profileRecord[@"checks"][@"net.myxxdev.mybloxx"]:nil;
 return [check isKindOfClass:NSDictionary.class]&&[check[@"state"] isEqual:@"installed"];
}
// The text to show, or nil to leave iOS's own text alone.
static inline NSString *MYBSupervisionMessage(NSDictionary *details,NSDictionary *record,NSDictionary *state,NSDictionary *profileRecord){
 if(![details isKindOfClass:NSDictionary.class]||![details[@"IsSupervised"] boolValue])return nil; // an unsupervised device never gets a message from here
 if(!MYBSupervisionBrandable(details,record)){
  // Supervised, but not by MYbloXX®: shown only while MYbloXX® is really protecting, only without management keys, and without claiming ownership.
  if(MYBSupervisionHasManagementKeys(details)||!MYBSupervisionProtected(state,profileRecord))return nil;
  return ([state isKindOfClass:NSDictionary.class]&&[state[@"enabled"] boolValue])?MYB_SUPERVISION_TEXT_EXISTING_ON:MYB_SUPERVISION_TEXT_EXISTING_LEGACY;
 }
 if([state isKindOfClass:NSDictionary.class]&&[state[@"enabled"] boolValue])return MYB_SUPERVISION_TEXT_ON;
 return MYBSupervisionProtected(state,profileRecord)?MYB_SUPERVISION_TEXT_LEGACY:MYB_SUPERVISION_TEXT_OFF;
}
