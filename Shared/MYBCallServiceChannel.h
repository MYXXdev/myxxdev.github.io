// A small one-way mailbox from the call service part to Settings. The call service runs in a locked-down system process that is often not allowed to
// write files, so the report also travels in system notification states (a few bytes each, under names of our own) and in that process's OWN
// preferences domain, both of which it is normally allowed to use. Only class and method names ever go through; no number, name or call.
#import <Foundation/Foundation.h>
#import <notify.h>
#define MYB_CSC_NAME @"net.myxxdev.mybloxx.csd.%u"
#define MYB_CSC_MAX 1500u
#define MYB_CSC_OWN_DOMAIN CFSTR("com.apple.callservicesd")
#define MYB_CSC_OWN_KEY CFSTR("MYBCallServiceReport")

static inline void MYBCSCSetStateIn(NSString *fmt, unsigned index, uint64_t value) {
    int token = 0;
    NSString *name = [NSString stringWithFormat:fmt, index];
    if (notify_register_check(name.UTF8String, &token) != NOTIFY_STATUS_OK) return;
    notify_set_state(token, value);
    notify_cancel(token);
}
static inline uint64_t MYBCSCGetStateIn(NSString *fmt, unsigned index) {
    int token = 0; uint64_t value = 0;
    NSString *name = [NSString stringWithFormat:fmt, index];
    if (notify_register_check(name.UTF8String, &token) != NOTIFY_STATUS_OK) return 0;
    notify_get_state(token, &value);
    notify_cancel(token);
    return value;
}
// header: top byte 0xC5 marks "ours", then 16 bits of chunk count, then 32 bits of byte length
static inline void MYBCSCPublishIn(NSString *fmt, NSString *text) {
    NSData *raw = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSData *packed = [raw compressedDataUsingAlgorithm:NSDataCompressionAlgorithmZlib error:NULL] ?: raw;
    BOOL zipped = packed != raw;
    NSUInteger chunks = (packed.length + 7) / 8;
    if (chunks > MYB_CSC_MAX) { packed = [packed subdataWithRange:NSMakeRange(0, MYB_CSC_MAX * 8)]; chunks = MYB_CSC_MAX; zipped = NO; }
    for (NSUInteger i = 0; i < chunks; i++) {
        uint64_t word = 0; NSUInteger n = MIN((NSUInteger)8, packed.length - i * 8);
        [packed getBytes:&word range:NSMakeRange(i * 8, n)];
        MYBCSCSetStateIn(fmt, (unsigned)i + 1, word);
    }
    MYBCSCSetStateIn(fmt, 0, ((uint64_t)0xC5 << 56) | ((uint64_t)(zipped ? 1 : 0) << 48) | ((uint64_t)chunks << 32) | (uint64_t)packed.length);
}
static inline NSString *MYBCSCReadFrom(NSString *fmt) {
    uint64_t head = MYBCSCGetStateIn(fmt, 0);
    if ((head >> 56) != 0xC5) return nil;
    BOOL zipped = ((head >> 48) & 1) != 0; NSUInteger chunks = (NSUInteger)((head >> 32) & 0xFFFF), length = (NSUInteger)(head & 0xFFFFFFFFu);
    if (!chunks || chunks > MYB_CSC_MAX || length > chunks * 8) return nil;
    NSMutableData *data = [NSMutableData data];
    for (NSUInteger i = 0; i < chunks; i++) { uint64_t w = MYBCSCGetStateIn(fmt, (unsigned)i + 1); [data appendBytes:&w length:8]; }
    data.length = length;
    NSData *plain = zipped ? [data decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmZlib error:NULL] : data;
    return plain ? [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding] : nil;
}
static inline void MYBCSCPublish(NSString *text) { MYBCSCPublishIn(MYB_CSC_NAME, text); }
static inline NSString *MYBCSCRead(void) { return MYBCSCReadFrom(MYB_CSC_NAME); }
// The private list, from the phone's side to the call service: published by SpringBoard (which may read the preference file) whenever the list or its
// switch changes and whenever the call service asks, and read fresh by the call service for every incoming call. No preference cache is involved, so a
// change takes effect on the very next call.
#define MYB_CSL_NAME @"net.myxxdev.mybloxx.csl.%u"
#define MYB_CSL_NEED "net.myxxdev.mybloxx.csl.need"

// The same text also goes through the preference service itself (not the file): the call service reads the preference service, whose copy of a file that was
// written directly stays old until it restarts (a userspace reboot). Writing through the service keeps its copy current, so nothing needs restarting.
#define MYB_CSL_LIVE_DOMAIN CFSTR("net.myxxdev.mybloxx.live")
#define MYB_CSL_LIVE_KEY CFSTR("List")
