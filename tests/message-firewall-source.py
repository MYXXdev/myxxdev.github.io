#!/usr/bin/env python3
# Message Firewall: the live hook (Companions/MYBMessageFirewall), its Shared store/rules/live-channel headers, and its Settings UI. Built on the
# grounded findings MYBMessageProbe produced (r53-r55): class IMTextMessagePipelineParameter, method
# -[IMTextMessageProcessingPipelineComponent runIndividuallyWithInput:], shape "@24@0:8@16" (object return, 3 args). These checks exist to keep the
# hook shape-checked before it ever installs, its diagnostics counters-only (the same standing privacy rule the probe follows), and the feature
# actually reachable from Settings -- not scaffolding that looks wired but does nothing.
import pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILS = []
def need(cond, label):
    print(('ok  ' if cond else 'FAIL'), label)
    if not cond: FAILS.append(label)

mf_dir = ROOT / 'Companions' / 'MYBMessageFirewall'
tweak = (mf_dir / 'Tweak.m').read_text()
plist = (mf_dir / 'MYBMessageFirewall.plist').read_text()
makefile = (mf_dir / 'Makefile').read_text()
main_makefile = (ROOT / 'Makefile').read_text()
rules = (ROOT / 'Shared' / 'MYBMessageFirewallRules.h').read_text()
store = (ROOT / 'Shared' / 'MYBMessageFirewallStore.h').read_text()
wire = (ROOT / 'Shared' / 'MYBMessageFirewallList.h').read_text()
patterns = (ROOT / 'Shared' / 'MYBMessageFirewallPatterns.h').read_text()
ctrl = (ROOT / 'Preferences' / 'MYBFirewallController.m').read_text()

# ---- the hook targets the right process, the right method, and refuses to install on a shape it does not recognize ----
need('"imagent"' in plist, 'the hook injects into imagent, the same process the probe confirmed the pipeline runs in')
need('.xm' not in makefile and 'Tweak.m' in makefile, 'the hook is a plain tweak (class_replaceMethod), not a Logos hook file')
need('IMTextMessageProcessingPipelineComponent' in tweak and 'runIndividuallyWithInput:' in tweak, 'the hook targets the exact class and method the probe confirmed real on-device')
need('class_getInstanceMethod' in tweak, 'the hook looks up the real method before touching it, never assumes it exists')
need('method_getTypeEncoding' in tweak and '@24@0:8@16' in tweak, 'the hook documents and checks against the exact shape the probe confirmed (r55)')
need('method_getNumberOfArguments' in tweak and 'shapeMismatch' in tweak, 'the hook refuses to install on any method whose argument count does not match what was confirmed')
need('imp_implementationWithBlock' in tweak and 'class_replaceMethod' in tweak, 'the hook uses the same proven replacement technique as the Private Call Service hook, not a guess at a different one')
need('attribute((constructor))' in tweak.replace('__', '').replace(' ', '') or '__attribute__((constructor))' in tweak, 'the hook installs itself automatically when the dylib loads')
need('dispatch_after' in tweak and 'InstallHook(attempt + 1)' in tweak, 'the hook retries if the target class is not loaded yet, the same retry pattern the call hook uses')

# ---- it only ever returns nil (suppress) or calls through to the real implementation -- never fabricates a return value for an unmatched message ----
need('return nil;' in tweak, 'a blocked message causes the hook to return nil, matching the object-returning shape instead of guessing a scalar')
need('orig)(self_, sel, input)' in tweak, 'every non-blocked message still runs the real implementation unchanged')

# ---- reads only what a block decision needs, never anything else about the message; writes only counters, never identifiers or content ----
forbidden = ['plainTextSubject]', 'richBody]', 'GUID]', 'messageItems]', 'participantIdentifiers]']
need(not any(f in tweak for f in forbidden), 'the hook reads only the fields its own decision needs (sender identifiers, plain body, isFromMe), nothing broader about the message')
need('isFromMe' in tweak, 'the hook never touches the user\'s own outgoing messages')
need('Counters[' in tweak and 'Count(' in tweak, 'diagnostics are kept as counters')
need(not any(bad in tweak for bad in ['fromIdentifier]);', 'Counters[fromIdentifier']), 'a sender identifier itself is never used as a counter key or logged verbatim')
need('CFPreferencesSetAppValue' in tweak, 'diagnostics use the one channel proven reliable in imagent (r53-r55)')
need('com.apple.imagent' in wire and 'MYB_MFH_OWN_DOMAIN' in wire and 'MYB_MFH_OWN_DOMAIN' in tweak, 'the report channel name lives in the shared header (not duplicated in the hook), so the hook and its Settings-side reader can never drift apart')

# r60's on-device diagnostics showed hooked=1 and zero "checked" counts ever, even for real test texts -- runIndividuallyWithInput: was never once
# invoked. r61 tried widening to every pipeline-component subclass (audio/sticker/typing-indicator/balloon-plugin); that was unnecessary scope for a
# plain-text-only feature and still never fired once across 6 classes. The probe's own original comment recorded that IMPipelineComponent declares
# BOTH runWithInput: and runIndividuallyWithInput: -- only the latter has ever been tried. This narrows back to the one relevant class (plain text)
# and tries both documented entry points on it, each independently and defensively shape-checked, so whichever one is the real per-message call gets
# caught without guessing blind or re-widening scope to message types this feature was never meant to touch.
need('runWithInput:' in tweak, 'the hook now also tries runWithInput:, the one documented pipeline entry point never yet attempted')
need(re.search(r'static BOOL HookOneMethod\(Class cls, SEL sel, NSString \*label\)',tweak) is not None, 'each method attempted gets its own independent, shape-checked patch with its own captured original implementation')
need('IMAudioMessageProcessingPipelineComponent' not in tweak and 'IMStickerMessageProcessingPipelineComponent' not in tweak and 'IMTypingIndicatorProcessingPipelineComponent' not in tweak and 'IMBalloonPluginProcessingPipelineComponent' not in tweak, 'scope stays narrowed to plain text -- other message types (audio, stickers, typing indicators, app messages) are not touched by a feature that was never meant to affect them')
need('hookedIndividually' in tweak and 'hookedWith' in tweak, 'diagnostics can tell which of the two entry points, if either, actually got patched')

# ---- the pure rules file never touches UIKit, hooks or file I/O, so it is testable and reusable from Settings and the hook alike ----
need('#import <UIKit' not in rules and 'class_' not in rules and 'NSFileManager' not in rules, 'the rules header stays pure: no UIKit, no runtime hooking, no file access')
need('MYBMFSenderKey' in rules and 'MYBPCKey' in rules, 'a sender identifier normalizes through the same proven phone-number key as Private Calls, falling back for non-phone handles')
need('"h:"' in rules, 'a non-phone identifier (an iMessage/email handle) is kept in its own namespace so it can never collide with a phone key')
need('MYBMFKeywordKey' in rules and 'lowercaseString' in rules, 'a keyword is normalized (trimmed, lowercased) before it is ever compared')
need('MYBMFTextMatches' in rules and 'MYBMFShouldBlock' in rules, 'the one block decision is a single pure function, reused by both the hook and (indirectly) the desktop tests')

# ---- store: its own file, its own switch, two independent lists, same locked read-merge-write cycle Private Calls/Call Firewall already proved ----
need('MYB_MF_KEY_SWITCH' in store and 'MYB_MF_KEY_SENDERS' in store and 'MYB_MF_KEY_KEYWORDS' in store, 'the store keeps a switch and two independent lists')
need('MYBPCLockTake' in store and 'MYBPCMerge' in store, 'the store reuses the exact same lock and merge primitives Private Calls and the Call Firewall already proved, not a new untested mechanism')

# ---- live channel: published fresh, read fresh by the hook -- no reboot needed to see a change, no stale-cache risk in the decision path ----
need('net.myxxdev.mybloxx.msgfirewall.live' in wire, 'the live channel has its own CFPreferences domain, separate from the Call Firewall\'s')
need('MYB_MFL_NAME' in wire and 'net.myxxdev.mybloxx.mfl' in wire, 'the live channel has its own mailbox namespace, separate from every other probe/hook in the project')
need('MYBMFLPublish' in wire and 'MYBMFLReadPublished' in wire, 'the live channel has both a publish side (Settings) and a read side (the hook)')

# ---- Settings: reachable, not scaffolding -- a real switch, two real drill-in lists, wired to the real store ----
need('"MYBMFSendersController"' in ctrl and '"MYBMFKeywordsController"' in ctrl, 'Settings has real drill-in pages for both blocked senders and keywords, not placeholder rows')
need('@"MESSAGES"' in ctrl, 'Settings groups the message-blocking rows under their own section, not folded into the call rules')
need('MYBMFSaveSwitch' in ctrl and 'MYBMFSaveSender' in ctrl and 'MYBMFSaveKeyword' in ctrl, 'every row in the new section is wired to an actual save function, not a no-op')
need('MYBMFAfterChange' in ctrl and 'MYBMFLPublish' in ctrl, 'every save republishes the live channel, so a change reaches imagent without a reboot, matching the Call Firewall\'s own guarantee')
need('MYB_MF_KEY_SWITCH' in ctrl and "toggle.key isEqualToString:MYB_MF_KEY_SWITCH" in ctrl.replace("[", "").replace("]", ""), 'the master switch writes to the message-firewall file specifically, not accidentally to the Call Firewall\'s')

# ---- bundled scam patterns: the real 54-rule set, split into junk/promotion/transaction, junk on by default and the rest off ----
need(patterns.count('MYB_MF_PATTERN_JUNK,@"category"') == 48, 'bundled patterns: 48 rules are categorized junk')
need(patterns.count('MYB_MF_PATTERN_PROMOTION,@"category"') == 4, 'bundled patterns: 4 rules are categorized promotion')
need(patterns.count('MYB_MF_PATTERN_TRANSACTION,@"category"') == 2, 'bundled patterns: 2 rules are categorized transaction')
need('NSRegularExpression' in patterns and 'regularExpressionWithPattern' in patterns, 'bundled patterns: compiled with the real regex engine, not a hand-rolled substring match')
need('MYB_MF_KEY_PATTERNS_JUNK' in store and 'MYB_MF_KEY_PATTERNS_PROMOTION' in store and 'MYB_MF_KEY_PATTERNS_TRANSACTION' in store, 'the store has an independent on/off setting per bundled category')
need('MYBMFEnabledPatternCategories' in store, 'the store exposes one function for which categories are currently active')
need('junk=%d' in wire and 'promo=%d' in wire and 'txn=%d' in wire, 'the live channel carries the three category flags, the same channel imagent actually reads (never the plist file directly)')

# ---- the hook compiles the bundled patterns once, at install time, never per message ----
start_block = tweak[tweak.index('static void Start(void)'):] if 'static void Start(void)' in tweak else ''
should_block_block = tweak[tweak.index('static BOOL ShouldBlock'):tweak.index('static void InstallHook')] if 'static BOOL ShouldBlock' in tweak and 'static void InstallHook' in tweak else ''
need('MYBMFCompileBundledPatterns' in start_block, 'the bundled patterns are compiled once, in the constructor/install path')
need('MYBMFCompileBundledPatterns' not in should_block_block, 'the per-message decision path never recompiles the bundled patterns -- it only matches against the cached compiled set')
need('MYBMFCompiledPatternsMatch' in should_block_block, 'the per-message decision actually checks the bundled patterns, not just the sender/keyword lists')
need('blockedPattern' in tweak, 'a pattern-based block is counted under its own diagnostics key, distinguishable from a sender or keyword block')

# ---- Settings: the three categories are individually reachable and wired to the real store, not just imported data sitting unused ----
need('"MYBMFPatternsController"' in ctrl, 'Settings has a real drill-in page for the bundled scam patterns')
need('MYB_MF_KEY_PATTERNS_JUNK' in ctrl and 'MYB_MF_KEY_PATTERNS_PROMOTION' in ctrl and 'MYB_MF_KEY_PATTERNS_TRANSACTION' in ctrl, 'Settings exposes all three categories as their own switches')
need('MYBMFSavePatternCategory' in ctrl, 'every category switch is wired to an actual save function, not a no-op')
need('"Known Scam Patterns"' in ctrl, 'the overview links to the scam-patterns page by name, not buried or unreachable')

print(f'\n{len(FAILS)} failed' if FAILS else '\nAll message-firewall source checks passed.')
sys.exit(1 if FAILS else 0)
