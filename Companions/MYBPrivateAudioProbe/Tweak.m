// MYbloXX Private Calls, audio probe (read-only).
// A busy signal means playing a short tone into a call that was just answered. Before anything is built for that, this part only LOOKS at the phone's audio
// system process: which audio and telephony classes it has, which audio libraries are loaded, and whether the audio-unit functions a call's sound goes
// through are present. It hooks nothing, changes nothing, plays nothing and never touches a call, a number or any sound. Only names and yes/no answers are
// written, to Settings, through a notification mailbox (Copy Calls Diagnostics reads it).
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <notify.h>
#import "../../Shared/MYBCallServiceChannel.h"

static BOOL Wanted(const char *name) {
    static const char *words[] = {"Telephony", "Voice", "Uplink", "Downlink", "VPIO", "AUVP", "Call", "Route", "Interruption", "AudioUnit", "Mixer"};
    for (size_t i = 0; i < sizeof(words) / sizeof(words[0]); i++) if (strstr(name, words[i])) return YES;
    return NO;
}
static void Probe(void) {
    @autoreleasepool {
        @try {
            NSMutableString *text = [NSMutableString stringWithFormat:@"process=%@ pid=%d\n", NSProcessInfo.processInfo.processName, getpid()];
            // loaded libraries that matter for call sound
            NSMutableArray *libs = [NSMutableArray array];
            for (uint32_t i = 0; i < _dyld_image_count() && libs.count < 80; i++) {
                const char *path = _dyld_get_image_name(i); if (!path) continue;
                const char *base = strrchr(path, '/'); base = base ? base + 1 : path;
                if (strstr(base, "Telephony") || strstr(base, "Voice") || strstr(base, "AudioToolbox") || strstr(base, "AVFAudio") || strstr(base, "AudioUnit") || strstr(base, "MediaToolbox") || strstr(base, "CoreAudio") || strstr(base, "AudioCodecs") || strstr(base, "Accessory")) [libs addObject:@(base)];
            }
            [text appendFormat:@"libs: %@\n", [libs componentsJoinedByString:@" "]];
            // audio-unit functions present?
            NSMutableArray *syms = [NSMutableArray array];
            for (NSString *s in @[@"AudioUnitRender", @"AudioUnitProcess", @"AudioUnitSetProperty", @"AudioOutputUnitStart", @"AudioComponentInstanceNew", @"AudioConverterFillComplexBuffer", @"AudioQueueNewInput", @"AudioQueueNewOutput", @"AudioServicesPlaySystemSound"]) [syms addObject:[NSString stringWithFormat:@"%@=%d", s, dlsym(RTLD_DEFAULT, s.UTF8String) ? 1 : 0]];
            [text appendFormat:@"symbols: %@\n", [syms componentsJoinedByString:@" "]];
            // classes that talk about telephony, voice or calls
            unsigned total = 0; Class *all = objc_copyClassList(&total);
            NSMutableArray *names = [NSMutableArray array];
            for (unsigned i = 0; i < total; i++) { const char *n = class_getName(all[i]); if (n && Wanted(n) && strncmp(n, "NS", 2) != 0 && strncmp(n, "_NS", 3) != 0 && names.count < 220) [names addObject:@(n)]; }
            free(all);
            [names sortUsingSelector:@selector(compare:)];
            [text appendFormat:@"classes(%lu): %@\n", (unsigned long)names.count, [names componentsJoinedByString:@" "]];
            // selectors of the few classes whose names suggest the call's sound path
            int shown = 0;
            for (NSString *name in names) {
                if (shown >= 14) break;
                if (!([name rangeOfString:@"Telephony"].location != NSNotFound || [name rangeOfString:@"VoiceProcessing"].location != NSNotFound || [name rangeOfString:@"Uplink"].location != NSNotFound)) continue;
                Class cls = NSClassFromString(name); unsigned n = 0; Method *list = cls ? class_copyMethodList(cls, &n) : NULL;
                NSMutableArray *sels = [NSMutableArray array];
                for (unsigned k = 0; k < n && sels.count < 40; k++) { const char *sel = sel_getName(method_getName(list[k])); if (sel[0] != '.' && strlen(sel) < 70) [sels addObject:@(sel)]; }
                free(list);
                [text appendFormat:@"%@: %@\n", name, [sels componentsJoinedByString:@" "]];
                shown++;
            }
            MYBCSCPublishIn(@"net.myxxdev.mybloxx.csm.%u", text);
        } @catch (NSException *e) { (void)e; }
    }
}
__attribute__((constructor)) static void Start(void) {
    if (![NSProcessInfo.processInfo.processName isEqualToString:@"mediaserverd"]) return;
    MYBCSCPublishIn(@"net.myxxdev.mybloxx.csm.%u", @"alive: the audio probe is loaded, report follows");
    static int askToken = 0;
    notify_register_dispatch("net.myxxdev.mybloxx.csm.probe", &askToken, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int t) { (void)t; Probe(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ Probe(); });
}
