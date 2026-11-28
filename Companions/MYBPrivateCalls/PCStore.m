#import "PCStore.h"
#import <notify.h>
#import <roothide.h>
#import "../../Shared/MYBConnectivity.h"
#import "../../Shared/MYBPrivateCallsStore.h"
#import "../../Shared/MYBCallServiceList.h"

// ONE store: PrivateCallsLog in the privacy preference file. Every process reads it from there. Writes go through MYBPCStoreMutate, directly when this
// process may write the file, otherwise through the root helper (request in Phone's own preferences + notification). See Shared/MYBPrivateCallsStore.h.
static NSDictionary *Prefs;
static NSArray *Effective;
static NSTimeInterval LoadedAt;
static NSObject *Lock;
static NSString *LastWrite = @"unknown";      // how the last save was done: direct, helper, failed
static BOOL ReadOK;

static NSString *StoreFile(void) { return MYBPrivPrefsFile(); }
static NSString *StampFile(void) { return MYBRuleFile(@"var/mobile/Library/MYbloXX/PrivateCallsReset.plist"); }
static NSArray *PhoneArray(NSString *key) {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)MYB_PC_PHONE_DOMAIN));
    return [value isKindOfClass:NSArray.class] ? value : nil;
}
void PCReload(void) {
    if (!Lock) Lock = [NSObject new];
    NSString *file = StoreFile();
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:file];
    BOOL readable = prefs != nil || ![NSFileManager.defaultManager fileExistsAtPath:file];   // no file yet is a normal empty store
    prefs = prefs ?: @{};
    NSArray *effective = MYBPCEffective(MYBPCStoreLog(file), nil);
    @synchronized (Lock) { Prefs = prefs; Effective = effective; ReadOK = readable; LoadedAt = NSDate.timeIntervalSinceReferenceDate; }
    if (readable) MYBCSLPublish(file);                      // the call service reads the list from there, fresh, on every incoming call
}
BOOL PCSwitchOn(void) {
    if (!Lock) PCReload();
    @synchronized (Lock) { return MYBConnFlag(Prefs, MYB_PC_KEY_SWITCH); }
}
NSArray *PCEffectiveEntries(void) {
    if (!Lock) PCReload();
    NSTimeInterval age; @synchronized (Lock) { age = NSDate.timeIntervalSinceReferenceDate - LoadedAt; }
    if (age > 20) PCReload();
    @synchronized (Lock) { return Effective ?: @[]; }
}
NSString *PCRegion(void) { return [NSLocale.currentLocale objectForKey:NSLocaleCountryCode]; }

// Phone's pending requests and the r18 list are retired from Phone's own preferences once the store covers them (or a reset made them void).
void PCRetire(void) {
    NSArray *store = MYBPCStoreLog(StoreFile());
    BOOL migrated = [[MYBPCStoreRead(StoreFile()) objectForKey:MYB_PC_KEY_VERSION] intValue] >= 2;
    double stamp = MYBPCResetStamp(StampFile());
    BOOL changed = NO;
    for (NSString *key in @[MYB_PC_PHONE_QUEUE, MYB_PC_PHONE_LOG]) {
        NSArray *items = PhoneArray(key);
        if (!items.count) continue;
        if ([key isEqual:MYB_PC_PHONE_LOG] && !migrated) continue;                       // the old list stays until the migration is verified
        if (MYBPCStoreCovers(store, MYBPCAfterReset(items, stamp))) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, (__bridge CFStringRef)MYB_PC_PHONE_DOMAIN); changed = YES;
        }
    }
    if (changed) CFPreferencesAppSynchronize((__bridge CFStringRef)MYB_PC_PHONE_DOMAIN);
}
static BOOL SaveViaHelper(NSDictionary *rec) {
    NSString *key = rec[@"k"];
    NSArray *queue = MYBPCLogWith(PhoneArray(MYB_PC_PHONE_QUEUE), rec);
    CFPreferencesSetAppValue((__bridge CFStringRef)MYB_PC_PHONE_QUEUE, (__bridge CFPropertyListRef)queue, (__bridge CFStringRef)MYB_PC_PHONE_DOMAIN);
    if (!CFPreferencesAppSynchronize((__bridge CFStringRef)MYB_PC_PHONE_DOMAIN)) return NO;
    notify_post(MYB_PC_REQUEST_NOTIFY);
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:5];
    while (until.timeIntervalSinceNow > 0) {                                           // wait for the store to show it; keep the screen alive
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
        NSDictionary *back = MYBPCRecordForKey(MYBPCStoreLog(StoreFile()), key);
        if (back && [back[@"t"] doubleValue] >= [rec[@"t"] doubleValue] - 0.001 && [back[@"on"] boolValue] == [rec[@"on"] boolValue]) return YES;
    }
    NSArray *rest = MYBPCLogWith(PhoneArray(MYB_PC_PHONE_QUEUE), MYBPCRecord(key, rec[@"d"], rec[@"a"], [rec[@"on"] boolValue], [rec[@"t"] doubleValue]));
    NSMutableArray *drop = [NSMutableArray array];                                     // not saved: withdraw the request so it cannot apply later
    for (id r in rest) if (![r[@"k"] isEqual:key]) [drop addObject:r];
    CFPreferencesSetAppValue((__bridge CFStringRef)MYB_PC_PHONE_QUEUE, drop.count ? (__bridge CFPropertyListRef)drop : NULL, (__bridge CFStringRef)MYB_PC_PHONE_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)MYB_PC_PHONE_DOMAIN);
    return NO;
}
BOOL PCSetEntry(NSString *key, NSString *display, NSString *action, BOOL on) {
    if (!key.length) return NO;
    NSDictionary *rec = nil;
    BOOL ok = MYBPCStoreSet(StoreFile(), key, display, action, on, NSDate.date.timeIntervalSince1970, &rec);
    NSString *how = @"direct";
    if (!ok) { ok = SaveViaHelper(rec); how = ok ? @"helper" : @"failed"; }
    @synchronized (Lock ?: (Lock = [NSObject new])) { LastWrite = how; }
    PCReload();
    if (ok) { notify_post(MYB_PRIV_NOTIFY); PCRetire(); }
    return ok;
}
NSDictionary *PCStoreState(void) {
    if (!Lock) PCReload();
    NSDictionary *d = MYBPCStoreRead(StoreFile());
    NSString *last; BOOL read; @synchronized (Lock) { last = LastWrite; read = ReadOK; }
    return @{@"storeRead": @(read), @"migrated": @([d[MYB_PC_KEY_VERSION] intValue] >= 2), @"lastSave": last,
             @"oldListPending": @(PhoneArray(MYB_PC_PHONE_LOG).count > 0), @"queued": @(PhoneArray(MYB_PC_PHONE_QUEUE).count),
             @"rules": @(MYBPCEffective(MYBPCStoreLog(StoreFile()), nil).count > 0), @"switchOn": @(PCSwitchOn()),
             @"time": @((long long)NSDate.date.timeIntervalSince1970)};
}
void PCPublish(NSString *domain, NSString *key, NSDictionary *status) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)status, (__bridge CFStringRef)domain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)domain);
}
