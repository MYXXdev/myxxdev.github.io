#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>
#import <roothide.h>
#import "../../Shared/MYBConnectivity.h"

// MYbloXX® Private Conversations, Spotlight display filter. It only runs in the home-screen search UI (SpringBoard and Spotlight), never in Messages,
// the message delivery services, the search indexer, CommCenter, or anything about carriers, SIM or calls. It does not read or change any message or
// index. It hides a search result on screen only when that result's own identifier is, after the same salted hash Messages uses, a private conversation.
// Names and lengths of what Messages results look like are written to a small probe file (no message text, names, numbers or addresses).

#define MSG(ret, ...) ((ret (*)(id, SEL, ##__VA_ARGS__))objc_msgSend)

static NSString *ProbeFile(void) { return MYBRuleFile(@"var/mobile/Library/MYbloXX/PrivateSpotlightProbe.plist"); }
static NSMutableArray<NSString *> *Shapes, *Hooked;
static int Hidden_, Seen_;

// The private set: salted hashes kept by Messages in its own preferences. Read at most every three seconds, and only while the switch is on.
static NSString *Salt_;
static NSSet *PrivateSet(void) {
    static NSSet *set; static CFAbsoluteTime stamp;
    @synchronized (Shapes) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (now - stamp < 3) return set;
        stamp = now; set = nil; Salt_ = nil;
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:MYBPrivPrefsFile()];
        if (!MYBConnFlag(prefs, MYB_PRIV_KEY_MESSAGES)) return nil;
        id salt = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("MYBPMSalt"), CFSTR("com.apple.MobileSMS")));
        id entries = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("MYBPMEntries"), CFSTR("com.apple.MobileSMS")));
        if (![salt isKindOfClass:NSString.class] || ![entries isKindOfClass:NSDictionary.class]) return nil;
        NSMutableSet *hashes = [NSMutableSet set];
        for (NSString *key in entries) if ([[entries[key] objectForKey:@"state"] isEqual:@"private"]) [hashes addObject:key];
        Salt_ = salt; set = hashes.count ? hashes : nil;
        return set;
    }
}
static NSString *HashOf(NSString *value) {
    NSData *input = [[NSString stringWithFormat:@"%@|%@", Salt_, value] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(input.bytes, (CC_LONG)input.length, digest);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < 12; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}
static BOOL StringPrivate(NSString *value, NSSet *set) {
    if (value.length < 4 || value.length > 400) return NO;
    NSMutableArray *candidates = [NSMutableArray arrayWithObject:value];
    for (NSString *part in [value componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/?&=# ,"]]) if (part.length >= 4 && ![part isEqual:value]) [candidates addObject:part];
    for (NSString *candidate in candidates) if ([set containsObject:HashOf(candidate)]) return YES;
    return NO;
}
static id Value(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (!object || ![object respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
    return MSG(id)(object, selector);
}
static BOOL LooksLikeMessages(NSString *value) {
    NSString *lower = value.lowercaseString;
    return [lower containsString:@"mobilesms"] || [lower containsString:@"imessage"] || [lower hasPrefix:@"sms"] || [lower containsString:@"messages"];
}
static BOOL Private(id item, NSSet *set, int depth, NSMutableArray *seen, BOOL *fromMessages) {
    if (!item || depth > 2) return NO;
    for (NSString *name in @[@"identifier", @"uniqueIdentifier", @"resultIdentifier", @"domainIdentifier", @"contentURL", @"url", @"applicationBundleIdentifier", @"resultBundleId", @"sectionBundleIdentifier"]) {
        id value = Value(item, name);
        if ([value isKindOfClass:NSURL.class]) value = [value absoluteString];
        if (![value isKindOfClass:NSString.class]) continue;
        [seen addObject:[NSString stringWithFormat:@"%@:%lu", name, (unsigned long)[value length]]];
        if (LooksLikeMessages(value)) *fromMessages = YES;
        if (StringPrivate(value, set)) return YES;
    }
    for (NSString *name in @[@"result", @"searchResult", @"item", @"attributeSet", @"searchableItem", @"representedObject"]) {
        id nested = Value(item, name);
        if (nested && nested != item && ![nested isKindOfClass:NSString.class]) { [seen addObject:name]; if (Private(nested, set, depth + 1, seen, fromMessages)) return YES; }
    }
    return NO;
}
static void WriteProbe(void) {
    NSDictionary *probe = @{@"process": NSBundle.mainBundle.bundleIdentifier ?: @"", @"hooked": Hooked ?: @[], @"shapes": Shapes ?: @[], @"seen": @(Seen_), @"hidden": @(Hidden_),
        @"salt": @(Salt_.length > 0), @"ios": UIDevice.currentDevice.systemVersion};
    NSString *file = ProbeFile();
    [NSFileManager.defaultManager createDirectoryAtPath:file.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    [probe writeToFile:file atomically:YES];
}
static void Filter(id snapshot) {
    NSSet *set = PrivateSet();
    if (!set.count) return;
    if (![snapshot respondsToSelector:@selector(itemIdentifiers)] || ![snapshot respondsToSelector:@selector(deleteItemsWithIdentifiers:)]) return;
    NSMutableArray *drop = [NSMutableArray array];
    for (id item in MSG(id)(snapshot, @selector(itemIdentifiers))) {
        if ([item isKindOfClass:NSNumber.class] || [item isKindOfClass:NSNull.class]) continue;
        NSMutableArray *seen = [NSMutableArray array]; BOOL fromMessages = NO;
        BOOL hide = [item isKindOfClass:NSString.class] ? StringPrivate(item, set) : Private(item, set, 0, seen, &fromMessages);
        if (hide) { [drop addObject:item]; Hidden_++; continue; }
        if (fromMessages) {
            Seen_++;
            NSString *shape = [NSString stringWithFormat:@"%@ [%@]", NSStringFromClass([item class]), [seen componentsJoinedByString:@","]];
            if (Shapes.count < 8 && ![Shapes containsObject:shape]) { [Shapes addObject:shape]; WriteProbe(); }
        }
    }
    if (drop.count) { MSG(void, id)(snapshot, @selector(deleteItemsWithIdentifiers:), drop); WriteProbe(); }
}
static void HookClass(Class source) {
    if (!source) return;
    SEL a1 = @selector(applySnapshot:animatingDifferences:), a2 = @selector(applySnapshot:animatingDifferences:completion:),
        a3 = @selector(applySnapshotUsingReloadData:), a4 = @selector(applySnapshotUsingReloadData:completion:);
    Method m1 = class_getInstanceMethod(source, a1), m2 = class_getInstanceMethod(source, a2), m3 = class_getInstanceMethod(source, a3), m4 = class_getInstanceMethod(source, a4);
    if (m1) { IMP o = method_getImplementation(m1); method_setImplementation(m1, imp_implementationWithBlock(^(id self, id snapshot, BOOL animated) { Filter(snapshot); ((void (*)(id, SEL, id, BOOL))o)(self, a1, snapshot, animated); })); }
    if (m2) { IMP o = method_getImplementation(m2); method_setImplementation(m2, imp_implementationWithBlock(^(id self, id snapshot, BOOL animated, id completion) { Filter(snapshot); ((void (*)(id, SEL, id, BOOL, id))o)(self, a2, snapshot, animated, completion); })); }
    if (m3) { IMP o = method_getImplementation(m3); method_setImplementation(m3, imp_implementationWithBlock(^(id self, id snapshot) { Filter(snapshot); ((void (*)(id, SEL, id))o)(self, a3, snapshot); })); }
    if (m4) { IMP o = method_getImplementation(m4); method_setImplementation(m4, imp_implementationWithBlock(^(id self, id snapshot, id completion) { Filter(snapshot); ((void (*)(id, SEL, id, id))o)(self, a4, snapshot, completion); })); }
    [Hooked addObject:NSStringFromClass(source)];
}

__attribute__((constructor)) static void MYXXPrivateSpotlightInit(void) {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
    if (![bundle isEqualToString:@"com.apple.springboard"] && ![bundle isEqualToString:@"com.apple.Spotlight"]) return;   // hard scope: the search UI only
    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 16) return;
    Shapes = [NSMutableArray array]; Hooked = [NSMutableArray array];
    HookClass(NSClassFromString(@"UICollectionViewDiffableDataSourceReference"));
    HookClass(NSClassFromString(@"UITableViewDiffableDataSourceReference"));
    // After launch settles, note which search-result classes this build of iOS has (names only), so a missing hook can be named next time.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (!PrivateSet().count) return;
        unsigned int count = 0; Class *all = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count && Hooked.count < 40; i++) {
            NSString *name = NSStringFromClass(all[i]);
            if (([name hasPrefix:@"SearchUI"] || [name hasPrefix:@"SPUI"]) && ([name containsString:@"Result"] || [name containsString:@"DataSource"])) [Hooked addObject:name];
        }
        free(all);
        WriteProbe();
    });
}
