// MYbloXX Message Firewall, the live hook. Blocks a text before it is ever stored or shown, inside imagent's own text-message pipeline -- a
// sender on the blocked list, or text matching a keyword, makes this stage report the message as suppressed, which stops it going any further
// through the pipeline (no storage, no notification, no badge). Every other message is untouched: the real implementation runs exactly as it
// always has.
//
// Why this exact method -- -[IMTextMessageProcessingPipelineComponent canSuppressMessageWithInput:]: three straight on-device releases
// (r59/r60 hooking just runIndividuallyWithInput: on the base class, r61 widening that to all 6 concrete pipeline-component subclasses, r62/r63
// also trying the sibling runWithInput:) all agreed on the same result -- the hook installs cleanly every time, but the "checked" counter below,
// bumped unconditionally on every single invocation, never once appeared, even across real incoming test texts sent right after a fresh
// userspace reboot. Across 2 classes and 3 different dispatch-chain selectors, that is conclusive: whatever imagent actually calls for a plain
// text is none of those. Companions/MYBMessageProbe's own on-device class/method dump (r53-r55) separately named the one OTHER, purpose-built
// decision point this same pipeline exposes for exactly this question -- canSuppressMessageWithInput:, declared on the shared IMPipelineComponent
// base every *ProcessingPipelineComponent inherits -- which nothing has actually tried hooking until now. Unlike the dispatch methods above, its
// name and its signature (it takes the per-message input object, not just self) both say what it is for: asking, for this one message, whether
// it may be suppressed. Patched on the concrete IMTextMessageProcessingPipelineComponent class itself (the r61 lesson: patching only where the
// inherited method is actually declared is dead code if a concrete subclass could shadow it, so the patch always targets the real receiving
// class, never the abstract base, whether or not it declares the selector itself). Its own ABI shape (object argument in, BOOL out) is read live
// via method_getTypeEncoding and refused if it doesn't match, the same discipline as every attempt before it -- no guessing an ABI inside a live
// system daemon. Its input is an IMTextMessagePipelineParameter -- confirmed by name on-device, with fromIdentifier/fromDisplayID/plainTextBody/
// isFromMe/chat right on it -- never guessed from a header written for a different iOS version.
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
// canSuppressMessageWithInput: is a predicate (its name says so), not a dispatch method -- it takes one object in and reports a yes/no answer
// about it, so its shape is object-argument-in, BOOL-out, never the object-out shape the three already-disproven dispatch-method attempts had.
// class_getInstanceMethod does an inheritance search deliberately: the selector is declared on the shared IMPipelineComponent base, and that is
// fine, because class_replaceMethod below still patches it directly onto cls (the concrete, actually-receiving class), which is what matters --
// the r61 lesson was about where the patch lands, not about where the selector happens to be declared.
static BOOL HookCanSuppress(Class cls, SEL sel, NSString *label) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { @synchronized (Lock) { Counters[[NSString stringWithFormat:@"missing.%@", label]] = @1; } return NO; }
    const char *enc = method_getTypeEncoding(m);
    NSString *encStr = enc ? @(enc) : @"";
    // @encode(BOOL) is "B" on arm64/arm64e, "c" on the legacy char-typedef ABI some older runtimes still report -- accept either, refuse
    // anything else rather than guess at an ABI inside a live system daemon.
    BOOL boolReturn = [encStr hasPrefix:@"B"] || [encStr hasPrefix:@"c"];
    if (!boolReturn || (int)method_getNumberOfArguments(m) != 3) {
        @synchronized (Lock) { Counters[[NSString stringWithFormat:@"shapeMismatch.%@", label]] = encStr; }
        return NO;
    }
    IMP orig = method_getImplementation(m);
    IMP replacement = imp_implementationWithBlock(^BOOL(id self_, id input) {
        @try {
            if (ShouldBlock(input)) { Report(); return YES; }   // YES: this message may be suppressed -- exactly what the selector asks
        } @catch (NSException *e) { (void)e; Count(@"hookError"); }
        return ((BOOL (*)(id, SEL, id))orig)(self_, sel, input);
    });
    class_replaceMethod(cls, sel, replacement, method_getTypeEncoding(m));
    @synchronized (Lock) { Counters[[NSString stringWithFormat:@"hooked.%@", label]] = @1; }
    return YES;
}
// r59-r63 tried three different dispatch-chain selectors across 1, then 6, then 2 classes again -- all installed cleanly, none ever fired
// (confirmed by "checked" never once appearing, including right after a fresh test text post-reboot). This switches to the one remaining,
// purpose-built candidate: canSuppressMessageWithInput:, which Companions/MYBMessageProbe's own on-device research already named as the real
// decision point and which nothing has tried hooking until now. If this also never fires, the pipeline-component theory itself -- not just
// which selector on it -- is what's wrong, and the next step is tracing imagent directly rather than guessing another selector name.
static void InstallHook(int attempt) {
    Class cls = NSClassFromString(@"IMTextMessageProcessingPipelineComponent");
    if (!cls) {
        Count(@"classOrMethodMissing");
        if (attempt < 6) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ InstallHook(attempt + 1); });
        Report();
        return;
    }
    BOOL hooked = HookCanSuppress(cls, NSSelectorFromString(@"canSuppressMessageWithInput:"), @"canSuppress");
    if (hooked) Count(@"hooked");
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
