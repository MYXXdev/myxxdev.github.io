// MYbloXX Private Calls, call service part.
// A private call can only vanish completely if it is stopped in the system's call service before the phone shows anything. The call service asks its
// own call filter "should this incoming call be filtered?" for every incoming call; a filtered call is rejected there, with no ringing, no screen, no
// banner and no missed-call notice, which is how the system's own blocking works. This part answers YES for a number on the private list, and otherwise
// leaves the filter's own answer alone. It reads only the call's number to compare it with the list; it writes nothing about any call.
// It also reports class and method names (and plain counters, never a number or a name) to Settings, so it can be checked from Copy Calls Diagnostics.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <unistd.h>
#import <string.h>
#import <roothide.h>
#import "../../Shared/MYBCallServiceChannel.h"
#import "../../Shared/MYBPrivateCallsStore.h"
#import "../../Shared/MYBFirewallList.h"
#import "../../Shared/MYBJunkCallers.h"
#import "../../Shared/MYBProtectionStats.h"

static NSString *const Domain = @"net.myxxdev.mybloxx.callservice";

// ---- the stop ----------------------------------------------------------------------------------------------------------------------------
static NSObject *Lock;
static NSMutableDictionary *Counters;
static NSString *BaseText = @"";
static NSArray *Cached; static NSTimeInterval CachedAt; static BOOL SwitchOn; static NSString *Source = @"none";
static const char *JunkRecords; static size_t JunkCount;   // Mikey's own bulk Known Junk Callers dataset, mmapped once at install time
static void Count(NSString *key) { @synchronized (Lock) { Counters[key] = @([Counters[key] intValue] + 1); } }
static void Republish(void) {
    NSString *text;
    @synchronized (Lock) { text = [BaseText stringByAppendingFormat:@"counters: %@\n", [[Counters description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
    MYBCSCPublish(text);
    CFPreferencesSetAppValue(MYB_CSC_OWN_KEY, (__bridge CFStringRef)text, MYB_CSC_OWN_DOMAIN);
    CFPreferencesAppSynchronize(MYB_CSC_OWN_DOMAIN);
}
static NSString *const PrivacyFile = @"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.privacy.plist";
static NSString *const PrivacyDomain = @"net.myxxdev.mybloxx.privacy";
// The private list and its switch: from the preference file, or when this process may not read it, from the preference service.
static void Reload(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PrivacyFile];
    NSArray *log = nil; id sw = nil; NSString *source = @"file";
    if ([prefs isKindOfClass:NSDictionary.class]) { log = MYBPCStoreLog(PrivacyFile); sw = prefs[MYB_PC_KEY_SWITCH]; }
    else {
        source = @"service";
        CFPreferencesAppSynchronize((__bridge CFStringRef)PrivacyDomain);
        id l = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)MYB_PC_KEY_LOG, (__bridge CFStringRef)PrivacyDomain));
        log = [l isKindOfClass:NSArray.class] ? l : nil;
        sw = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)MYB_PC_KEY_SWITCH, (__bridge CFStringRef)PrivacyDomain));
        if (!log) source = @"unreadable";
    }
    NSArray *effective = MYBPCEffective(log ?: @[], nil);
    @synchronized (Lock) { Cached = effective; SwitchOn = [sw isKindOfClass:NSNumber.class] && [sw boolValue]; Source = source; CachedAt = NSDate.timeIntervalSinceReferenceDate; Counters[@"listSize"] = @(effective.count); }
}
static id Get(id object, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (!object || ![object respondsToSelector:sel]) return nil;
    @try { return [object valueForKey:name]; } @catch (NSException *e) { (void)e; return nil; }
}
// What to do with this incoming call: 0 nothing, 1 reject it silently (Decline), 2 let it ring for the caller but show nothing here (Mute), 3 answer and
// end it at once with nothing shown (Hang up). Anything unclear is 0, so a call is only ever touched on a clear match.
static BOOL CanAnswerHere(id call);
static int Decide(id call) {
    @try {
        Count(@"asked");
        NSArray *entries; BOOL on;
        // Where the list comes from, freshest first: the live copy in the preference service (kept current by every writer), then the mailbox, then the
        // old file-backed preference (which can be stale until a userspace reboot, so it is only the last resort).
        NSString *box = nil; NSString *from = nil;
        CFPreferencesAppSynchronize(MYB_CSL_LIVE_DOMAIN);
        id live = CFBridgingRelease(CFPreferencesCopyAppValue(MYB_CSL_LIVE_KEY, MYB_CSL_LIVE_DOMAIN));
        if ([live isKindOfClass:NSString.class] && [live hasPrefix:@"sw="]) { box = live; from = @"live"; }
        else { Count(@"noLive"); box = MYBCSCReadFrom(MYB_CSL_NAME); if (box) from = @"mailbox"; }
        if (box) {
            NSMutableArray *list = [NSMutableArray array]; on = NO;
            for (NSString *line in [box componentsSeparatedByString:@"\n"]) {
                if ([line hasPrefix:@"sw="]) { on = [line hasSuffix:@"1"]; continue; }
                NSArray *parts = [line componentsSeparatedByString:@"\t"];
                if (parts.count == 2 && [parts[0] length]) [list addObject:@{@"k": parts[0], @"a": parts[1], @"d": @"", @"t": @0, @"on": @YES}];
            }
            entries = list;
            Count([@"from_" stringByAppendingString:from]);
            @synchronized (Lock) { Source = from; Counters[@"listSize"] = @(list.count); }
        } else {
            Count(@"noMailbox");
            notify_post(MYB_CSL_NEED);                                                               // ask SpringBoard to publish it
            Reload();
            @synchronized (Lock) { entries = Cached; on = SwitchOn; }
        }
        if (!on) { Count(@"switchOff"); return 0; }
        if (!entries.count) { Count(@"emptyList"); return 0; }
        id provider = Get(call, @"provider");
        id telephony = Get(provider, @"isTelephonyProvider");
        if (telephony && ![telephony boolValue]) { Count(@"notPhoneProvider"); return 0; }       // FaceTime and other apps' calls are left alone
        NSMutableArray *people = [NSMutableArray array]; NSString *region = nil;
        id many = Get(call, @"remoteParticipantHandles");
        NSMutableArray *handles = [NSMutableArray array];
        if ([many isKindOfClass:NSSet.class] && [many count]) [handles addObjectsFromArray:[many allObjects]];
        else if ([many isKindOfClass:NSArray.class] && [many count]) [handles addObjectsFromArray:many];
        else { id one = Get(call, @"handle"); if (one) [handles addObject:one]; }
        for (id h in handles) {
            NSMutableArray *forms = [NSMutableArray array];
            for (NSString *name in @[@"value", @"normalizedValue"]) { id v = Get(h, name); if ([v isKindOfClass:NSString.class] && [v length]) [forms addObject:v]; }
            id iso = Get(h, @"isoCountryCode");
            if (!region && [iso isKindOfClass:NSString.class] && [iso length] == 2) region = iso;
            for (NSString *f in forms) if (MYBPCIsProtectedNumber(f)) { Count(@"emergency"); return 0; }
            [people addObject:forms];
        }
        if (!people.count) { Count(@"noIdentity"); return 0; }
        NSDictionary *entry = MYBPCEntryForHandles(entries, people, region ?: [NSLocale.currentLocale objectForKey:NSLocaleCountryCode]);
        if (!entry) { Count(@"noMatch"); return 0; }
        Count(@"matched");
        id action = entry[@"a"];
        Count([NSString stringWithFormat:@"matched_%@", action ?: @"mute"]);
        if ([action isEqual:MYB_PC_ACTION_DECLINE]) return 1;
        if ([action isEqual:MYB_PC_ACTION_HANGUP]) return CanAnswerHere(call) ? 3 : (Count(@"hangupAsDecline"), 1);   // cannot answer quietly: reject quietly instead
        return 2;
    } @catch (NSException *e) { (void)e; Count(@"error"); return 0; }
}

// Call Firewall: a second, entirely independent decision, read from its own live channel (MYB_FWL_LIVE_DOMAIN/MYB_FWL_NAME -- its own switch, its own
// list, never Private Calls' PrivacyFile or MYB_CSL_*). Only ever consulted when Private Calls itself had nothing to say for this call, so one feature
// being on never changes how the other decides, and a number can be handled by either, both, or neither without the two ever needing to agree.
static int FirewallDecide(id call) {
    @try {
        Count(@"fwAsked");
        CFPreferencesAppSynchronize(MYB_FWL_LIVE_DOMAIN);
        id live = CFBridgingRelease(CFPreferencesCopyAppValue(MYB_FWL_LIVE_KEY, MYB_FWL_LIVE_DOMAIN));
        NSString *text = nil;
        if ([live isKindOfClass:NSString.class] && [live hasPrefix:@"sw="]) { text = live; Count(@"fwFromLive"); }
        else { text = MYBCSCReadFrom(MYB_FWL_NAME); if (text) Count(@"fwFromMailbox"); }
        if (!text) { Count(@"fwNoData"); notify_post(MYB_FWL_NEED); return 0; }
        NSArray *entries = nil;
        NSDictionary *settings = MYBFWParsePublished(text, &entries);
        if (![settings[MYB_FW_KEY_SWITCH] boolValue]) { Count(@"fwSwitchOff"); return 0; }
        id provider = Get(call, @"provider");
        id telephony = Get(provider, @"isTelephonyProvider");
        if (telephony && ![telephony boolValue]) { Count(@"fwNotPhoneProvider"); return 0; }       // FaceTime and other apps' calls are left alone
        NSMutableArray *people = [NSMutableArray array]; NSString *region = nil;
        id many = Get(call, @"remoteParticipantHandles");
        NSMutableArray *handles = [NSMutableArray array];
        if ([many isKindOfClass:NSSet.class] && [many count]) [handles addObjectsFromArray:[many allObjects]];
        else if ([many isKindOfClass:NSArray.class] && [many count]) [handles addObjectsFromArray:many];
        else { id one = Get(call, @"handle"); if (one) [handles addObject:one]; }
        for (id h in handles) {
            NSMutableArray *forms = [NSMutableArray array];
            for (NSString *name in @[@"value", @"normalizedValue"]) { id v = Get(h, name); if ([v isKindOfClass:NSString.class] && [v length]) [forms addObject:v]; }
            id iso = Get(h, @"isoCountryCode");
            if (!region && [iso isKindOfClass:NSString.class] && [iso length] == 2) region = iso;
            for (NSString *f in forms) if (MYBPCIsProtectedNumber(f)) { Count(@"fwEmergency"); return 0; }
            [people addObject:forms];
        }
        NSString *deviceRegion = region ?: [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];
        BOOL unknownCaller = !people.count;                                                        // no usable number at all: a true no-caller-ID call
        NSDictionary *entry = unknownCaller ? nil : MYBPCEntryForHandles(entries, people, deviceRegion);
        NSString *key = nil;
        if (!unknownCaller) for (NSArray *forms in people) { for (NSString *f in forms) { NSString *k = MYBPCKey(f, deviceRegion); if (k) { key = k; break; } } if (key) break; }
        MYBFWDecision decision = MYBFWDecide(settings, entry, key, unknownCaller, YES, YES, NO, YES, NO, NO, NO);
        // Mikey's own bulk Known Junk Callers dataset (Shared/MYBJunkCallers.h, ~1.1M numbers) -- consulted only as a last-resort fallback, once
        // every rule above (an explicit entry, a range, Allow List Mode, International Block) has had nothing to say. A number explicitly on the
        // user's own list, in either direction, always takes precedence over this bundled, unreviewed-by-hand dataset.
        if (decision == MYBFWNothing && !unknownCaller && key.length && JunkRecords && [[settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ON] boolValue]) {
            Count(@"jcChecked");
            @try {
                if (MYBJCIsListed(JunkRecords, JunkCount, key)) {
                    Count(@"jcMatched");
                    decision = MYBFWFromAction([settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ACTION]);
                }
            } @catch (NSException *e) { (void)e; Count(@"jcError"); }
        }
        int result = 0;
        if (decision == MYBFWDoDecline) result = 1;
        else if (decision == MYBFWDoHangup) result = CanAnswerHere(call) ? 3 : (Count(@"fwHangupAsDecline"), 1);
        else if (decision == MYBFWDoMute) result = 2;
        if (result) Count([NSString stringWithFormat:@"fwMatched_%d", result]);
        return result;
    } @catch (NSException *e) { (void)e; Count(@"fwError"); return 0; }
}

// Calls that are being handled quietly, remembered by object and by identifier, so the screens that would show them can be told to stay away.
static NSMapTable *Modes; static NSMutableDictionary *ModeById;
static NSString *IdOf(id call) {
    for (NSString *name in @[@"uniqueProxyIdentifier", @"callUUID", @"uniqueId", @"uuid"]) { id v = Get(call, name); if ([v isKindOfClass:NSString.class] && [v length]) return v; if ([v respondsToSelector:@selector(UUIDString)]) return [v UUIDString]; }
    return nil;
}
static void Remember(id call, int mode) {
    @synchronized (Lock) {
        if (!Modes) { Modes = [NSMapTable weakToStrongObjectsMapTable]; ModeById = [NSMutableDictionary dictionary]; }
        [Modes setObject:@(mode) forKey:call];
        NSString *ident = IdOf(call); if (ident) ModeById[ident] = @[@(mode), @(NSDate.timeIntervalSinceReferenceDate)];
        for (NSString *k in ModeById.allKeys) if (NSDate.timeIntervalSinceReferenceDate - [ModeById[k][1] doubleValue] > 600) [ModeById removeObjectForKey:k];
    }
}
static int ModeOf(id call) {
    if (!call) return 0;
    @synchronized (Lock) {
        id m = [Modes objectForKey:call]; if (m) return [m intValue];
        NSString *ident = IdOf(call); NSArray *e = ident ? ModeById[ident] : nil; return e ? [e[0] intValue] : 0;
    }
}
// The request that answers a call: TUAnswerRequest, tied to this call's identifier when it can be (it has initWithUniqueProxyIdentifier:), else plain init.
static id AnswerRequestFor(id call) {
    @try {
        Class cls = NSClassFromString(@"TUAnswerRequest");
        if (!cls) {
            unsigned n = 0; Class *all = objc_copyClassList(&n);
            for (unsigned i = 0; i < n && !cls; i++) { const char *c = class_getName(all[i]); size_t l = strlen(c); if (l > 13 && !strcmp(c + l - 13, "AnswerRequest") && (c[0] == 'T' || c[0] == 'C')) cls = all[i]; }
            free(all);
        }
        if (!cls) return nil;
        id ident = Get(call, @"uniqueProxyIdentifier"); id req = nil;
        SEL withId = NSSelectorFromString(@"initWithUniqueProxyIdentifier:");
        if ([ident isKindOfClass:NSString.class] && [cls instancesRespondToSelector:withId]) req = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], withId, ident);
        if (!req) { SEL withCall = NSSelectorFromString(@"initWithCall:"); if ([cls instancesRespondToSelector:withCall]) req = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], withCall, call); }
        if (!req) req = [[cls alloc] init];
        return req;
    } @catch (NSException *e) { (void)e; return nil; }
}
// Answering must happen on the call service's own serial queue (the one it calls the filter on): its call methods assert that, and the first try, from the
// main queue, crashed the service. The queue is taken from the filter call itself, and anything that is not a plain private serial queue is refused.
typedef dispatch_queue_t (*CurrentQueueFn)(void);
static dispatch_queue_t CurrentQueue(void) {
    static CurrentQueueFn fn; static BOOL looked;
    if (!looked) { looked = YES; fn = (CurrentQueueFn)dlsym(RTLD_DEFAULT, "dispatch_get_current_queue"); }
    return fn ? fn() : NULL;
}
static NSString *const QuickBuild = @"r46";
static BOOL QuickOff;                                       // set at start when an earlier try of this build crashed the service
static BOOL SafeQueue(dispatch_queue_t q) {
    if (!q) return NO;
    const char *label = dispatch_queue_get_label(q);
    NSString *text = label ? @(label) : @"";
    @synchronized (Lock) { Counters[@"hangupQueue"] = text.length ? text : @"unnamed"; }
    if (!text.length || [text hasPrefix:@"com.apple.root."] || [text isEqualToString:@"com.apple.main-thread"]) return NO;
    return YES;
}
static BOOL CanAnswerHere(id call) {
    if (QuickOff) { Count(@"quickOffAfterCrash"); return NO; }
    if (![call respondsToSelector:NSSelectorFromString(@"answerWithRequest:")]) { Count(@"noAnswerSelector"); return NO; }
    if (![call respondsToSelector:NSSelectorFromString(@"disconnect")]) { Count(@"noDisconnectSelector"); return NO; }
    if (!NSClassFromString(@"TUAnswerRequest")) { Count(@"noAnswerRequestClass"); return NO; }
    if (!SafeQueue(CurrentQueue())) { Count(@"noSafeQueue"); return NO; }
    return YES;
}
// Hang up: the call is picked up and ended at once, from inside the call service, so no screen ever opens. A marker is written before the try and removed
// after it; if the service ever dies in between, the next start sees the marker and this build stops trying (Hang up then declines quietly instead).
// Answering a call opens its audio session, which is what makes iOS show the microphone recording indicator (the Dynamic Island ring). That is a true,
// system-drawn indicator of real microphone activation, not a bug, and the only ways to hide it are the techniques spyware uses to hide its own
// surveillance, which this build will not do. What it CAN do honestly is keep that window as short as possible: disconnect the instant iOS itself marks
// the call connected, rather than guessing a fixed delay. QuickDisconnectIfDue (below) is called from that real connection notification; this function
// only answers and arms a short safety timer in case that notification never arrives for some reason.
static NSMapTable *QuickQueues;
static void QuickDisconnectIfDue(id call) {
    dispatch_queue_t queue; @synchronized (Lock) { queue = QuickQueues ? [QuickQueues objectForKey:call] : nil; if (queue) [QuickQueues removeObjectForKey:call]; }
    if (!queue) return;
    dispatch_async(queue, ^{
        @try { ((void (*)(id, SEL))objc_msgSend)(call, NSSelectorFromString(@"disconnect")); Count(@"quickDisconnected"); } @catch (NSException *e) { (void)e; Count(@"quickDisconnectError"); }
        CFPreferencesSetAppValue(CFSTR("MYBQuickTry"), NULL, MYB_CSC_OWN_DOMAIN); CFPreferencesAppSynchronize(MYB_CSC_OWN_DOMAIN);
        Republish();
    });
}
static void QuickHangup(id call, dispatch_queue_t queue) {
    if (!queue) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), queue, ^{
        @try {
            id request = AnswerRequestFor(call); if (!request) { Count(@"noAnswerRequest"); return; }
            CFPreferencesSetAppValue(CFSTR("MYBQuickTry"), (__bridge CFStringRef)QuickBuild, MYB_CSC_OWN_DOMAIN); CFPreferencesAppSynchronize(MYB_CSC_OWN_DOMAIN);
            @synchronized (Lock) { if (!QuickQueues) QuickQueues = [NSMapTable weakToStrongObjectsMapTable]; [QuickQueues setObject:queue forKey:call]; }
            ((void (*)(id, SEL, id))objc_msgSend)(call, NSSelectorFromString(@"answerWithRequest:"), request);
            Count(@"quickAnswered");
            // Safety fallback only: disconnects even if the connected notification never fires. The real exit above should win almost every time.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), queue, ^{ Count(@"quickDisconnectFallback"); QuickDisconnectIfDue(call); });
        } @catch (NSException *e) { (void)e; Count(@"quickAnswerError"); CFPreferencesSetAppValue(CFSTR("MYBQuickTry"), NULL, MYB_CSC_OWN_DOMAIN); }
    });
}
static NSMutableSet *Hooked;
static BOOL HookFilter(NSString *className) {
    Class cls = NSClassFromString(className);
    SEL sel = NSSelectorFromString(@"shouldFilterIncomingCall:");
    Method m = cls ? class_getInstanceMethod(cls, sel) : NULL;
    BOOL already; @synchronized (Lock) { already = [Hooked containsObject:className]; }
    if (!m || already) return NO;
    char rt[8] = {0}; method_getReturnType(m, rt, sizeof rt);
    NSString *enc = [NSString stringWithFormat:@"%s", method_getTypeEncoding(m) ?: ""];
    if (method_getNumberOfArguments(m) != 3 || !(rt[0] == 'c' || rt[0] == 'B')) { @synchronized (Lock) { Counters[[className stringByAppendingString:@"_notBool"]] = enc; } return NO; }
    IMP orig = method_getImplementation(m);
    IMP replacement = imp_implementationWithBlock(^BOOL(id self_, id call) {
        dispatch_queue_t callerQueue = CurrentQueue();
        int d = Decide(call);
        if (!d) d = FirewallDecide(call);          // Private Calls had nothing to say: let the Firewall's own, independent rules have a turn
        if (d) MYBPSBumpCalls();                   // Protection Center's all-time counter: one bump per call actually stopped, muted or hung up
        if (d == 1) { Count(@"stopped"); Republish(); return YES; }
        if (d == 2 || d == 3) {
            Remember(call, d);
            if (d == 2 && [call respondsToSelector:NSSelectorFromString(@"setShouldSuppressRingtone:")]) { ((void (*)(id, SEL, BOOL))objc_msgSend)(call, NSSelectorFromString(@"setShouldSuppressRingtone:"), YES); Count(@"quietRing"); }
            if (d == 3) QuickHangup(call, callerQueue);
            Republish();
        }
        return ((BOOL (*)(id, SEL, id))orig)(self_, sel, call);
    });
    class_replaceMethod(cls, sel, replacement, method_getTypeEncoding(m));
    @synchronized (Lock) { [Hooked addObject:className]; }
    @synchronized (Lock) { Counters[[className stringByAppendingString:@"_hooked"]] = enc; }
    return YES;
}

// The screens and indicators that would show a quietly handled call. Each is told to stay away for that call only; every other call is untouched.
static void ApplyQuiet(id call) {
    SEL set = NSSelectorFromString(@"setShouldSuppressRingtone:");
    if ([call respondsToSelector:set]) ((void (*)(id, SEL, BOOL))objc_msgSend)(call, set, YES);
}
static IMP OrigResolvedCall;
static void HookQuiet(NSString *className, NSString *selector, int args, char ret, int kind) {
    Class cls = NSClassFromString(className); SEL sel = NSSelectorFromString(selector);
    Method m = cls ? class_getInstanceMethod(cls, sel) : NULL;
    NSString *tag = [NSString stringWithFormat:@"%@.%@", className, selector];
    if (!m) { @synchronized (Lock) { Counters[[tag stringByAppendingString:@"_missing"]] = @1; } return; }
    char rt[8] = {0}; method_getReturnType(m, rt, sizeof rt);
    BOOL isBool = rt[0] == 'c' || rt[0] == 'B';
    BOOL shapeOK = ret == 'v' ? rt[0] == 'v' : ret == '@' ? rt[0] == '@' : isBool;
    if ((int)method_getNumberOfArguments(m) != args + 2 || !shapeOK) { @synchronized (Lock) { Counters[[tag stringByAppendingString:@"_shape"]] = [NSString stringWithFormat:@"%s", method_getTypeEncoding(m) ?: ""]; } return; }
    IMP orig = method_getImplementation(m); IMP replacement = NULL;
    if (kind == 0) {          // void method taking the call: skip it for a quiet call
        replacement = imp_implementationWithBlock(^void(id self_, id call) { if (ModeOf(call)) { Count(@"uiHeldBack"); return; } ((void (*)(id, SEL, id))orig)(self_, sel, call); });
    } else if (kind == 1) {   // BOOL answer about the call: YES = suppress
        replacement = imp_implementationWithBlock(^BOOL(id self_, id call) { if (ModeOf(call)) return YES; return ((BOOL (*)(id, SEL, id))orig)(self_, sel, call); });
    } else if (kind == 2) {   // BOOL answer: NO = do not show
        replacement = imp_implementationWithBlock(^BOOL(id self_, id call) { if (ModeOf(call)) return NO; return ((BOOL (*)(id, SEL, id))orig)(self_, sel, call); });
    } else if (kind == 3) {   // BOOL getter on the call itself: YES = suppress its UI
        replacement = imp_implementationWithBlock(^BOOL(id self_) { if (ModeOf(self_)) return YES; return ((BOOL (*)(id, SEL))orig)(self_, sel); });
    } else if (kind == 4) {   // void method about a ringing call: make sure it is silenced before the system acts on it
        replacement = imp_implementationWithBlock(^void(id self_, id call) { if (ModeOf(call) == 2) ApplyQuiet(call); ((void (*)(id, SEL, id))orig)(self_, sel, call); });
    } else if (kind == 6) {   // void method on the call: skip "un-silence" for a quietly handled call
        replacement = imp_implementationWithBlock(^void(id self_) { if (ModeOf(self_) == 2) { Count(@"unsuppressHeld"); return; } ((void (*)(id, SEL))orig)(self_, sel); });
    } else if (kind == 7) {   // void setter taking a BOOL: a quietly handled call stays silenced whatever is asked
        replacement = imp_implementationWithBlock(^void(id self_, BOOL value) { ((void (*)(id, SEL, BOOL))orig)(self_, sel, ModeOf(self_) == 2 ? YES : value); });
    } else if (kind == 8) {   // object getter: the call shown in the status area; a quiet call is never it
        OrigResolvedCall = orig;
        replacement = imp_implementationWithBlock(^id(id self_) { id c = ((id (*)(id, SEL))orig)(self_, sel); if (ModeOf(c)) { Count(@"islandHeldBack"); return nil; } return c; });
    } else if (kind == 10) {  // void method marking a call connected: for a Hang up call, disconnect right here, the earliest honest moment
        replacement = imp_implementationWithBlock(^void(id self_, id call) { ((void (*)(id, SEL, id))orig)(self_, sel, call); if (ModeOf(call) == 3) QuickDisconnectIfDue(call); });
    } else {                  // kind 9: BOOL getter on the status resolver: NO while the call it would show is a quiet one
        replacement = imp_implementationWithBlock(^BOOL(id self_) {
            id c = OrigResolvedCall ? ((id (*)(id, SEL))OrigResolvedCall)(self_, NSSelectorFromString(@"resolvedCall")) : nil;
            if (ModeOf(c)) { Count(@"controlsHeldBack"); return NO; }
            return ((BOOL (*)(id, SEL))orig)(self_, sel);
        });
    }
    class_replaceMethod(cls, sel, replacement, method_getTypeEncoding(m));
    @synchronized (Lock) { Counters[[tag stringByAppendingString:@"_hooked"]] = @1; }
}
static BOOL QuietHooksDone;
static void InstallQuietHooks(void) {
    if (QuietHooksDone) return;
    QuietHooksDone = YES;
    HookQuiet(@"CSDCallStateController", @"_launchInCallApplicationForIncomingCallIfNecessary:", 1, 'v', 0);
    HookQuiet(@"CSDCallStateController", @"_launchInCallApplicationForAnsweringCallIfNecessary:", 1, 'v', 0);
    for (NSString *c in @[@"CSDProviderCall", @"CSDRelayCall", @"CSDCall"]) HookQuiet(c, @"shouldSuppressInCallUI", 0, 'B', 3);
    HookQuiet(@"CSDCallStateController", @"_shouldLaunchInCallApplicationForProviderOfCall:", 1, 'B', 2);
    HookQuiet(@"CSDCallStateController", @"_handleRingingCallStatusChangeForHostedCall:", 1, 'v', 4);
    HookQuiet(@"CSDCallStateController", @"_handleConnectedCallStatusChangeForHostedCall:", 1, 'v', 10);
    HookQuiet(@"CSDCall", @"unsuppressRingtoneIfNecessary", 0, 'v', 6);
    HookQuiet(@"CSDCall", @"setShouldSuppressRingtone:", 1, 'v', 7);
    HookQuiet(@"CSDStatusBarManager", @"shouldOpenInCallServiceForCall:", 1, 'B', 2);
    HookQuiet(@"CSDStatusBarResolver", @"resolvedCall", 0, '@', 8);
    for (NSString *n in @[@"shouldDisplaySystemCallControls", @"callStatusSupportsSystemControls"]) HookQuiet(@"CSDStatusBarResolver", n, 0, 'B', 9);
}
static void InstallHooks(int attempt) {
    BOOL any = NO;
    for (NSString *name in @[@"CSDCallFilterController", @"CSDBlockedCallFilter"]) any |= HookFilter(name);
    InstallQuietHooks();
    Reload();
    Republish();
    NSUInteger done; @synchronized (Lock) { done = Hooked.count; }
    if (done < 2 && attempt < 6) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ InstallHooks(attempt + 1); });
    (void)any;
}

static BOOL Interesting(const char *selector) {
    static const char *words[] = {"ncoming", "inging", "allStatus", "etStatus", "isconnect", "nswer", "eject", "ecline", "ewCall", "ewIncoming", "didReceive", "nnounce", "uppress", "andleStatus"};
    NSString *low = @(selector);
    for (size_t i = 0; i < sizeof(words) / sizeof(words[0]); i++) if ([low rangeOfString:@(words[i]) options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    return NO;
}
static void Probe(NSString *stage) {
    @autoreleasepool {
        @try {
            unsigned count = 0; Class *all = objc_copyClassList(&count);
            NSMutableArray *classes = [NSMutableArray array], *methods = [NSMutableArray array];
            NSMutableArray<NSString *> *names = [NSMutableArray array];
            for (unsigned i = 0; i < count; i++) { const char *n = class_getName(all[i]); if (strncmp(n, "CSD", 3) == 0) [names addObject:@(n)]; }
            free(all);
            [names sortUsingSelector:@selector(compare:)];
            for (NSString *name in names) {
                BOOL callish = [name rangeOfString:@"Call"].location != NSNotFound || [name rangeOfString:@"Telephony"].location != NSNotFound || [name rangeOfString:@"Provider"].location != NSNotFound;
                if (!callish) continue;
                if (classes.count < 120) [classes addObject:name];
                Class cls = NSClassFromString(name); unsigned n = 0;
                Method *list = cls ? class_copyMethodList(cls, &n) : NULL;
                for (unsigned i = 0; i < n && methods.count < 260; i++) {
                    const char *sel = sel_getName(method_getName(list[i]));
                    if (Interesting(sel)) [methods addObject:[NSString stringWithFormat:@"%@.%s %s", name, sel, method_getTypeEncoding(list[i]) ?: ""]];
                }
                free(list);
            }
            NSMutableString *text = [NSMutableString stringWithFormat:@"stage=%@ process=%@ csdClasses=%lu\n", stage, NSProcessInfo.processInfo.processName, (unsigned long)names.count];
            NSMutableDictionary *byClass = [NSMutableDictionary dictionary];
            for (NSString *m in methods) {                      // "Class.selector types" -> selectors only, grouped by class
                NSRange dot = [m rangeOfString:@"."], sp = [m rangeOfString:@" "];
                if (dot.location == NSNotFound) continue;
                NSString *cls = [m substringToIndex:dot.location];
                NSUInteger end = sp.location == NSNotFound ? m.length : sp.location;
                if (end <= dot.location + 1) continue;
                NSString *sel = [m substringWithRange:NSMakeRange(dot.location + 1, end - dot.location - 1)];
                if (!byClass[cls]) byClass[cls] = [NSMutableArray array];
                [byClass[cls] addObject:sel];
            }
            for (NSString *name in @[@"CSDUserNotificationController", @"CSDStatusBarManager", @"CSDStatusBarResolver", @"CSDRecentsController", @"CSDCallHistoryController", @"CSDCallHistoryManager", @"CSDCallStateController", @"CSDCallStateMonitor", @"CSDCall", @"CSDProviderCall", @"CSDRelayCall", @"CSDCallController", @"CSDProviderDisplayMonitor", @"CSDCallFilterController", @"CSDDirtyCallManager", @"CSDClientManager"]) {
                Class cls = NSClassFromString(name); unsigned n = 0; Method *list = cls ? class_copyMethodList(cls, &n) : NULL;
                NSMutableArray *sels = [NSMutableArray array];
                for (unsigned k = 0; k < n; k++) { const char *sel = sel_getName(method_getName(list[k])); if (sel[0] != '.' && strncmp(sel, "set", 3) != 0 && strlen(sel) < 80) [sels addObject:@(sel)]; }
                free(list);
                [text appendFormat:@"%@: %@\n", name, [sels componentsJoinedByString:@" "]];
            }
            {   // every class and method in the call service or its helpers that talks about "busy", "reason" or answering requests
                unsigned total = 0; Class *every = objc_copyClassList(&total); NSMutableArray *hits = [NSMutableArray array];
                for (unsigned k = 0; k < total && hits.count < 60; k++) {
                    const char *cn = class_getName(every[k]);
                    if (strstr(cn, "AnswerRequest") || strstr(cn, "DisconnectedReason") || strstr(cn, "DisconnectReason") || strstr(cn, "CallFilter")) [hits addObject:@(cn)];
                }
                free(every);
                [text appendFormat:@"classes: %@\n", [hits componentsJoinedByString:@" "]];
            }
            @synchronized (Lock) { BaseText = [text copy]; }
            Reload();
            { NSString *full; @synchronized (Lock) { full = [text stringByAppendingFormat:@"hooks: %@ source=%@ switch=%d counters: %@\n", [Hooked.allObjects componentsJoinedByString:@","], Source, SwitchOn, Counters]; } text = [full mutableCopy]; }
            MYBCSCPublish(text);                                                                              // system notification states
            CFPreferencesSetAppValue(MYB_CSC_OWN_KEY, (__bridge CFStringRef)text, MYB_CSC_OWN_DOMAIN);       // its own preferences
            CFPreferencesAppSynchronize(MYB_CSC_OWN_DOMAIN);
            NSDictionary *status = @{@"stage": stage, @"report": text};
            CFPreferencesSetAppValue(CFSTR("status"), (__bridge CFPropertyListRef)status, (__bridge CFStringRef)Domain);
            CFPreferencesAppSynchronize((__bridge CFStringRef)Domain);
            for (NSString *path in @[@"/var/mobile/Library/MYbloXX/CallServiceProbe.plist", @"/var/tmp/MYbloXX-CallServiceProbe.plist", @"/tmp/MYbloXX-CallServiceProbe.plist"]) [status writeToFile:path atomically:YES];
        } @catch (NSException *e) { (void)e; }
    }
}

__attribute__((constructor)) static void Start(void) {
    if (![NSProcessInfo.processInfo.processName isEqualToString:@"callservicesd"]) return;
    Lock = [NSObject new]; Counters = [NSMutableDictionary dictionary]; Hooked = [NSMutableSet set];
    @try {
        const char *recs = NULL; size_t cnt = 0;
        if (MYBJCLoad(jbroot(MYB_JC_DATASET_PATH), &recs, &cnt)) { JunkRecords = recs; JunkCount = cnt; }
        Counters[@"jcLoadedCount"] = @((long long)cnt);
    } @catch (NSException *e) { (void)e; Counters[@"jcLoadError"] = @1; }
    { CFPreferencesAppSynchronize(MYB_CSC_OWN_DOMAIN); id tried = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("MYBQuickTry"), MYB_CSC_OWN_DOMAIN));
      if ([tried isEqual:QuickBuild]) { QuickOff = YES; CFPreferencesSetAppValue(CFSTR("MYBQuickOff"), (__bridge CFStringRef)QuickBuild, MYB_CSC_OWN_DOMAIN); CFPreferencesSetAppValue(CFSTR("MYBQuickTry"), NULL, MYB_CSC_OWN_DOMAIN); CFPreferencesAppSynchronize(MYB_CSC_OWN_DOMAIN); }
      else { id off = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("MYBQuickOff"), MYB_CSC_OWN_DOMAIN)); QuickOff = [off isEqual:QuickBuild]; } }
    MYBCSCPublish(@"alive: the call service part is loaded, report follows");
    CFPreferencesSetAppValue(CFSTR("MYBAlive"), (__bridge CFNumberRef)@((long)time(NULL)), MYB_CSC_OWN_DOMAIN);
    for (NSString *path in @[@"/var/tmp/MYbloXX-CallServiceAlive", @"/tmp/MYbloXX-CallServiceAlive"]) [@"loaded" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];   // proves the part is loaded even when nothing else can be written
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ InstallHooks(0); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ notify_post(MYB_CSL_NEED); });
    static int askToken = 0;                                                                                       // Settings asks for a fresh look with one tap
    notify_register_dispatch("net.myxxdev.mybloxx.csd.probe", &askToken, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int t) { (void)t; Probe(@"asked"); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ Probe(@"start"); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ Probe(@"later"); });
}
