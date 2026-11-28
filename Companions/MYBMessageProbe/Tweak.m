// MYbloXX Message Firewall, pipeline probe (read-only, no hook). Mirrors MYBPrivateAudioProbe exactly: before anything is built that touches a live
// message, this part only LOOKS at imagent's own loaded classes -- which IM*/pipeline classes exist, and which properties and methods they declare --
// so the real object graph around a message's suppression decision can be confirmed from the binary itself, without ever receiving, reading, altering
// or suppressing an actual text. It installs no hook, calls no IM* method, and never touches a message, a number or a name. Only class, property and
// method NAMES are written, through every channel Companions/MYBPrivateCallService already proved necessary for a locked-down system daemon -- the
// one-way mailbox (Shared/MYBCallServiceChannel.h) under its own namespace, imagent's own preferences domain, a dedicated preferences domain, and a
// handful of plain files -- since a sandboxed daemon may refuse some of these and there is no way to know in advance which. None is required to
// succeed; each is tried independently so one failing never stops the rest.
//
// Why this exists: Settings' "Message Firewall" is not shipped by this build. Blocking or auto-deleting a text before it ever notifies would need a
// hook inside imagent, the daemon that handles iMessage/SMS even when Messages.app is closed -- nothing this codebase has ever done before, and the
// one documented decision point Apple's own pipeline exposes for it (-[IMTextMessageProcessingPipelineComponent canSuppressMessageWithInput:]) takes
// an untyped `id` whose real class can't be determined from headers alone. This probe answers that question safely, from the phone it will actually
// run on, before a single line of hooking code is written.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import "../../Shared/MYBCallServiceChannel.h"

#define MYB_IMP_NAME @"net.myxxdev.mybloxx.imp.%u"
#define MYB_IMP_OWN_DOMAIN CFSTR("com.apple.imagent")
#define MYB_IMP_OWN_KEY CFSTR("MYBMessageProbeReport")
#define MYB_IMP_DEDICATED_DOMAIN CFSTR("net.myxxdev.mybloxx.messageprobe")

// Every channel a sandboxed system daemon might allow, tried independently. Still only class/property/method NAMES, the same text, through all of
// them -- never a number, a contact or a message.
static void WriteEverywhere(NSString *text) {
    @try { MYBCSCPublishIn(MYB_IMP_NAME, text); } @catch (NSException *e) { (void)e; }
    @try {
        CFPreferencesSetAppValue(MYB_IMP_OWN_KEY, (__bridge CFStringRef)text, MYB_IMP_OWN_DOMAIN);
        CFPreferencesAppSynchronize(MYB_IMP_OWN_DOMAIN);
    } @catch (NSException *e) { (void)e; }
    @try {
        CFPreferencesSetAppValue(CFSTR("status"), (__bridge CFStringRef)text, MYB_IMP_DEDICATED_DOMAIN);
        CFPreferencesAppSynchronize(MYB_IMP_DEDICATED_DOMAIN);
    } @catch (NSException *e) { (void)e; }
    NSDictionary *doc = @{@"report": text, @"pid": @(getpid()), @"time": @((long)time(NULL))};
    for (NSString *path in @[@"/var/mobile/Library/MYbloXX/MessageProbe.plist", @"/var/tmp/MYbloXX-MessageProbe.plist", @"/tmp/MYbloXX-MessageProbe.plist"]) {
        @try {
            [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
            [doc writeToFile:path atomically:YES];
        } @catch (NSException *e) { (void)e; }
    }
}
// A bare marker, separate from the full report: tells us the constructor itself ran inside imagent even if every other channel above is refused.
static void MarkAlive(void) {
    @try {
        CFPreferencesSetAppValue(CFSTR("MYBAlive"), (__bridge CFNumberRef)@((long)time(NULL)), MYB_IMP_OWN_DOMAIN);
        CFPreferencesAppSynchronize(MYB_IMP_OWN_DOMAIN);
    } @catch (NSException *e) { (void)e; }
    for (NSString *path in @[@"/var/tmp/MYbloXX-MessageProbeAlive", @"/tmp/MYbloXX-MessageProbeAlive"]) {
        @try { [[NSString stringWithFormat:@"%ld", (long)time(NULL)] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; } @catch (NSException *e) { (void)e; }
    }
}

static BOOL Wanted(const char *name) {
    static const char *words[] = {"Pipeline", "PipelineInput", "PipelineComponent", "IMMessage", "IMHandle", "IMDMessage", "IMDChat", "Suppress", "Incoming"};
    for (size_t i = 0; i < sizeof(words) / sizeof(words[0]); i++) if (strstr(name, words[i])) return YES;
    return NO;
}
// Property and method NAMES only -- never a value, never invoked. class_copyPropertyList/class_copyMethodList/method_getTypeEncoding read declared
// metadata off the Class object itself; nothing here creates an instance, calls a getter or touches live data. The type encoding (e.g. "v@:@") is
// still just metadata -- it says a method's argument/return SHAPE (object, BOOL, void, ...), never a value -- but it is needed before any hook can
// safely be written: calling or returning from a hooked method with the wrong ABI shape is undefined behaviour inside a live system daemon.
static NSString *Shape(Class cls) {
    NSMutableArray *props = [NSMutableArray array];
    unsigned pc = 0; objc_property_t *plist = class_copyPropertyList(cls, &pc);
    for (unsigned i = 0; i < pc && props.count < 60; i++) { const char *n = property_getName(plist[i]); if (n) [props addObject:@(n)]; }
    free(plist);
    NSMutableArray *sels = [NSMutableArray array];
    unsigned mc = 0; Method *mlist = class_copyMethodList(cls, &mc);
    for (unsigned i = 0; i < mc && sels.count < 80; i++) {
        const char *s = sel_getName(method_getName(mlist[i]));
        if (!s || s[0] == '.' || strlen(s) > 70) continue;
        const char *enc = method_getTypeEncoding(mlist[i]);
        [sels addObject:enc ? [NSString stringWithFormat:@"%s[%s]", s, enc] : @(s)];
    }
    free(mlist);
    return [NSString stringWithFormat:@"props(%lu): %@\nmethods(%lu): %@", (unsigned long)props.count, [props componentsJoinedByString:@" "], (unsigned long)sels.count, [sels componentsJoinedByString:@" "]];
}
static void Probe(void) {
    @autoreleasepool {
        @try {
            NSMutableString *text = [NSMutableString stringWithFormat:@"process=%@ pid=%d\n", NSProcessInfo.processInfo.processName, getpid()];
            unsigned total = 0; Class *all = objc_copyClassList(&total);
            NSMutableArray *names = [NSMutableArray array];
            for (unsigned i = 0; i < total; i++) { const char *n = class_getName(all[i]); if (n && Wanted(n) && names.count < 260) [names addObject:@(n)]; }
            [names sortUsingSelector:@selector(compare:)];
            [text appendFormat:@"classes(%lu): %@\n", (unsigned long)names.count, [names componentsJoinedByString:@" "]];
            // The shape of the two components we already know exist from static headers, plus any class whose name contains "Input" -- the most
            // likely home for the untyped parameter canSuppressMessageWithInput: actually receives.
            NSMutableArray *detailed = [NSMutableArray array];
            // First pass (r52/r53, on-device): IMTextMessageProcessingPipelineComponent only showed 4 methods, because class_copyMethodList excludes
            // inherited ones -- canSuppressMessageWithInput: lives higher up, on the shared base every *ProcessingPipelineComponent inherits from.
            // The matching *PipelineParameter class (IMTextMessagePipelineParameter, the same naming pairing every other component in the pipeline
            // uses -- IMReadReceiptProcessingPipelineComponent/IMReadReceiptPipelineParameter, etc.) is the strongest candidate for the untyped
            // `input` itself, despite having no "Input" in its own name.
            for (NSString *known in @[@"IMTextMessageProcessingPipelineComponent", @"IMMessage", @"IMHandle", @"IMTextMessagePipelineParameter", @"IMPipelineComponent", @"IMMessageLegacyProcessingPipelineComponent"]) if ([names containsObject:known]) [detailed addObject:known];
            for (NSString *n in names) if ([n rangeOfString:@"Input"].location != NSNotFound && detailed.count < 20 && ![detailed containsObject:n]) [detailed addObject:n];
            free(all);
            for (NSString *name in detailed) {
                Class cls = NSClassFromString(name);
                if (cls) [text appendFormat:@"-- %@ --\n%@\n", name, Shape(cls)];
            }
            WriteEverywhere(text);
        } @catch (NSException *e) { (void)e; }
    }
}
__attribute__((constructor)) static void Start(void) {
    if (![NSProcessInfo.processInfo.processName isEqualToString:@"imagent"]) return;
    MarkAlive();
    WriteEverywhere(@"alive: the message pipeline probe is loaded, report follows");
    static int askToken = 0;
    notify_register_dispatch("net.myxxdev.mybloxx.imp.probe", &askToken, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int t) { (void)t; MarkAlive(); Probe(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ Probe(); });
}
