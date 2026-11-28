// myxxreserved — MYXX Reserve native power helper.
// Original code by MYXXdev.
//
// Why a separate process: Sentinel 1.3.2 (the known-good baseline on this
// phone) never calls the sleep API from SpringBoard. Its SpringBoard dylib
// launches a separate unsandboxed jailbreak binary that carries
// `platform-application`, and that binary does:
//     setuid(0); setuid(0); setgid(0); setgid(0);
//     e = IORegistryEntryFromPath(kIOMasterPortDefault,
//             "IOPower:/IOPowerConnection/IOPMrootDomain");
//     IORegistryEntrySetCFProperty(e, CFSTR("System Boot Complete"), kCFBooleanTrue);
//     fb = IOPMFindPowerManagement(kIOMasterPortDefault);
//     IOPMSleepSystem(fb);
// This helper reproduces that sequence (same order, same arguments) and adds
// what Sentinel lacked: every result is recorded so a failure is visible.
//
// Modes:
//   myxxreserved sleep    – the sequence above (real system sleep request)
//   myxxreserved probe    – open the root domain + PM connection, report, no sleep,
//                           no property change (safe at any charge)
//   myxxreserved respring – terminate backboardd (Sentinel's recovery action)

#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach.h>
#include <notify.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "../Shared/RSVShared.h"

// ---- IOKit prototypes (the iOS SDK ships IOKit.tbd but no headers)
typedef mach_port_t io_object_t;
typedef io_object_t io_registry_entry_t;
typedef io_object_t io_connect_t;
typedef io_object_t io_service_t;
typedef kern_return_t IOReturn;
extern const mach_port_t kIOMasterPortDefault;
extern io_registry_entry_t IORegistryEntryFromPath(mach_port_t mainPort, const char *path);
extern kern_return_t IORegistryEntrySetCFProperty(io_registry_entry_t entry, CFStringRef name, CFTypeRef value);
extern kern_return_t IOObjectRelease(io_object_t object);
extern io_connect_t IOPMFindPowerManagement(mach_port_t mainPort);
extern CFMutableDictionaryRef IOServiceMatching(const char *name);
extern io_service_t IOServiceGetMatchingService(mach_port_t mainPort, CFDictionaryRef matching);
extern kern_return_t IOServiceOpen(io_service_t service, task_port_t owningTask, uint32_t type, io_connect_t *connect);
extern IOReturn IOPMSleepSystem(io_connect_t fb);
extern kern_return_t IOServiceClose(io_connect_t connect);

// ---- libproc prototypes (not in the iOS SDK headers; exported by libSystem)
extern int proc_listallpids(void *buffer, int buffersize);
extern int proc_name(int pid, void *buffer, uint32_t buffersize);

static void report(uint8_t step, uint32_t value) {
    // detail byte: bit0 = running as root (euid 0), bit1 = setuid(0) succeeded
    static uint8_t detail = 0;
    if (step == RSVHelperStarted) detail = (uint8_t)value;
    int token = 0;
    if (notify_register_check(RSV_N_HELPER_STATE, &token) == NOTIFY_STATUS_OK) {
        // For helper results the low 32 bits carry the raw IOReturn/value
        // instead of a timestamp; SpringBoard timestamps the event itself.
        uint64_t w = RSVPackStatus(RSV_BUILD, step, detail, value);
        notify_set_state(token, w);
        notify_cancel(token);
    }
    notify_post(RSV_N_HELPER_STATE);
    fprintf(stderr, "myxxreserved: step=0x%02x value=0x%08x euid=%d\n", step, value, geteuid());
}

static int do_power(bool reallySleep) {
    // Same privilege attempt as the baseline. If the binary was not started
    // with root rights these fail harmlessly; the euid is recorded so the
    // Settings page can show which context actually ran.
    int su = setuid(0);
    (void)setuid(0);
    (void)setgid(0);
    (void)setgid(0);
    uint8_t ctx = (geteuid() == 0 ? 1 : 0) | (su == 0 ? 2 : 0);
    report(RSVHelperStarted, ctx);

    io_registry_entry_t root = IORegistryEntryFromPath(kIOMasterPortDefault,
                                   "IOPower:/IOPowerConnection/IOPMrootDomain");
    if (!root) {
        report(RSVHelperNoRootDomain, 0);
        return RSVExitNoRootDomain;
    }
    if (reallySleep) {
        // Baseline marks boot complete so the root domain accepts the request.
        kern_return_t kp = IORegistryEntrySetCFProperty(root, CFSTR("System Boot Complete"), kCFBooleanTrue);
        if (kp != KERN_SUCCESS)
            fprintf(stderr, "myxxreserved: System Boot Complete set returned 0x%08x (continuing, as baseline does)\n", kp);
    }
    IOObjectRelease(root);

    // Open the root-domain connection ourselves (this is what
    // IOPMFindPowerManagement does internally) so the kernel's exact refusal
    // code is recorded instead of a bare "0".
    io_connect_t fb = 0;
    kern_return_t ko = KERN_FAILURE;
    io_service_t svc = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if (svc) {
        ko = IOServiceOpen(svc, mach_task_self(), 0, &fb);
        IOObjectRelease(svc);
    }
    if (ko != KERN_SUCCESS || !fb) {
        fb = IOPMFindPowerManagement(kIOMasterPortDefault);   // baseline call, as a second try
    }
    if (!fb) {
        report(RSVHelperNoPMConnect, (uint32_t)ko);
        return RSVExitNoPMConnect;
    }
    if (!reallySleep) {
        IOServiceClose(fb);
        report(RSVHelperProbeOK, ctx);
        return RSVExitOK;
    }

    report(RSVHelperAboutToSleep, 0);
    IOReturn kr = IOPMSleepSystem(fb);
    IOServiceClose(fb);
    if (kr != 0) {
        report(RSVHelperSleepError, (uint32_t)kr);
        return RSVExitSleepError;
    }
    report(RSVHelperSleepOK, 0);
    return RSVExitOK;
}

static int find_pids(const char *name, pid_t *out, int max) {
    int cap = 4096;
    pid_t *pids = calloc((size_t)cap, sizeof(pid_t));
    if (!pids) return 0;
    int n = proc_listallpids(pids, cap * (int)sizeof(pid_t));
    int found = 0;
    for (int i = 0; i < n && found < max; i++) {
        char buf[256] = {0};
        if (pids[i] > 0 && proc_name(pids[i], buf, sizeof(buf)) > 0 && strcmp(buf, name) == 0)
            out[found++] = pids[i];
    }
    free(pids);
    return found;
}

static int do_respring(void) {
    (void)setuid(0);
    pid_t pids[8];
    int n = find_pids("backboardd", pids, 8);
    if (n == 0) {
        report(RSVHelperNoBackboardd, 0);
        return RSVExitNoBackboardd;
    }
    for (int i = 0; i < n; i++) kill(pids[i], SIGTERM);   // what `killall backboardd` sends
    report(RSVHelperRespringSent, (uint32_t)n);
    // If it is still alive after 2 s, force it.
    sleep(2);
    for (int i = 0; i < n; i++) {
        if (kill(pids[i], 0) == 0) kill(pids[i], SIGKILL);
    }
    return RSVExitOK;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        report(RSVHelperBadArgs, 0);
        return RSVExitBadArgs;
    }
    if (strcmp(argv[1], "sleep") == 0)    return do_power(true);
    if (strcmp(argv[1], "probe") == 0)    return do_power(false);
    if (strcmp(argv[1], "respring") == 0) return do_respring();
    report(RSVHelperBadArgs, 0);
    return RSVExitBadArgs;
}
