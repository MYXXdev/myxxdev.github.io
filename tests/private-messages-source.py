#!/usr/bin/env python3
# Private Conversations: Messages-only scope, thread identity, move/return/restore, pre-existing mute state, background lock, upgrade and uninstall behaviour.
import re,sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
def R(p):return (ROOT/p).read_text(encoding='utf-8')
bad=[]
def need(c,m):
    print(('ok   ' if c else 'FAIL ')+m)
    if not c:bad.append(m)
core=R('Companions/MYBPrivateMessages/PMCore.m');ui=R('Companions/MYBPrivateMessages/PMUI.m');tw=R('Companions/MYBPrivateMessages/Tweak.x')
mk=R('Companions/MYBPrivateMessages/Makefile');pl=R('Companions/MYBPrivateMessages/MYBPrivateMessages.plist');adv=R('Preferences/MYBAdvancedController.m')
strip=lambda t:re.sub(r'//[^\n]*','',re.sub(r'/\*.*?\*/','',t,flags=re.S))
allsrc=strip(core)+strip(ui)+strip(tw)
# scope
need('com.apple.MobileSMS' in pl and pl.count('com.apple')==1,'filter plist names Messages only')
need(bool(re.search(r'if \(!\[bundle isEqualToString:@"com.apple.MobileSMS"\]\) return;',tw)),'the tweak returns at once in any other process')
need(not re.search(r'CommCenter|CarrierBundle|CTCellularPlan|CoreTelephony|CTTelephony|imagent|IMDaemon|sqlite3|\.db"|sms\.db',allsrc),'no CommCenter, carrier, eSIM, telephony, daemon or database access')
need('PMInstallHooks' in tw and 'majorVersion != 16' in tw,'hooks are installed on iOS 16 only; elsewhere Messages is left alone')
need('Companions/MYBPrivateMessages' in R('Makefile'),'the component is built with the package')
# off by default and fail-closed
need('MYBConnFlag(Prefs, MYB_PRIV_KEY_MESSAGES)' in core and 'ListHooked' in core.split('BOOL PMActive')[1][:120],'inactive unless switched on and the list hooks were found')
need('if (!ListHooked)' in core and 'if (!MuteReady())' in core,'a move is refused when threads cannot be hidden or alerts cannot be silenced')
# identity
need('CC_SHA256' in core and 'guid' in core and '%@|%@' in core and 'Salt()' in core,'identity is a salted hash of the exact chat GUID')
need(not re.search(r'(participants|handles|chatIdentifier|displayName.*Entries)',core.split('NSString *PMIdentity')[1].split('BOOL PMIsPrivate')[0]),'identity never uses a participant, so one shared contact does not make threads private')
need('objc_getAssociatedObject(conversation, &IDKey)' in core and 'never cache a miss' in core,'identity is cached per conversation and misses are not cached')
need(not re.search(r'setObject:[^;]*(guid|PMTitle|text|body|address)',core) and 'was' in core and 'state' in core,'only the hash, the earlier alert state and a state word are stored')
# mute: record, verify, roll back, truth
need("@\"was\": @(was)" in core and 'ReadMute(conversation, &was)' in core,'whether alerts were already hidden is recorded before anything changes')
need('0.7 * NSEC_PER_SEC' in core and '0.5 * NSEC_PER_SEC' in core and 'proven()' in core and 'NoteIdentity' in core,'the mute change is read back at once and again before it is reported')
need('[now removeObjectForKey:identity]' in core and 'SetMute(conversation, was' in core and 'Hide Alerts may have changed' in core,'a failed move is undone and reports the real mute state')
need('@"state": @"moving"' in core and '@"state": @"returning"' in core and 'PMReconcile' in core,'half-done moves and returns are journaled and finished on the next launch')
need('if (was || !conversation) { finish(was); return; }' in core and 'SetMute(conversation, NO, finish)' in core,'return restores the earlier mute state and leaves it alone when it was already on')
need('Returned to Messages, but Hide Alerts is still on' in core,'a failed unmute still returns the thread and says alerts are still hidden')
# hiding
need('Bypass' in core and 'onversations' in core and 'imp_implementationWithBlock' in core,'ChatKit list getters are filtered for screens while ChatKit itself sees every conversation')
need('Hidden()' in core and 'containsObject:identity' in core,'filtering matches the exact identity')
need('leadingSwipeActionsConfigurationForIndexPath:' in core and 'PrivateSwipe' in core and 'PMSessionUnlocked()' in core and 'PMUIMoveFromMenu(conversation)' in core,'Private is a swipe action on the ordinary list, only while the private session is unlocked, and Apple\'s own menu gets no extra item')
need('@catch (NSException' in core,'a missing menu property leaves Messages unchanged')
# gesture
need('numberOfTapsRequired = 5' in tw and 'TouchOnTitle' in tw and 'viewControllers.count == 1' in tw and 'cancelsTouchesInView = NO' in tw,'five taps, only on the title, normal touches untouched')
need('TitleLabel(nav.navigationBar' in tw and 'navigationItem.title' in tw,'the title is found by what is on screen (large or collapsed)')
# lock
need('UIApplicationDidEnterBackgroundNotification' in tw and 'UIApplicationWillResignActiveNotification' in tw and 'UIApplicationProtectedDataWillBecomeUnavailable' in tw,'background, resign-active and phone lock are all handled')
need('PMCoverIfNeeded' in tw and 'UIWindowLevelAlert + 1000' in ui and 'PrivateNav.view.hidden = YES' in ui,'a cover hides the private list and any open private thread from the app switcher snapshot')
need('PMPopPrivateThread' in ui and 'PMNoteTop' in core and 'if (!PMSessionUnlocked())' in core,'a private thread opened without the session is sent back to the list')
need('LAPolicyDeviceOwnerAuthentication' in ui and 'MYB_PRIV_KEY_MESSAGES_LOCK' in core and 'if (!PMLockOn())' in ui,'optional device authentication is the lock; the gesture is only the shortcut')
need('canEvaluatePolicy' in ui and 'Device lock needed' in ui,'with the lock on and no passcode set the list stays closed and says why')
# UI
need('PMOpenNative' in ui and 'showConversation:animated:' in core,'selecting a thread opens the native Messages conversation')
need('Return to Messages' in ui and 'confirmReturn' in ui and 'trailingSwipeActions' in ui,'Return to Messages is available in the private list')
need('MYXXShowChoice' in ui and 'MYXXShowMessage' in ui and 'MYXXStyleNavigation' in ui,'the list and sheets use the shared MYbloXX® look')
need('MYXXShowTipFactsOnce' in ui and 'Conversations stay in Apple Messages' in ui and 'jailbreak is not active' in ui,'one tip with the gesture and the honest caveat; Replay Tips shows it again')
need('PMPickerController' in ui and 'PMOrdinaryConversations' in ui,'a picker adds a conversation from inside the private list as a fallback')
# diagnostics privacy
need('method names only' in core and 'PMTitle' not in core.split('void PMPublishStatus')[1].split('void PMCountMenuUse')[0],'diagnostics carry counts and selector names, never names, numbers or text')
# settings and upgrade/uninstall
need('MYB_PRIV_KEY_MESSAGES' in adv and 'MYB_PRIV_KEY_MESSAGES_LOCK' in adv and 'PRIVATE CONVERSATIONS' in adv and adv.index('PRIVATE ALBUM')<adv.index('PRIVATE CONVERSATIONS'),'Settings: opt-in rows sit under Extra Privacy Protection after Private Album')
need('Turn Off and Restore Alerts' in adv and 'Restore Alerts Now' in adv and 'requestRestore' in adv,'turning it off offers to restore alerts; a restore button stays available')
need(core.count('PMReconcile')>=3 and 'restoreAll' in core and 'Prefs[MYB_PRIV_KEY_MESSAGES_RESTORE]' in core and 'if (!PMSwitchOn()) PMLockAll();' in tw,'restore runs whatever the switch says; switching off closes the session and shows every thread')
need('Restore Alerts Now' in R('layout/DEBIAN/prerm'),'removal warns to restore alerts first')
need('kEntries' in core and 'NSUserDefaults' in core and 'removeObjectForKey:kEntries' not in core,'assignments live in Messages preferences and are never cleared by an upgrade')
core2=core
need('performWithSender:nil target:nil' in core and 'FindAlertsAction' in core and 'StockAction' in core,'without a private setter, the stock Hide Alerts / Show Alerts menu action itself is performed')
need('[state isEqual:@"private"]) [hidden addObject:key]' in core and 'still visible until alerts are proven silenced' in core,'a thread is hidden only after Hide Alerts is proven, never before')
need('PrivateNav = nil; [self.navigationController dismissViewControllerAnimated' in ui and '!PrivateNav.presentingViewController' in ui,'closing the private list releases it, so five taps open it again')
need('done(NO, @"pending")' in core and 'if (restoreAll && !pending)' in core,'a restore that could not reach the row stays pending and is retried')
need('objc_copyClassNamesForImage' in core and 'contextMenuConfigurationForItemsAtIndexPaths' in core and 'contextMenuInteraction:configurationForMenuAtLocation:' in core and 'menuProbe' in core,'the long-press menu is found by what ChatKit list classes implement (single, iOS 16 multi-item, interaction), and the names are published')
need('PMScanList' in core and 'interactions' in core and 'view.delegate' in core and 'PMScanList(top)' in tw,'the menu hookup is also read from the live list and its rows, and hooked before a long-press')
need('copyDiagnostics' in adv and 'Copies class and menu names only' in adv,'Settings can copy the Messages diagnostics (names only)')
need('setMutedUntilDate:' in core and 'distantFuture' in core and 'canMuteStateBeToggled' in core and '@"unmute"' in core,'iOS 16.5.1 (device evidence): Hide Alerts is CKConversation setMutedUntilDate: / unmute, read with isMuted, guarded by canMuteStateBeToggled')
need('_dci_collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:' in core,'iOS 16.5.1 (device evidence): the list builds its long-press menu through the _dci_ multi-item method')
need('containsString:@"racked"' in core,'ChatKit tracking list is never filtered')
need('FilterSnapshot' in core and 'UICollectionViewDiffableDataSourceReference' in core and 'deleteItemsWithIdentifiers' in core and 'dlsym(RTLD_DEFAULT' in core,'rows applied to the list are filtered at the data-source level by chat identifier (in memory only)')
need('lookup' in core and '[name hasPrefix:@"conversationFor"]' in core and 'if (!lookup) continue;' in core,'only ChatKit lookups see the unfiltered list; refreshes it triggers are still filtered')
need('RevealIdentity' in core and 'collectionView:didSelectItemAtIndexPath:' in core and 'showConversation:animated:' in core and 'openProbe' in core,'opening a private thread tries every show-conversation variant, then selects the row like a tap')
sys.exit(1 if bad else 0)

_pm=open('Companions/MYBPrivateMessages/PMCore.m').read()
need('PrivateSwipe' in _pm and 'leadingSwipeActionsConfigurationForIndexPath:' in _pm and 'swipeSeen' in _pm,'the swipe is added where the list asks for its trailing actions')
