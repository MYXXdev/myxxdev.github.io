#import "PCCall.h"
#import "PCStore.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import "../../Shared/MYBConnectivity.h"
#import "../../Shared/MYBPrivateCalls.h"
#import "../../Shared/MYBPCContacts.h"

#define SEND(ret, ...) ((ret (*)(id, SEL, ##__VA_ARGS__))objc_msgSend)

static NSMutableSet<NSString *> *Seen;          // calls already counted as seen, so the report counts calls and not looks
static NSMutableSet<NSString *> *Handled;       // call identifiers that already had their one action (identifiers only, never numbers)
static NSMutableDictionary *Counts;
static BOOL Installed;

static BOOL Has(id object, SEL selector) { return object && [object respondsToSelector:selector]; }
static BOOL BoolOf(id object, SEL selector, BOOL fallback) { return Has(object, selector) ? SEND(BOOL)(object, selector) : fallback; }
static NSString *Identifier(id call) {
    if (Has(call, NSSelectorFromString(@"uniqueProxyIdentifier"))) { id v = SEND(id)(call, NSSelectorFromString(@"uniqueProxyIdentifier")); if ([v isKindOfClass:NSString.class]) return v; }
    if (Has(call, NSSelectorFromString(@"callUUID"))) { id v = SEND(id)(call, NSSelectorFromString(@"callUUID")); if ([v isKindOfClass:NSString.class]) return v; }
    return nil;
}
static void Count(NSString *key) {
    Counts[key] = @([Counts[key] integerValue] + 1);
    PCPublish(@"com.apple.InCallService", @"MYBPCCallStatus", @{@"observer": @YES, @"store": PCStoreState(), @"counts": [Counts copy], @"time": @((long long)NSDate.date.timeIntervalSince1970)});
}
// One person per handle: the strings that describe that person (value, normalised value).
static NSArray *PeopleOf(id call, NSString **regionOut) {
    NSMutableArray *people = [NSMutableArray array];
    NSMutableArray *handles = [NSMutableArray array];
    SEL set = NSSelectorFromString(@"remoteParticipantHandles"), one = NSSelectorFromString(@"handle");
    id many = Has(call, set) ? SEND(id)(call, set) : nil;
    if ([many isKindOfClass:NSSet.class] && [many count]) [handles addObjectsFromArray:[many allObjects]];
    else if (Has(call, one)) { id h = SEND(id)(call, one); if (h) [handles addObject:h]; }
    for (id h in handles) {
        NSMutableArray *forms = [NSMutableArray array];
        for (NSString *name in @[@"value", @"normalizedValue"]) {
            SEL s = NSSelectorFromString(name);
            id v = Has(h, s) ? SEND(id)(h, s) : nil;
            if ([v isKindOfClass:NSString.class] && [v length]) [forms addObject:v];
        }
        SEL iso = NSSelectorFromString(@"isoCountryCode");
        if (regionOut && !*regionOut && Has(h, iso)) { id v = SEND(id)(h, iso); if ([v isKindOfClass:NSString.class] && [v length] == 2) *regionOut = v; }
        [people addObject:forms];
    }
    return people;
}
static BOOL OrdinaryPhoneCall(id call) {
    id provider = Has(call, NSSelectorFromString(@"provider")) ? SEND(id)(call, NSSelectorFromString(@"provider")) : nil;
    SEL telephony = NSSelectorFromString(@"isTelephonyProvider");
    if (!Has(provider, telephony) || !SEND(BOOL)(provider, telephony)) return NO;            // unknown means "not an ordinary phone call"
    if (BoolOf(call, NSSelectorFromString(@"isVoIPCall"), NO) || BoolOf(call, NSSelectorFromString(@"isConversation"), NO)) return NO;
    return YES;
}
// "Answered" is read from the call's own status (1 active, 2 on hold; 4 is ringing). The yes/no flags are not used: a ringing call can report connected.
static int StatusOf(id call) {
    for (NSString *name in @[@"status", @"callStatus"]) { SEL sel = NSSelectorFromString(name); if (Has(call, sel)) return ((int (*)(id, SEL))objc_msgSend)(call, sel); }
    return -1;
}
static BOOL IsAnswered(id call) { int st = StatusOf(call); return st == 1 || st == 2; }
static void Evaluate(id center, id call, NSArray *current) {
    NSString *identifier = Identifier(call);
    if (!identifier.length) { Count(@"noIdentifier"); return; }                              // cannot be scoped to this one call: leave it alone
    BOOL incoming = BoolOf(call, NSSelectorFromString(@"isIncoming"), NO);
    if (incoming && ![Seen containsObject:identifier]) { [Seen addObject:identifier]; Count(@"incomingSeen"); Count([NSString stringWithFormat:@"status%d", StatusOf(call)]); if (!PCSwitchOn()) Count(@"switchOff"); }
    if (!PCSwitchOn()) return;
    BOOL connectedNow = IsAnswered(call);
    BOOL connecting = BoolOf(call, NSSelectorFromString(@"isConnecting"), NO);
    BOOL answered = connectedNow;                                                            // "connecting" alone is not answered: a ringing call can report it
    BOOL emergency = BoolOf(call, NSSelectorFromString(@"isEmergency"), NO) || BoolOf(call, NSSelectorFromString(@"isEmergencyCall"), NO) || BoolOf(call, NSSelectorFromString(@"isSOS"), NO);
    BOOL other = NO;
    for (id c in current) {
        NSString *cid = Identifier(c);
        if (c == call || (cid && [cid isEqual:identifier])) continue;                        // the same call under another object is not "another call"
        if (IsAnswered(c)) other = YES;
    }
    NSString *region = nil;
    NSArray *people = PeopleOf(call, &region);
    NSDictionary *entry = MYBPCEntryForHandles(PCEffectiveEntries(), people, region ?: PCRegion());
    if (!entry) { if (!people.count) Count(@"noIdentity"); else if (incoming && ![Handled containsObject:[identifier stringByAppendingString:@"/nomatch"]]) { [Handled addObject:[identifier stringByAppendingString:@"/nomatch"]]; Count(@"noMatch"); } return; }
    BOOL ordinary = OrdinaryPhoneCall(call);
    MYBPCDecision decision = MYBPCDecide(entry, YES, incoming, answered, ordinary, emergency, [Handled containsObject:identifier], other);
    if (decision == MYBPCNothing) {
        NSString *why = answered ? @"holdAnswered" : emergency ? @"holdEmergency" : other ? @"holdOtherCall" : [Handled containsObject:identifier] ? @"holdHandled" : @"holdOther";
        if (![Handled containsObject:[identifier stringByAppendingString:@"/why"]]) { [Handled addObject:[identifier stringByAppendingString:@"/why"]]; Count(why); if (connecting) Count(@"holdSawConnecting"); }
        if (incoming && !ordinary && ![Handled containsObject:[identifier stringByAppendingString:@"/odd"]]) { [Handled addObject:[identifier stringByAppendingString:@"/odd"]]; Count(@"matchedNotOrdinary"); } return; }
    Count(decision == MYBPCDoMute ? @"matchedMute" : @"matchedDecline");
    [Handled addObject:identifier];                                                          // marked before acting: a second notification can never repeat it
    SEL suppress = NSSelectorFromString(@"suppressRingtone");
    if (Has(call, suppress) && !BoolOf(call, NSSelectorFromString(@"shouldSuppressRingtone"), NO)) SEND(void)(call, suppress);   // silent first, whatever follows
    if (decision == MYBPCDoMute) { Count(Has(call, suppress) ? @"muted" : @"muteUnsupported"); return; }
    SEL disconnect = NSSelectorFromString(@"disconnectCall:"), answer = NSSelectorFromString(@"answerCall:");
    if (!Has(center, disconnect)) { Count(@"declineUnsupported"); return; }
    // the last look before acting: still this call, still ringing, still not answered
    if (!BoolOf(call, NSSelectorFromString(@"isIncoming"), NO) || IsAnswered(call)) { Count(@"changedBeforeDecline"); return; }
    if (decision == MYBPCDoHangup && Has(center, answer)) {
        SEND(void, id)(center, answer, call);                                                // picked up, then ended at once
        Count(@"hungUp");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ @try { SEND(void, id)(center, disconnect, call); } @catch (NSException *e) { (void)e; } });
        return;
    }
    SEND(void, id)(center, disconnect, call);
    Count(decision == MYBPCDoHangup ? @"hangUpUnsupportedDeclined" : @"declined");
}
static void EvaluateAll(void) {
    @try {
        Class centerClass = objc_getClass("TUCallCenter");
        if (!centerClass || !Has(centerClass, NSSelectorFromString(@"sharedInstance"))) return;
        id center = SEND(id)(centerClass, NSSelectorFromString(@"sharedInstance"));
        SEL incomingSel = NSSelectorFromString(@"incomingCalls"), currentSel = NSSelectorFromString(@"currentCalls");
        NSArray *incoming = Has(center, incomingSel) ? SEND(id)(center, incomingSel) : nil;
        NSArray *current = Has(center, currentSel) ? SEND(id)(center, currentSel) : @[];
        if (![incoming isKindOfClass:NSArray.class] || !incoming.count) {
            // calls that ended are forgotten so the set stays small
            if (Handled.count > 64) [Handled removeAllObjects];
            return;
        }
        for (id call in incoming) Evaluate(center, call, current);
        static BOOL again;                                                                   // a ringing call is looked at again for a few seconds: its number can arrive a moment after the call does
        if (!again) { again = YES; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ again = NO; EvaluateAll(); }); }
    } @catch (NSException *e) { (void)e; }
}
static NSString *SymbolName(const char *symbol, NSString *fallback) {
    void *p = dlsym(RTLD_DEFAULT, symbol);
    NSString *name = p ? *(__unsafe_unretained NSString **)p : nil;
    return [name isKindOfClass:NSString.class] ? name : fallback;
}
void PCCallInstall(void) {
    MYBPCContactFallback = MYBPCContactEntry;                                                // another number of a private contact is the same person
    if (Installed) return;
    Handled = [NSMutableSet set];
    Seen = [NSMutableSet set];
    Counts = [NSMutableDictionary dictionary];
    Class centerClass = objc_getClass("TUCallCenter"), callClass = objc_getClass("TUCall");
    BOOL ok = centerClass && callClass && class_getInstanceMethod(callClass, NSSelectorFromString(@"suppressRingtone")) && class_getInstanceMethod(centerClass, NSSelectorFromString(@"disconnectCall:")) && class_getInstanceMethod(centerClass, NSSelectorFromString(@"incomingCalls"));
    PCPublish(@"com.apple.InCallService", @"MYBPCCallStatus", @{@"observer": @(ok), @"store": PCStoreState(), @"counts": @{}, @"time": @((long long)NSDate.date.timeIntervalSince1970)});
    if (!ok) return;                                                                         // a different iOS build: normal call handling, nothing hooked
    Installed = YES;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[SymbolName("TUCallCenterCallStatusChangedNotification", @"TUCallCenterCallStatusChangedNotification"), SymbolName("TUCallCenterCallerIDChangedNotification", @"TUCallCenterCallerIDChangedNotification")])
        [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; EvaluateAll(); }];
    static int token = 0;
    notify_register_dispatch(MYB_PRIV_NOTIFY, &token, dispatch_get_main_queue(), ^(int t) { (void)t; PCReload(); PCPublish(@"com.apple.InCallService", @"MYBPCCallStatus", @{@"observer": @YES, @"store": PCStoreState(), @"counts": [Counts copy], @"time": @((long long)NSDate.date.timeIntervalSince1970)}); });
    dispatch_async(dispatch_get_main_queue(), ^{ EvaluateAll(); });
}
