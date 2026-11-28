// Private Calls: the root side of the one store. Phone cannot always write the privacy file, so it leaves a request in its own preferences and
// posts a notification; this applies it through the same function Settings uses. It also merges the r18 Phone list once. Numbers are never logged.
#import "../Shared/MYBPrivateCallsStore.h"
static NSString *MYBPCStoreFile(void){return MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.privacy.plist");}
static NSString *MYBPCStampFile(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/PrivateCallsReset.plist");}
static int MYBPCApplyNow(void){
 NSDictionary *phone=[NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/Preferences/com.apple.mobilephone.plist")];
 NSArray *queue=[phone[MYB_PC_PHONE_QUEUE] isKindOfClass:NSArray.class]?phone[MYB_PC_PHONE_QUEUE]:nil,*old=[phone[MYB_PC_PHONE_LOG] isKindOfClass:NSArray.class]?phone[MYB_PC_PHONE_LOG]:nil;
 BOOL failed=NO;int n=MYBPCApplyPending(MYBPCStoreFile(),MYBPCStampFile(),queue,old,&failed);
 if(failed){logLine(@"PRIVATE_CALLS: the store could not be updated; nothing was changed");return 74;}
 if(n)notify_post("net.myxxdev.mybloxx.privacy.changed");
 return 0;
}
// The daemon wakes on Phone's request and otherwise checks every half minute. Cheap: one small plist read.
static int MYBPCRequestToken=-1;
static void MYBPCWatchPrepare(void){if(MYBPCRequestToken<0)notify_register_check(MYB_PC_REQUEST_NOTIFY,&MYBPCRequestToken);}
static BOOL MYBPCRequestPending(void){int dirty=0;return MYBPCRequestToken>=0&&notify_check(MYBPCRequestToken,&dirty)==0&&dirty;}
