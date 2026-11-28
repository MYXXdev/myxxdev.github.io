// MYbloXX Message Firewall, the live hook. Blocks a text before it is ever stored or shown, inside imagent's own text-message pipeline -- the
// earliest point confirmed real on this phone (Companions/MYBMessageProbe's on-device reports, r53-r55): a sender on the blocked list, or text
// matching a keyword, makes this stage return nil instead of running the real implementation, which stops the message going any further through
// the pipeline (no storage, no notification, no badge). Every other message is untouched: the real implementation runs exactly as it always has.
//
// Why this exact method: -[IMTextMessageProcessingPipelineComponent runIndividuallyWithInput:] is the per-stage entry point IMPipelineComponent's
// own chain-of-responsibility design calls for every incoming text (confirmed on-device: IMPipelineComponent declares
// runWithInput:/runIndividuallyWithInput:/nextComponent/setNextComponent:, and the concrete subclasses loaded in imagent override
// runIndividuallyWithInput: with the same object-returning shape). Its input is an IMTextMessagePipelineParameter -- confirmed by name on-device,
// with fromIdentifier/fromDisplayID/plainTextBody/isFromMe/chat right on it -- never guessed from a header written for a different iOS version. Its
// return type is a real object (encoding "@24@0:8@16", confirmed by method_getTypeEncoding, r55), never void or BOOL, so returning nil to signal
// "stop" and returning the original implementation's result to pass a message through are both valid answers for its ABI; there is no return-shape
// guess here, only a behavioural one (that nil actually halts the chain), which is exactly what this feature exists to let Mikey confirm live.
//
// Reads only what a block decision needs (sender identifiers, the plain text, whether it is the user's own outgoing message) and never writes,
// stores, forwards or logs a number, a contact or a message anywhere -- diagnostics below carry counts only.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../../Shared/MYBCallServiceChannel.h"
#import "../../Shared/MYBMessageFirewallList.h"
#import "../../Shared/MYBProtectionStats.h"

static NSObject *Lock;
static NSMutableDictionary *Counters;
static NSArray *CompiledPatterns;   // Mikey's own 54-rule bundled scam detector, compiled once at install time -- never reparsed per message
static void Count(NSString *key) { @synchronized (Lock) { Counters[key] = @([Counters[key] intValue] + 1); } }

// MYB_MFH_OWN_DOMAIN/MYB_MFH_OWN_KEY/MYB_MFH_NAME now live in Shared/MYBMessageFirewallList.h, so the Settings screen's diagnostics reader can
// never drift from what this hook actually publishes to.

static void Report(void) {
    NSString *text;
    @synchronized (Lock) { text = [[Counters description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; }
    @try { MYBCSCPublishIn(MYB_MFH_NAME, text); } @catch (NSException *e) { (void)e; }
    @try {
        CFPreferencesSetAppValue(MYB_MFH_OWN_KEY, (__bridge CFStringRef)text, MYB_MFH_OWN_DOMAIN);
        CFPreferencesAppSynchronize(MYB_MFH_OWN_DOMAIN);
    } @catch (NSException *e) { (void)e; }
}
static id Get(id object, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (!object || ![object respondsToSelector:sel]) return nil;
    @try { return [object valueForKey:name]; } @catch (NSException *e) { (void)e; return nil; }
}
// Reads the live block list fresh for every message -- no cache, the same guarantee the Call Firewall's own live list already makes ("no
// preference cache is involved, so a change takes effect on the very next call"). A CFPreferences round trip is cheap; texts do not arrive often
// enough for that cost to matter, and a stale decision here is a far worse failure mode than one extra IPC call.
static BOOL ShouldBlock(id input) {
    @try {
        NSString *published = MYBMFLReadPublished();
        if (!published.length) { Count(@"noList"); return NO; }
        NSMutableArray *senders = nil, *keywords = nil, *categories = nil;
        BOOL on = MYBMFParsePublished(published, &senders, &keywords, &categories);
        Count(@"checked");
        if (!on) return NO;
        id fromMe = Get(input, @"isFromMe");
        if ([fromMe isKindOfClass:NSNumber.class] && [fromMe boolValue]) return NO;   // never touch the user's own outgoing texts
        NSString *region = [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];
        NSMutableArray *senderKeys = [NSMutableArray array];
        for (NSString *field in @[@"fromIdentifier", @"fromDisplayID"]) {
            NSString *key = MYBMFSenderKey(Get(input, field), region);
            if (key.length) [senderKeys addObject:key];
        }
        NSString *plainText = Get(input, @"plainTextBody");
        BOOL senderMatch = NO;
        for (NSString *key in senderKeys) if ([senders containsObject:key]) { senderMatch = YES; break; }
        BOOL keywordMatch = !senderMatch && MYBMFTextMatches(plainText, keywords);
        // Mikey's own bundled scam-pattern set (Shared/MYBMessageFirewallPatterns.h) -- checked last, only against whichever categories are
        // enabled, using the patterns compiled once at install time rather than reparsed here.
        BOOL patternMatch = !senderMatch && !keywordMatch && categories.count && MYBMFCompiledPatternsMatch(plainText, CompiledPatterns, categories);
        if (senderMatch) Count(@"blockedSender");
        else if (keywordMatch) Count(@"blockedKeyword");
        else if (patternMatch) Count(@"blockedPattern");
        BOOL blocked = senderMatch || keywordMatch || patternMatch;
        if (blocked) MYBPSBumpMessages();   // Protection Center's all-time counter: one bump per message actually blocked
        return blocked;
    } @catch (NSException *e) { (void)e; Count(@"decisionError"); return NO; }
}
// Whether cls declares sel ITSELF -- class_copyMethodList only ever returns methods a class defines on its own, never ones it inherits -- so this
// is how an override is told apart from a class that just answers class_getInstanceMethod() by inheriting the base class's copy.
// label is just for diagnostics ("runWith"/"runIndividually") so the two attempts never collide in Counters.
static BOOL HookOneMethod(Class cls, SEL sel, NSString *label) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { @synchronized (Lock) { Counters[[NSString stringWithFormat:@"missing.%@", label]] = @1; } return NO; }
    const char *enc = method_getTypeEncoding(m);
    NSString *encStr = enc ? @(enc) : @"";
    // Shape confirmed on-device (r55) for runIndividuallyWithInput: -- "@24@0:8@16" (object return, self, _cmd, one object argument). Both methods
    // this hook now tries share the same chain-of-responsibility calling convention (one input, one object result), so the same shape check applies
    // to either; refuse to hook anything that does not match rather than guess at an ABI inside a live system daemon.
    if (![encStr hasPrefix:@"@"] || (int)method_getNumberOfArguments(m) != 3) {
        @synchronized (Lock) { Counters[[NSString stringWithFormat:@"shapeMismatch.%@", label]] = encStr; }
        return NO;
    }
    IMP orig = method_getImplementation(m);
    IMP replacement = imp_implementationWithBlock(^id(id self_, id input) {
        @try {
            if (ShouldBlock(input)) { Report(); return nil; }
        } @catch (NSException *e) { (void)e; Count(@"hookError"); }
        return ((id (*)(id, SEL, id))orig)(self_, sel, input);
    });
    class_replaceMethod(cls, sel, replacement, method_getTypeEncoding(m));
    @synchronized (Lock) { Counters[[NSString stringWithFormat:@"hooked.%@", label]] = @1; }
    return YES;
}
// r61 widened this to every pipeline-component subclass (audio/sticker/typing-indicator/balloon-plugin, not just plain text) chasing the same
// theory, and on-device evidence showed that was both unnecessary scope (those message types were never in this feature's remit) and still never
// once fired -- "checked" never appeared even with 6 classes hooked. Narrowed back to the one class this feature actually cares about: plain text.
//
// What's different this time: the original probe's own comment recorded that IMPipelineComponent declares BOTH runWithInput: and
// runIndividuallyWithInput:. Every attempt so far only ever patched runIndividuallyWithInput:, and two separate on-device releases (r59/r60 with
// just the base class, r61 with six classes) agree it never fires for a real incoming text. That leaves runWithInput: as the one documented,
// still-untried entry point -- very plausibly the actual per-stage call the chain-of-responsibility pipeline makes for every message, with
// runIndividuallyWithInput: being some other, secondary path. Both are patched here, independently and defensively (each is only installed if its
// own shape checks out), so whichever one actually fires gets caught, and diagnostics show which.
static void InstallHook(int attempt) {
    Class cls = NSClassFromString(@"IMTextMessageProcessingPipelineComponent");
    if (!cls) {
        Count(@"classOrMethodMissing");
        if (attempt < 6) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ InstallHook(attempt + 1); });
        Report();
        return;
    }
    BOOL hookedIndividually = HookOneMethod(cls, NSSelectorFromString(@"runIndividuallyWithInput:"), @"runIndividually");
    BOOL hookedWith = HookOneMethod(cls, NSSelectorFromString(@"runWithInput:"), @"runWith");
    BOOL any = hookedIndividually || hookedWith;
    if (any) Count(@"hooked");
    else if (attempt < 6) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ InstallHook(attempt + 1); });
    Report();
}
__attribute__((constructor)) static void Start(void) {
    if (![NSProcessInfo.processInfo.processName isEqualToString:@"imagent"]) return;
    Lock = [NSObject new];
    Counters = [NSMutableDictionary dictionary];
    @try { CompiledPatterns = MYBMFCompileBundledPatterns(); } @catch (NSException *e) { (void)e; CompiledPatterns = [NSArray array]; }
    @synchronized (Lock) { Counters[@"patternsCompiled"] = @(CompiledPatterns.count); }
    InstallHook(0);
}
