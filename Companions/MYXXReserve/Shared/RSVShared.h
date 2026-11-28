// MYXX Reserve — shared constants and pure helpers.
// Original code by MYXXdev. Used by every component (SpringBoard core,
// status-bar display hooks, thermalmonitord hook, sleep helper, Settings, CC).
#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#define RSV_VERSION "0.2.2"
// Build number is packed into every startup/status signal so Settings can
// tell "this exact version loaded" apart from a stale signal after upgrade.
#define RSV_BUILD 22

#define RSV_DOMAIN          "com.myxxdev.reserve"          // user settings (CFPreferences)
#define RSV_STATUS_DOMAIN   "com.myxxdev.reserve.status"   // human-readable status text
#define RSV_JOURNAL_DOMAIN  "com.myxxdev.reserve.journal"  // what reserve changed (crash-safe restore)

// ---- Darwin notifications. Names carry a 64-bit state readable from any
// process (including sandboxed apps), so no file paths are needed.
#define RSV_N_PREFS          "com.myxxdev.reserve/prefs-changed"
#define RSV_N_REQUEST        "com.myxxdev.reserve/request"        // state = RSVPackRequest()
#define RSV_N_THROTTLE       "com.myxxdev.reserve/throttle"       // state = 1 on, 0 off
#define RSV_N_DISPLAY_CFG    "com.myxxdev.reserve/display-config" // state = RSVPackDisplay()
#define RSV_N_SB_STATE       "com.myxxdev.reserve/state.springboard"
#define RSV_N_DISP_STATE     "com.myxxdev.reserve/state.display"
#define RSV_N_HELPER_STATE   "com.myxxdev.reserve/state.helper"
#define RSV_N_THERMAL_STATE  "com.myxxdev.reserve/state.thermal"

// ---- Requests (Settings / Control Center -> SpringBoard)
enum {
    RSVRequestNone        = 0,
    RSVRequestQuickTest   = 1, // overlay + lock + helper probe, auto-ends, no radios/LPM
    RSVRequestFullTest    = 2, // real reserve with a 2-minute safety auto-recover
    RSVRequestEnterNow    = 3, // manual reserve (CC toggle / Settings)
    RSVRequestRecoverNow  = 4,
    RSVRequestPing        = 5,
};

// ---- SpringBoard status codes (low byte of the "code" field)
enum {
    RSVSBNoSignal         = 0x00,
    RSVSBLoaded           = 0x01,
    RSVSBRequestReceived  = 0x02,
    RSVSBQuickTestRunning = 0x03,
    RSVSBQuickTestPassed  = 0x04,
    RSVSBEntering         = 0x05,
    RSVSBSleepRequested   = 0x06, // helper reported IOPMSleepSystem == kIOReturnSuccess
    RSVSBRecovered        = 0x07,
    RSVSBRestoredAfterRespring = 0x08,
    RSVSBFailHelperLaunch = 0x81,
    RSVSBFailSleep        = 0x82,
    RSVSBFailOverlay      = 0x83,
    RSVSBFailRecovery     = 0x84,
    RSVSBFailQuickTest    = 0x85,
    RSVSBBusy             = 0x86, // request ignored because reserve/test already running
};

// ---- Helper step codes
enum {
    RSVHelperStarted       = 0x01,
    RSVHelperProbeOK       = 0x02,
    RSVHelperAboutToSleep  = 0x03,
    RSVHelperSleepOK       = 0x04,
    RSVHelperRespringSent  = 0x05,
    RSVHelperNoRootDomain  = 0x81,
    RSVHelperNoPMConnect   = 0x82,
    RSVHelperSleepError    = 0x83,
    RSVHelperNoBackboardd  = 0x84,
    RSVHelperBadArgs       = 0x85,
};

// ---- Thermal hook codes
enum {
    RSVThermalLoaded       = 0x01,
    RSVThermalProductFound = 0x02,
    RSVThermalThrottled    = 0x03,
    RSVThermalUnthrottled  = 0x04,
    RSVThermalNoProduct    = 0x81,
    RSVThermalNoSelector   = 0x82,
};

// Helper exit codes (also visible to SpringBoard via waitpid)
enum {
    RSVExitOK = 0,
    RSVExitNoRootDomain = 10,
    RSVExitNoPMConnect = 12,
    RSVExitSleepError = 13,
    RSVExitNoBackboardd = 14,
    RSVExitBadArgs = 64,
};

// ---- 64-bit status word:  [63..48] build  [47..40] code  [39..32] detail  [31..0] unix time
static inline uint64_t RSVPackStatus(uint16_t build, uint8_t code, uint8_t detail, uint32_t t) {
    return ((uint64_t)build << 48) | ((uint64_t)code << 40) | ((uint64_t)detail << 32) | (uint64_t)t;
}
static inline uint16_t RSVStatusBuild(uint64_t s)  { return (uint16_t)(s >> 48); }
static inline uint8_t  RSVStatusCode(uint64_t s)   { return (uint8_t)((s >> 40) & 0xff); }
static inline uint8_t  RSVStatusDetail(uint64_t s) { return (uint8_t)((s >> 32) & 0xff); }
static inline uint32_t RSVStatusTime(uint64_t s)   { return (uint32_t)(s & 0xffffffffu); }

// ---- Request word: [63..56] request  [31..0] nonce
static inline uint64_t RSVPackRequest(uint8_t req, uint32_t nonce) { return ((uint64_t)req << 56) | nonce; }
static inline uint8_t  RSVRequestKind(uint64_t r)  { return (uint8_t)(r >> 56); }
static inline uint32_t RSVRequestNonce(uint64_t r) { return (uint32_t)(r & 0xffffffffu); }

// ---- Display config word: bit 63 = spoof on, [7..0] threshold
static inline uint64_t RSVPackDisplay(bool spoof, int threshold) {
    if (threshold < 1) threshold = 1;
    if (threshold > 99) threshold = 99;
    return (spoof ? (1ULL << 63) : 0) | (uint64_t)(threshold & 0xff);
}
static inline bool RSVDisplaySpoof(uint64_t w)     { return (w >> 63) & 1; }
static inline int  RSVDisplayThreshold(uint64_t w) { return (int)(w & 0xff); }

// ---- THE single percentage calculation, used by every display path.
//
// Sentinel 1.3.2 (verified in its arm64 disassembly):
//     fcvtzs( (double)((float)batteryLevel * 100.0f) - (double)threshold + 1.0 )
// i.e. trunc(level*100 - threshold + 1). With an integer true percentage this
// is exactly truePct - threshold + 1. We feed it the integer percentage the
// system itself is displaying, so the result is always "stock number minus
// (threshold - 1)", with no float-truncation off-by-one, and the threshold
// percentage shows as 1%.
static inline long long RSVDisplayedPercent(long long truePct, int threshold) {
    if (truePct < 0) return truePct;           // unknown level: leave alone
    if (threshold <= 1) return truePct;        // identity
    long long v = truePct - (long long)threshold + 1;
    if (v < 0) v = 0;
    if (v > 100) v = 100;
    return v;
}

// Integer battery percentage from UIDevice.batteryLevel (0.0–1.0).
// Rounds to nearest, matching how the status bar presents capacity.
static inline int RSVPercentFromLevel(float level) {
    if (level < 0.f) return -1;
    float p = level * 100.0f;
    int r = (int)(p + 0.5f);
    if (r > 100) r = 100;
    return r;
}

static inline uint32_t RSVNow(void) { return (uint32_t)time(NULL); }
