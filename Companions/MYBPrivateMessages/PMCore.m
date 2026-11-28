#import "PMCore.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <CommonCrypto/CommonDigest.h>
#import <roothide.h>
#import "../../Shared/MYBConnectivity.h"

#define MSG(ret, ...) ((ret (*)(id, SEL, ##__VA_ARGS__))objc_msgSend)

// ---- state --------------------------------------------------------------------------------------------------------------------------------
// Messages' own preference domain (the only place this sandboxed process may write). Entry: identity hash -> {was: BOOL (alerts already hidden before
// MYbloXX®), state: "moving" (alerts being silenced, still visible) | "private" (hidden) | "returning" (visible again)}. A "returning" or "moving" entry is a half-done change that PMReconcile finishes.
static NSString *const kEntries = @"MYBPMEntries", *const kSalt = @"MYBPMSalt", *const kStatus = @"MYBPMStatus", *const kRestoreDone = @"MYBPMRestoreDone";
static NSDictionary *Prefs;
static NSSet *HiddenSet;                 // identities hidden from the ordinary list (state private or moving)
static NSObject *Lock;
static BOOL ListHooked, SessionOn;
static NSInteger Generation;                 // bumped whenever the hidden set changes
static NSString *RevealIdentity;             // a private thread being opened from the private list: shown to the list for a moment
static NSMutableArray<NSString *> *ListHookNames, *ProbeNames, *SearchProbe, *SearchClasses;
static int MenuUses;
static __thread int Bypass;               // >0 while ChatKit itself is working on its own list: it must see every conversation

static NSInteger SwipeProviders, SwipeOffered, SwipeSeen;
static NSMutableArray<NSString *> *SwipeProbe;   // counts only, for the status line
static NSUserDefaults *Defaults(void) { return NSUserDefaults.standardUserDefaults; }
static NSMutableDictionary *Entries(void) {
    NSDictionary *saved = [Defaults() dictionaryForKey:kEntries];
    return saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
}
static void SaveEntries(NSDictionary *entries) {
    NSMutableSet *hidden = [NSMutableSet set];
    for (NSString *key in entries) {
        NSString *state = entries[key][@"state"];
        if ([state isEqual:@"private"]) [hidden addObject:key];
    }
    @synchronized (Lock) { HiddenSet = hidden; Generation++; }
    [Defaults() setObject:entries forKey:kEntries];
    [Defaults() synchronize];
}
static NSSet *Hidden(void) { @synchronized (Lock) { return HiddenSet; } }

void PMReloadPrefs(void) { Prefs = [NSDictionary dictionaryWithContentsOfFile:MYBPrivPrefsFile()] ?: @{}; }
BOOL PMSwitchOn(void) { return MYBConnFlag(Prefs, MYB_PRIV_KEY_MESSAGES); }
BOOL PMLockOn(void) { return MYBConnFlag(Prefs, MYB_PRIV_KEY_MESSAGES_LOCK); }
BOOL PMActive(void) { return PMSwitchOn() && ListHooked; }

// ---- identity -----------------------------------------------------------------------------------------------------------------------------
static char IDKey;
static id ChatOf(id conversation) {
    if (!conversation) return nil;
    if ([conversation respondsToSelector:@selector(chat)]) return MSG(id)(conversation, @selector(chat));
    if ([conversation respondsToSelector:@selector(guid)]) return conversation;
    return nil;
}
static NSString *Salt(void) {
    NSString *salt = [Defaults() stringForKey:kSalt];
    if (!salt.length) { salt = NSUUID.UUID.UUIDString; [Defaults() setObject:salt forKey:kSalt]; }
    return salt;
}
NSString *PMIdentity(id conversation) {
    if (!conversation) return nil;
    NSString *cached = objc_getAssociatedObject(conversation, &IDKey);
    if (cached) return cached;
    id chat = ChatOf(conversation);
    NSString *guid = [chat respondsToSelector:@selector(guid)] ? MSG(id)(chat, @selector(guid)) : nil;
    if (![guid isKindOfClass:NSString.class] || !guid.length) return nil;   // not ready yet: never cache a miss
    NSData *input = [[NSString stringWithFormat:@"%@|%@", Salt(), guid] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(input.bytes, (CC_LONG)input.length, digest);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < 12; i++) [hex appendFormat:@"%02x", digest[i]];
    objc_setAssociatedObject(conversation, &IDKey, hex, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return hex;
}
BOOL PMIsPrivate(id conversation) {
    NSString *identity = PMIdentity(conversation);
    return identity && [Hidden() containsObject:identity];
}
NSString *PMTitle(id conversation) {
    for (NSString *name in @[@"displayName", @"name"]) {
        SEL selector = NSSelectorFromString(name);
        if ([conversation respondsToSelector:selector]) {
            id value = MSG(id)(conversation, selector);
            if ([value isKindOfClass:NSString.class] && [value length]) return value;
        }
    }
    return @"Conversation";
}

// ---- the real list, seen without the filter -------------------------------------------------------------------------------------------------
static id ConversationList(void) {
    Class list = NSClassFromString(@"CKConversationList");
    return [list respondsToSelector:@selector(sharedConversationList)] ? MSG(id)(list, @selector(sharedConversationList)) : nil;
}
static NSArray *AllConversations(void) {
    id list = ConversationList();
    if (![list respondsToSelector:@selector(conversations)]) return @[];
    Bypass++;
    id all = MSG(id)(list, @selector(conversations));
    Bypass--;
    return [all isKindOfClass:NSArray.class] ? all : @[];
}
NSArray *PMPrivateConversations(void) {
    NSMutableArray *out = [NSMutableArray array];
    for (id conversation in AllConversations()) if (PMIsPrivate(conversation)) [out addObject:conversation];
    return out;
}
NSArray *PMOrdinaryConversations(void) {
    NSMutableArray *out = [NSMutableArray array];
    for (id conversation in AllConversations()) if (PMIdentity(conversation) && !PMIsPrivate(conversation)) [out addObject:conversation];
    return out;
}

// ---- native "Hide Alerts" ------------------------------------------------------------------------------------------------------------------
// The setter is found at runtime by its shape (a BOOL getter and its one-BOOL setter named for muting / do-not-disturb on IMChat or CKConversation),
// then proven by reading the value back. If none is found, a conversation is never reported silenced and the move is refused.
static SEL MuteGet, MuteSet;
static BOOL MuteOnChat, MuteResolved, MuteByDate;
static BOOL IsBoolType(const char *type) { return type && (type[0] == 'B' || type[0] == 'c'); }
static void ResolveMute(void) {
    if (MuteResolved) return;
    MuteResolved = YES;
    ProbeNames = [NSMutableArray array];
    NSArray *getters = @[@"ismuted", @"muted", @"isdnd", @"isdonotdisturb", @"donotdisturb", @"ishidingalerts", @"hidealerts"];
    NSArray *pairs = @[@[@"IMChat", @YES], @[@"CKConversation", @NO]];
    for (NSArray *pair in pairs) {
        Class cls = NSClassFromString(pair[0]);
        if (!cls) continue;
        unsigned count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        for (unsigned i = 0; i < count; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            NSString *lower = name.lowercaseString;
            if ((([lower containsString:@"mute"] || [lower containsString:@"dnd"] || [lower containsString:@"hidealert"]) && ProbeNames.count < 40))
                [ProbeNames addObject:[NSString stringWithFormat:@"%@.%@", pair[0], name]];   // method names only, for the next build
            if (MuteGet || ![getters containsObject:lower] || method_getNumberOfArguments(methods[i]) != 2) continue;
            char *ret = method_copyReturnType(methods[i]);
            BOOL boolean = IsBoolType(ret);
            free(ret);
            if (!boolean) continue;
            NSString *core = [lower hasPrefix:@"is"] ? [name substringFromIndex:2] : name;
            NSString *cap = [[core substringToIndex:1].uppercaseString stringByAppendingString:[core substringFromIndex:1]];
            for (NSString *setterName in @[[NSString stringWithFormat:@"set%@:", cap], [NSString stringWithFormat:@"setIs%@:", cap]]) {
                Method setter = class_getInstanceMethod(cls, NSSelectorFromString(setterName));
                if (!setter || method_getNumberOfArguments(setter) != 3) continue;
                char *arg = method_copyArgumentType(setter, 2);
                BOOL ok = IsBoolType(arg);
                free(arg);
                if (ok) { MuteGet = method_getName(methods[i]); MuteSet = method_getName(setter); MuteOnChat = [pair[1] boolValue]; break; }
            }
        }
        free(methods);
        if (MuteGet) break;
    }
    if (!MuteGet) {   // iOS 16.5.1 (read from a device): no BOOL setter; CKConversation has isMuted, setMutedUntilDate: and unmute
        Class conversation = NSClassFromString(@"CKConversation");
        SEL untilSetter = NSSelectorFromString(@"setMutedUntilDate:");
        if (conversation && class_getInstanceMethod(conversation, @selector(isMuted)) && class_getInstanceMethod(conversation, untilSetter)) {
            MuteGet = @selector(isMuted); MuteSet = untilSetter; MuteOnChat = NO; MuteByDate = YES;
        }
    }
}
static BOOL AdapterReady(void) { ResolveMute(); return MuteGet && MuteSet; }

// Stock path: Messages' own long-press menu already has Hide Alerts / Show Alerts. Its action is found in the real menu and performed, so the
// change is exactly the one the stock control makes, with no private setter to guess. Needs the conversation to be on screen in the ordinary list.
// Every ChatKit list class that builds the long-press menu is found by what it implements, not by a guessed name: the single-item and the
// iOS 16 multi-item collection-view methods, and the generic menu-interaction method.
static NSMutableArray<NSString *> *RefreshProbe;         // list-screen update/reload method names (names only)
static NSMutableArray<NSString *> *IdShapes;             // shape of the list's item identifiers (type and length only)
static NSMutableArray<NSString *> *OpenProbe;            // methods named show/open...Conversation on the screens that could open a thread (names only)
static NSMutableArray<NSString *> *ScannedClasses;       // classes whose menu hookup was read from the live list (names only)
static NSMutableArray<NSDictionary *> *MenuHooks;        // {c: Class, s: selector name, i: IMP, k: 1 single | 2 plural | 3 interaction}
static NSMutableArray<NSString *> *MenuProbe;            // method names containing "ContextMenu" on ChatKit list classes (names only)
static BOOL StockCallable(void) { for (NSDictionary *h in MenuHooks) if ([h[@"k"] integerValue] != 3) return YES; return NO; }
static UIContextMenuConfiguration *CallMenu(id controller, UICollectionView *view, NSIndexPath *path, CGPoint point) {
    for (NSDictionary *hook in MenuHooks) {
        if ([hook[@"k"] integerValue] == 3 || ![controller isKindOfClass:hook[@"c"]]) continue;
        SEL selector = NSSelectorFromString(hook[@"s"]);
        IMP imp = (IMP)[hook[@"i"] pointerValue];
        if (![controller respondsToSelector:selector]) continue;
        return [hook[@"k"] integerValue] == 2
            ? ((UIContextMenuConfiguration * (*)(id, SEL, id, id, CGPoint))imp)(controller, selector, view, @[path], point)
            : ((UIContextMenuConfiguration * (*)(id, SEL, id, id, CGPoint))imp)(controller, selector, view, path, point);
    }
    return nil;
}
static id ConversationForCell(id controller, UICollectionView *view, NSIndexPath *path);
static UIAction *FindAlertsAction(UIMenuElement *element, BOOL *muted) {
    if ([element isKindOfClass:UIAction.class]) {
        NSString *title = element.title.lowercaseString;
        if (![title containsString:@"alert"]) return nil;
        BOOL show = [title hasPrefix:@"show"] || [title hasPrefix:@"mostrar"], hide = [title hasPrefix:@"hide"] || [title hasPrefix:@"ocultar"];
        if (!show && !hide) return nil;
        *muted = show;                                   // "Show Alerts" is offered while alerts are hidden
        return (UIAction *)element;
    }
    if ([element isKindOfClass:UIMenu.class]) for (UIMenuElement *child in ((UIMenu *)element).children) { UIAction *found = FindAlertsAction(child, muted); if (found) return found; }
    return nil;
}
static UICollectionView *ListView(UIViewController *controller) {
    if ([controller respondsToSelector:@selector(collectionView)]) { id view = MSG(id)(controller, @selector(collectionView)); if ([view isKindOfClass:UICollectionView.class]) return view; }
    for (UIView *view in controller.viewIfLoaded.subviews) if ([view isKindOfClass:UICollectionView.class]) return (UICollectionView *)view;
    return nil;
}
static UIAction *StockAction(id conversation, BOOL *muted) {
    NSString *identity = PMIdentity(conversation);
    UIViewController *controller = PMFindController(@"CKConversationListCollectionViewController") ?: PMFindController(@"CKConversationListController");
    UICollectionView *view = ListView(controller);
    if (!StockCallable() || !identity || !view) return nil;
    for (NSIndexPath *path in view.indexPathsForVisibleItems) {
        id candidate = ConversationForCell(controller, view, path);
        if (![PMIdentity(candidate) isEqual:identity]) continue;
        UIContextMenuConfiguration *config = CallMenu(controller, view, path, [view cellForItemAtIndexPath:path].center);
        if (!config) return nil;
        id provider = nil;
        @try { provider = [config valueForKey:@"actionProvider"]; } @catch (NSException *e) { return nil; }
        if (!provider) return nil;
        return FindAlertsAction(((UIContextMenuActionProvider)provider)(@[]), muted);
    }
    return nil;
}
static BOOL MuteReady(void) { return AdapterReady() || MenuHooks.count > 0; }
static id MuteTarget(id conversation) { return MuteOnChat ? ChatOf(conversation) : conversation; }
static NSMutableDictionary *CachedStock;                 // identity -> {a: UIAction, m: muted?, t: date}: the real action from the menu the user just opened
static NSString *NoteIdentity;                            // identity of the last conversation whose mute the system announced
static NSDate *NoteTime;
static NSString *LastReason;
static NSArray *MenuTitles;                               // titles of the stock menu items (interface words only), so a missing action can be named next time
static void CollectTitles(UIMenuElement *element, NSMutableArray *out) {
    if (out.count < 24 && element.title.length) [out addObject:[NSString stringWithFormat:@"%@%@", [element isKindOfClass:UIMenu.class] ? @"menu:" : (([element isKindOfClass:UIAction.class]) ? @"" : @"other:"), element.title]];
    else if (out.count < 24 && ![element isKindOfClass:UIMenu.class]) [out addObject:NSStringFromClass(element.class)];
    if ([element isKindOfClass:UIMenu.class]) for (UIMenuElement *child in ((UIMenu *)element).children) CollectTitles(child, out);
}
static void RememberStock(id conversation, UIAction *action, BOOL muted) {
    NSString *identity = PMIdentity(conversation);
    if (!identity || !action) return;
    if (!CachedStock) CachedStock = [NSMutableDictionary dictionary];
    CachedStock[identity] = @{@"a": action, @"m": @(muted), @"t": NSDate.date};
}
static NSDictionary *Cached(id conversation) {
    NSDictionary *entry = CachedStock[PMIdentity(conversation) ?: @""];
    return (entry && -[entry[@"t"] timeIntervalSinceNow] < 120) ? entry : nil;
}
static void ListenForMuteNotice(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:@"IMChatMuteDidChangeNotification" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        NoteIdentity = PMIdentity(note.object); NoteTime = NSDate.date;
    }];
}
// Fresh: the adapter, or the real menu of a row that is on screen right now.
static BOOL ReadMuteFresh(id conversation, BOOL *value) {
    id target = MuteTarget(conversation);
    if (AdapterReady() && [target respondsToSelector:MuteGet]) { *value = MSG(BOOL)(target, MuteGet); return YES; }
    BOOL muted = NO;
    if (!StockAction(conversation, &muted)) return NO;
    *value = muted;
    return YES;
}
static BOOL ReadMute(id conversation, BOOL *value) {
    if (ReadMuteFresh(conversation, value)) return YES;
    NSDictionary *entry = Cached(conversation);
    if (!entry) return NO;
    *value = [entry[@"m"] boolValue];
    return YES;
}
// Sets, then proves it. Proof is a fresh read after 0.7 s and again 0.5 s later; when no fresh read is possible, the system's own "mute changed"
// notice for this very conversation, after a single toggle from a known state, counts. Nothing else is accepted.
static void SetMute(id conversation, BOOL on, void (^done)(BOOL proven)) {
    id target = MuteTarget(conversation);
    BOOL now = NO;
    if (!ReadMute(conversation, &now)) { LastReason = @"E2"; done(NO); return; }
    NSDate *started = NSDate.date;
    if (now != on) {
        if (AdapterReady() && [target respondsToSelector:MuteSet]) {
            if (MuteByDate) {
                SEL toggleable = NSSelectorFromString(@"canMuteStateBeToggled");
                if ([target respondsToSelector:toggleable] && !MSG(BOOL)(target, toggleable)) { LastReason = @"E5"; done(NO); return; }   // Messages says this thread's alerts cannot be changed
                SEL unmute = NSSelectorFromString(@"unmute");
                if (on) MSG(void, id)(target, MuteSet, [NSDate distantFuture]);                // indefinite, as Hide Alerts is
                else if ([target respondsToSelector:unmute]) MSG(void)(target, unmute);
                else MSG(void, id)(target, MuteSet, nil);
            } else MSG(void, BOOL)(target, MuteSet, on);
        } else {
            BOOL muted = NO;
            UIAction *action = StockAction(conversation, &muted) ?: Cached(conversation)[@"a"];
            if (!action) { LastReason = @"E3"; done(NO); return; }
            [action performWithSender:nil target:nil];
        }
    }
    NSString *identity = PMIdentity(conversation);
    BOOL (^proven)(void) = ^BOOL{
        BOOL value = NO;
        if (ReadMuteFresh(conversation, &value)) return value == on;
        return now != on && [NoteIdentity isEqual:identity] && [NoteTime timeIntervalSinceDate:started] >= 0;
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!proven()) { LastReason = @"E4"; done(NO); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL ok = proven();
            if (!ok) LastReason = @"E4";
            done(ok);
        });
    });
}

// ---- move and return ----------------------------------------------------------------------------------------------------------------------
static BOOL Busy;
void PMMove(id conversation, PMDone done) {
    NSString *identity = PMIdentity(conversation);
    if (!identity) { done(NO, @"This conversation can't be identified right now. Nothing was changed."); return; }
    if (!ListHooked) { done(NO, @"Private Conversations can't hide threads on this version of Messages. Nothing was changed."); return; }
    if (!MuteReady()) { LastReason = @"E1"; done(NO, @"Messages alerts can't be silenced on this version, so the conversation was not moved. [E1]"); return; }
    if (Busy) { done(NO, @"Another change is still finishing. Try again in a moment."); return; }
    NSMutableDictionary *entries = Entries();
    if ([entries[identity][@"state"] isEqual:@"private"]) { done(YES, @"Already private."); return; }
    BOOL was = NO;
    if (!ReadMute(conversation, &was)) { LastReason = @"E2"; done(NO, @"The current alert setting can't be read from here. Nothing was changed. [E2]"); return; }
    Busy = YES;
    entries[identity] = @{@"was": @(was), @"state": @"moving"};
    SaveEntries(entries);                                   // still visible until alerts are proven silenced; a crash from here on is finished by PMReconcile
    void (^finish)(BOOL) = ^(BOOL silenced) {
        NSMutableDictionary *now = Entries();
        if (silenced) {
            now[identity] = @{@"was": @(was), @"state": @"private"};
            SaveEntries(now);
            Busy = NO;
            PMRefreshLists(); PMPublishStatus();
            done(YES, @"Moved to Private. Hide Alerts is on for this conversation.");
            return;
        }
        // Not proven: undo everything and say exactly what state it is in.
        [now removeObjectForKey:identity];
        SaveEntries(now);
        NSString *failure = LastReason;
        SetMute(conversation, was, ^(BOOL restored) {
            LastReason = failure;
            Busy = NO;
            PMPublishStatus();
            NSString *code = LastReason ?: @"E4";
            done(NO, restored ? [NSString stringWithFormat:@"Not moved. Alerts could not be silenced, so the conversation is back in Messages exactly as it was. [%@]", code]
                              : [NSString stringWithFormat:@"Not moved, but Hide Alerts may have changed. Check this conversation's Details in Messages. [%@]", code]);
        });
    };
    if (was) finish(YES); else SetMute(conversation, YES, finish);
}

static void ReturnIdentity(NSString *identity, id conversation, BOOL retryable, PMDone done) {
    NSMutableDictionary *entries = Entries();
    NSDictionary *entry = entries[identity];
    BOOL was = [entry[@"was"] boolValue];
    entries[identity] = @{@"was": @(was), @"state": @"returning"};   // visible again at once
    SaveEntries(entries);
    PMRefreshLists();
    void (^finish)(BOOL) = ^(BOOL restored) {
        NSMutableDictionary *now = Entries();
        [now removeObjectForKey:identity];                           // visibility is restored either way; the message below tells the truth about alerts
        SaveEntries(now);
        PMRefreshLists(); PMPublishStatus();
        done(restored, restored ? @"Returned to Messages. Its alert setting is back to what it was."
                                : @"Returned to Messages, but Hide Alerts is still on. Turn it off in the conversation's Details.");
    };
    if (was || !conversation) { finish(was); return; }
    // The row has to be on screen for the stock control to be reached, so give the list a moment to show it again.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL probe = NO;
        if (retryable && !ReadMute(conversation, &probe)) { done(NO, @"pending"); return; }   // not on screen yet: the entry stays and the next launch retries
        SetMute(conversation, NO, finish);
    });
}
void PMReturn(id conversation, PMDone done) {
    NSString *identity = PMIdentity(conversation);
    if (!identity || !Entries()[identity]) { done(NO, @"This conversation is not private."); return; }
    ReturnIdentity(identity, conversation, NO, done);
}

// ---- reconcile ----------------------------------------------------------------------------------------------------------------------------
// Runs whenever Messages opens, whatever the switch says: finishes half-done moves and carries out a "Restore Alerts" request from Settings, so a
// conversation is never left hidden or muted just because the feature was turned off or removed.
void PMReconcile(void) {
    if (Busy) return;
    NSMutableDictionary *entries = Entries();
    NSNumber *request = Prefs[MYB_PRIV_KEY_MESSAGES_RESTORE];
    BOOL restoreAll = [request isKindOfClass:NSNumber.class] && ![request isEqual:[Defaults() objectForKey:kRestoreDone]];
    NSMutableArray *todo = [NSMutableArray array];
    for (NSString *identity in entries) {
        NSString *state = entries[identity][@"state"];
        if (restoreAll || [state isEqual:@"moving"] || [state isEqual:@"returning"]) [todo addObject:identity];
    }
    if (!todo.count) { if (restoreAll) [Defaults() setObject:request forKey:kRestoreDone]; PMPublishStatus(); return; }
    NSArray *all = AllConversations();
    if (!all.count) return;                                           // chats not loaded yet: the next appearance tries again
    NSMutableDictionary *byIdentity = [NSMutableDictionary dictionary];
    for (id conversation in all) { NSString *identity = PMIdentity(conversation); if (identity) byIdentity[identity] = conversation; }
    __block NSUInteger remaining = todo.count;
    __block BOOL pending = NO;
    for (NSString *identity in todo) {
        id conversation = byIdentity[identity];
        if (!conversation) {                                          // the conversation no longer exists: nothing left to restore
            NSMutableDictionary *now = Entries(); [now removeObjectForKey:identity]; SaveEntries(now);
            if (--remaining == 0) { if (restoreAll) [Defaults() setObject:request forKey:kRestoreDone]; PMRefreshLists(); PMPublishStatus(); }
            continue;
        }
        ReturnIdentity(identity, conversation, YES, ^(BOOL ok, NSString *message) {
            if (!ok && [message isEqual:@"pending"]) pending = YES;
            if (--remaining == 0) { if (restoreAll && !pending) [Defaults() setObject:request forKey:kRestoreDone]; PMPublishStatus(); }
        });
    }
}

// ---- status for Settings (counts and yes/no only) ------------------------------------------------------------------------------------------
void PMPublishStatus(void) {
    NSDictionary *entries = Entries();
    NSUInteger held = 0;
    for (NSDictionary *entry in entries.allValues) if (![entry[@"was"] boolValue]) held++;
    NSDictionary *status = @{@"private": @(entries.count), @"alertsHeld": @(held), @"lists": @(ListHooked), @"mute": @(MuteReady()), @"stockMute": @(MenuHooks.count), @"menuProbe": MenuProbe ?: @[], @"scanned": ScannedClasses ?: @[], @"idShapes": IdShapes ?: @[], @"openProbe": OpenProbe ?: @[], @"refreshProbe": RefreshProbe ?: @[], @"lastReason": LastReason ?: @"", @"menuTitles": MenuTitles ?: @[], @"searchShapes": SearchProbe ?: @[], @"searchClasses": SearchClasses ?: @[],
        @"hooked": [ListHookNames componentsJoinedByString:@","] ?: @"", @"probe": ProbeNames ?: @[], @"menuUses": @(MenuUses), @"swipeProbe": SwipeProbe ?: @[], @"swipeSeen": @(SwipeSeen), @"swipeLists": @(SwipeProviders), @"swipeOffered": @(SwipeOffered), @"ios": UIDevice.currentDevice.systemVersion};
    [Defaults() setObject:status forKey:kStatus];
    [Defaults() synchronize];
}
void PMCountMenuUse(void) { MenuUses++; }

// ---- hiding: filter ChatKit's own conversation arrays for the screens, never for ChatKit itself ----------------------------------------------
static NSArray *Filtered(id result) {
    if (![result isKindOfClass:NSArray.class]) return result;
    NSSet *hidden = Hidden();
    if (!hidden.count) return result;
    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:[result count]];
    for (id item in result) { NSString *identity = PMIdentity(item); if (!(identity && [hidden containsObject:identity] && ![identity isEqual:RevealIdentity])) [kept addObject:item]; }
    return [result isKindOfClass:NSMutableArray.class] ? kept : [kept copy];
}
static BOOL SafeWrapType(const char *type) { return type && strchr("@vBcqQiIlLsS#:", type[0]); }
static void HookList(void) {
    Class list = NSClassFromString(@"CKConversationList");
    if (!list) return;
    ListHookNames = [NSMutableArray array];
    unsigned count = 0;
    Method *methods = class_copyMethodList(list, &count);
    for (unsigned i = 0; i < count; i++) {
        SEL selector = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(selector);
        unsigned args = method_getNumberOfArguments(methods[i]) - 2;
        char *ret = method_copyReturnType(methods[i]);
        BOOL returnOK = SafeWrapType(ret), returnsObject = ret[0] == '@';
        free(ret);
        if (!returnOK || args > 3 || [name hasPrefix:@"init"] || [name isEqual:@"dealloc"] || [name hasPrefix:@"."] || [name isEqual:@"hash"] ||
            [name isEqual:@"isEqual:"] || [name isEqual:@"description"] || [name isEqual:@"debugDescription"] || [name hasPrefix:@"retain"] ||
            [name hasPrefix:@"release"] || [name hasPrefix:@"autorelease"] || [name hasPrefix:@"mutableCopy"] || [name hasPrefix:@"copy"]) continue;
        BOOL typesOK = YES;
        for (unsigned a = 0; a < args; a++) { char *type = method_copyArgumentType(methods[i], a + 2); typesOK &= SafeWrapType(type); free(type); }
        if (!typesOK) continue;
        IMP original = method_getImplementation(methods[i]);
        BOOL arrayGetter = args == 0 && returnsObject && [name containsString:@"onversations"] && ![name hasPrefix:@"_"] && ![name hasPrefix:@"set"] && ![name containsString:@"racked"];
        if (arrayGetter) {
            // What the screens read: filtered. (Anything ChatKit asks of itself, inside the wrapped methods below, is not.)
            id block = ^id(id self) {
                id result = ((id (*)(id, SEL))original)(self, selector);
                return (Bypass > 0 || !PMSwitchOn()) ? result : Filtered(result);
            };
            method_setImplementation(methods[i], imp_implementationWithBlock(block));
            [ListHookNames addObject:name];
        } else {
            BOOL lookup = [name hasPrefix:@"conversationFor"] || [name hasPrefix:@"_conversationFor"] || [name containsString:@"ForExistingChat"] ||
                [name containsString:@"ForChat"] || [name hasPrefix:@"_beginTracking"];
            if (!lookup) continue;
            id block = ^intptr_t(id self, intptr_t a, intptr_t b, intptr_t c) {
                Bypass++;
                intptr_t result = ((intptr_t (*)(id, SEL, intptr_t, intptr_t, intptr_t))original)(self, selector, a, b, c);
                Bypass--;
                return result;
            };
            method_setImplementation(methods[i], imp_implementationWithBlock(block));
        }
    }
    free(methods);
    ListHooked = ListHookNames.count > 0;
}

// ---- the long-press menu ------------------------------------------------------------------------------------------------------------------
extern void PMUIMoveFromMenu(id conversation);
static id ConversationForCell(id controller, UICollectionView *view, NSIndexPath *path) {
    id cell = [view cellForItemAtIndexPath:path];
    if ([cell respondsToSelector:@selector(conversation)]) { id c = MSG(id)(cell, @selector(conversation)); if (PMIdentity(c)) return c; }
    for (NSString *name in @[@"conversationForIndexPath:", @"conversationAtIndexPath:"]) {
        SEL selector = NSSelectorFromString(name);
        if ([controller respondsToSelector:selector]) { id c = MSG(id, id)(controller, selector, path); if (PMIdentity(c)) return c; }
    }
    return nil;
}
// Apple's own press-and-hold menu is left exactly as it is. It is only read, to remember Apple's own "Hide Alerts" action for this thread.
static UIContextMenuConfiguration *Augment(UIContextMenuConfiguration *config, id conversation) {
    id actionProvider = nil, previewProvider = nil, identifier = nil;
    @try { actionProvider = [config valueForKey:@"actionProvider"]; previewProvider = [config valueForKey:@"previewProvider"]; identifier = [config valueForKey:@"identifier"]; }
    @catch (NSException *e) { return config; }
    if (!actionProvider) return config;
    UIContextMenuActionProvider original = actionProvider;
    UIContextMenuActionProvider provider = ^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIMenu *base = original(suggested);
        BOOL muted = NO;
        UIAction *stock = FindAlertsAction(base, &muted);
        if (stock) RememberStock(conversation, stock, muted);
        { NSMutableArray *titles = [NSMutableArray array]; CollectTitles(base, titles); MenuTitles = titles; PMPublishStatus(); }
        return base;
    };
    PMCountMenuUse();
    return [UIContextMenuConfiguration configurationWithIdentifier:identifier previewProvider:previewProvider actionProvider:provider];
}
static UIContextMenuConfiguration *HandleMenu(id self, UIView *view, NSIndexPath *path, id conversationSource, UIContextMenuConfiguration *config) {
    if (!config || !PMActive() || !PMSessionUnlocked()) return config;
    id conversation = nil;
    if (path && [view isKindOfClass:UICollectionView.class]) conversation = ConversationForCell(self, (UICollectionView *)view, path);
    else if ([conversationSource respondsToSelector:@selector(conversation)]) conversation = MSG(id)(conversationSource, @selector(conversation));
    return (conversation && PMIdentity(conversation) && !PMIsPrivate(conversation)) ? Augment(config, conversation) : config;
}
static NSMutableSet<NSString *> *HookedPairs;
static void HookClassMenu(Class cls) {
    unsigned methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    NSString *className = NSStringFromClass(cls);
    for (unsigned m = 0; m < methodCount; m++) {
        SEL selector = method_getName(methods[m]);
        NSString *name = NSStringFromSelector(selector);
        if ([name containsString:@"ontextMenu"] && MenuProbe.count < 30) [MenuProbe addObject:[NSString stringWithFormat:@"%@.%@", className, name]];
        NSInteger kind = [name isEqual:@"collectionView:contextMenuConfigurationForItemAtIndexPath:point:"] ? 1
            : ([name isEqual:@"collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:"] || [name isEqual:@"_dci_collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:"]) ? 2
            : [name isEqual:@"contextMenuInteraction:configurationForMenuAtLocation:"] ? 3 : 0;
        NSString *pair = [className stringByAppendingFormat:@"|%@", name];
        if (!kind || [HookedPairs containsObject:pair]) continue;
        [HookedPairs addObject:pair];
        IMP original = method_getImplementation(methods[m]);
        [MenuHooks addObject:@{@"c": cls, @"s": name, @"i": [NSValue valueWithPointer:(const void *)original], @"k": @(kind)}];
        id block;
        if (kind == 1) block = ^UIContextMenuConfiguration *(id self, UICollectionView *view, NSIndexPath *path, CGPoint point) {
            return HandleMenu(self, view, path, nil, ((UIContextMenuConfiguration * (*)(id, SEL, id, id, CGPoint))original)(self, selector, view, path, point));
        };
        else if (kind == 2) block = ^UIContextMenuConfiguration *(id self, UICollectionView *view, NSArray<NSIndexPath *> *paths, CGPoint point) {
            UIContextMenuConfiguration *config = ((UIContextMenuConfiguration * (*)(id, SEL, id, id, CGPoint))original)(self, selector, view, paths, point);
            return paths.count == 1 ? HandleMenu(self, view, paths.firstObject, nil, config) : config;
        };
        else block = ^UIContextMenuConfiguration *(id self, UIContextMenuInteraction *interaction, CGPoint point) {
            UIContextMenuConfiguration *config = ((UIContextMenuConfiguration * (*)(id, SEL, id, CGPoint))original)(self, selector, interaction, point);
            id source = [interaction.view respondsToSelector:@selector(conversation)] ? interaction.view : self;
            return HandleMenu(self, interaction.view, nil, source, config);
        };
        method_setImplementation(methods[m], imp_implementationWithBlock(block));
    }
    free(methods);
}
static void HookMenu(void) {
    MenuHooks = [NSMutableArray array];
    MenuProbe = [NSMutableArray array];
    HookedPairs = [NSMutableSet set];
    ScannedClasses = [NSMutableArray array];
    Class anchor = NSClassFromString(@"CKConversationList");
    const char *image = anchor ? class_getImageName(anchor) : NULL;
    unsigned classCount = 0;
    const char **names = image ? objc_copyClassNamesForImage(image, &classCount) : NULL;
    for (unsigned c = 0; c < classCount; c++) {
        NSString *className = @(names[c]);
        if ([className containsString:@"onversation"] || [className hasPrefix:@"CKMessages"] || [className hasPrefix:@"CKChatList"]) HookClassMenu(objc_getClass(names[c]));
    }
    free(names);
}
// ---- swipe: Private --------------------------------------------------------------------------------------------------------------------------
// A conversation in the ordinary list gets a "Private" swipe action, only while Private Messages is unlocked this session. The list's own swipe
// actions (delete, hide alerts, pin) stay as they are. The action is added where the list is configured, and only for the conversation list.
// The swipe is added where ChatKit builds the trailing actions of a conversation row.
static UISwipeActionsConfiguration *PrivateSwipe(UIViewController *controller, UISwipeActionsConfiguration *base, NSIndexPath *path) {
    if (!PMActive() || !PMSessionUnlocked()) return base;
    @try {
        UICollectionView *view = ListView(controller);
        if (!view.window || controller.presentedViewController) return base;           // only while the conversation list itself is on screen
        id conversation = ConversationForCell(controller, view, path);
        if (!conversation || !PMIdentity(conversation) || PMIsPrivate(conversation)) return base;
        for (UIContextualAction *existing in base.actions) if ([existing.title isEqual:@"Private"]) return base;
        UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Private" handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
            (void)a; (void)v; PMUIMoveFromMenu(conversation); done(YES);
        }];
        action.backgroundColor = UIColor.systemIndigoColor;
        action.image = [UIImage systemImageNamed:@"lock.fill"];
        NSMutableArray *all = [NSMutableArray arrayWithArray:base.actions ?: @[]];
        [all addObject:action];
        UISwipeActionsConfiguration *merged = [UISwipeActionsConfiguration configurationWithActions:all];
        merged.performsFirstActionWithFullSwipe = base ? base.performsFirstActionWithFullSwipe : NO;
        SwipeOffered++;
        return merged;
    } @catch (NSException *e) { (void)e; return base; }
}
static void HookSwipe(void) {
    SwipeProbe = [NSMutableArray array];
    for (NSString *className in @[@"CKConversationListCollectionViewController", @"CKConversationListController", @"CKConversationListCollectionView"]) {
        Class cls = NSClassFromString(className); unsigned n = 0;
        Method *methods = cls ? class_copyMethodList(cls, &n) : NULL;
        for (unsigned i = 0; i < n; i++) { NSString *name = NSStringFromSelector(method_getName(methods[i])); if ([name localizedCaseInsensitiveContainsString:@"swipe"] && SwipeProbe.count < 20) [SwipeProbe addObject:[className stringByAppendingFormat:@".%@", name]]; }
        free(methods);
    }
    // ChatKit builds each row's leading actions (the left side: Pin, Unread) in this method of its conversation list; Private is appended to what it returns.
    Class listClass = NSClassFromString(@"CKConversationListCollectionViewController");
    SEL sel = NSSelectorFromString(@"leadingSwipeActionsConfigurationForIndexPath:");
    Method method = listClass ? class_getInstanceMethod(listClass, sel) : NULL;
    if (!method) return;
    NSMutableString *shape = [NSMutableString string];
    for (const char *p = method_getTypeEncoding(method); p && *p; p++) if (*p < '0' || *p > '9') [shape appendFormat:@"%c", *p];
    if (![shape isEqualToString:@"@@:@"]) return;                                      // a different signature on this iOS build: not hooked
    IMP original = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^id(UIViewController *self, NSIndexPath *path) {
        UISwipeActionsConfiguration *base = ((id (*)(id, SEL, id))original)(self, sel, path);
        SwipeSeen++;
        if (!PMActive()) return base;
        SwipeProviders++;
        return PrivateSwipe(self, base, path);
    }));
}
// The real hookup, read from the live list on screen: the list controller, the collection view's delegate and the delegates of every context-menu
// interaction on the list and its rows. Classes found this way are hooked the first time they are seen, before anyone long-presses.
void PMScanList(UIViewController *list) {
    static CFAbsoluteTime last;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - last < 1.5) return;
    last = now;
    UICollectionView *view = ListView(list);
    NSMutableSet<Class> *classes = [NSMutableSet set];
    void (^add)(id) = ^(id object) {
        for (Class c = object ? object_getClass(object) : Nil; c && c != NSObject.class; c = class_getSuperclass(c))
            if ([NSStringFromClass(c) hasPrefix:@"CK"]) [classes addObject:c];
    };
    add(list);
    add(view.delegate);
    void (^addInteractions)(UIView *) = ^(UIView *host) {
        for (id interaction in host.interactions) if ([interaction isKindOfClass:UIContextMenuInteraction.class]) add(((UIContextMenuInteraction *)interaction).delegate);
    };
    addInteractions(view);
    for (UICollectionViewCell *cell in view.visibleCells) { add(cell); addInteractions(cell); }
    for (Class cls in classes) {
        NSString *name = NSStringFromClass(cls);
        if (![ScannedClasses containsObject:name] && ScannedClasses.count < 30) [ScannedClasses addObject:name];
        HookClassMenu(cls);
    }
    PMPublishStatus();
}

// ---- screens ------------------------------------------------------------------------------------------------------------------------------
void PMRefreshLists(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        id list = ConversationList();
        [NSNotificationCenter.defaultCenter postNotificationName:@"CKConversationListChangedNotification" object:list];
        UIViewController *controller = PMFindController(@"CKConversationListCollectionViewController") ?: PMFindController(@"CKConversationListController");
        SEL update = NSSelectorFromString(@"updateConversationList");
        if ([controller respondsToSelector:update]) MSG(void)(controller, update);
        // Re-applying the list's own current snapshot runs it through the filter, so a thread that was just made private leaves the screen at once.
        UICollectionView *view = ListView(controller);
        id source = view.dataSource;
        if ([source isKindOfClass:NSClassFromString(@"UICollectionViewDiffableDataSourceReference") ?: NSNull.class] && [source respondsToSelector:@selector(snapshot)]) {
            id snapshot = MSG(id)(source, @selector(snapshot));
            if (snapshot) MSG(void, id, BOOL)(source, @selector(applySnapshot:animatingDifferences:), snapshot, YES);
        }
        if (!RefreshProbe) {
            RefreshProbe = [NSMutableArray array];
            unsigned count = 0;
            Method *methods = class_copyMethodList(object_getClass(controller), &count);
            for (unsigned i = 0; i < count && RefreshProbe.count < 16; i++) {
                NSString *name = NSStringFromSelector(method_getName(methods[i]));
                if ([name hasPrefix:@"update"] || [name hasPrefix:@"reload"] || [name hasPrefix:@"_update"] || [name hasPrefix:@"_reload"]) [RefreshProbe addObject:name];
            }
            free(methods);
        }
    });
}
static UIViewController *Search(UIViewController *controller, NSString *prefix, int depth) {
    if (!controller || depth > 12) return nil;
    if ([NSStringFromClass(controller.class) hasPrefix:prefix]) return controller;
    for (UIViewController *child in controller.childViewControllers) { UIViewController *found = Search(child, prefix, depth + 1); if (found) return found; }
    return Search(controller.presentedViewController, prefix, depth + 1);
}
UIViewController *PMFindController(NSString *prefix) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) { UIViewController *found = Search(window.rootViewController, prefix, 0); if (found) return found; }
    }
    return nil;
}
BOOL PMOpenNative(id conversation) {
    OpenProbe = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];   // {c: controller, s: selector name, n: argument count}
    for (NSString *name in @[@"CKMessagesController", @"CKConversationListController", @"CKConversationListCollectionViewController", @"CKChatController"]) {
        UIViewController *controller = PMFindController(name);
        for (Class cls = controller ? object_getClass(controller) : Nil; cls && cls != UIViewController.class && cls != NSObject.class; cls = class_getSuperclass(cls)) {
            unsigned count = 0;
            Method *methods = class_copyMethodList(cls, &count);
            for (unsigned i = 0; i < count; i++) {
                NSString *method = NSStringFromSelector(method_getName(methods[i]));
                if (!([method hasPrefix:@"showConversation"] || [method hasPrefix:@"openConversation"] || [method hasPrefix:@"_showConversation"])) continue;
                if (OpenProbe.count < 24) [OpenProbe addObject:[NSString stringWithFormat:@"%@.%@", NSStringFromClass(cls), method]];
                [candidates addObject:@{@"c": controller, @"s": method, @"n": @(method_getNumberOfArguments(methods[i]) - 2)}];
            }
            free(methods);
        }
    }
    // The documented pair first, then any other two-argument (conversation, animated) variant.
    for (NSDictionary *candidate in candidates) {
        if (![candidate[@"s"] isEqual:@"showConversation:animated:"]) continue;
        MSG(void, id, BOOL)(candidate[@"c"], NSSelectorFromString(candidate[@"s"]), conversation, YES);
        return YES;
    }
    for (NSDictionary *candidate in candidates) {
        SEL selector = NSSelectorFromString(candidate[@"s"]);
        Method method = class_getInstanceMethod(object_getClass(candidate[@"c"]), selector);
        char *type = method ? method_copyArgumentType(method, 3) : NULL;
        BOOL boolean = type && (type[0] == 'B' || type[0] == 'c');
        free(type);
        if ([candidate[@"n"] integerValue] == 2 && boolean) { MSG(void, id, BOOL)(candidate[@"c"], selector, conversation, YES); return YES; }
    }
    // Last resort, with no private name at all: show the row to the list for a moment and select it the way a tap would.
    NSString *identity = PMIdentity(conversation);
    UIViewController *list = PMFindController(@"CKConversationListCollectionViewController");
    SEL select = @selector(collectionView:didSelectItemAtIndexPath:);
    if (!identity || ![list respondsToSelector:select]) return NO;
    RevealIdentity = identity;
    @synchronized (Lock) { Generation++; }
    PMRefreshLists();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UICollectionView *view = ListView(list);
        for (NSIndexPath *path in view.indexPathsForVisibleItems) {
            if ([PMIdentity(ConversationForCell(list, view, path)) isEqual:identity]) { MSG(void, id, id)(list, select, view, path); break; }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            RevealIdentity = nil;
            @synchronized (Lock) { Generation++; }
            PMRefreshLists();
        });
    });
    return YES;
}

// A thread that is private must not be on screen unless the private session opened it.
static __weak UIViewController *PrivateThread;
static id ConversationOfController(UIViewController *controller) {
    if (![NSStringFromClass(controller.class) hasPrefix:@"CK"] || ![controller respondsToSelector:@selector(conversation)]) return nil;
    id conversation = MSG(id)(controller, @selector(conversation));
    return PMIdentity(conversation) ? conversation : nil;
}
void PMNoteTop(UIViewController *top) {
    if (!PMSwitchOn()) { PrivateThread = nil; return; }
    id conversation = ConversationOfController(top);
    if (!conversation) { if (PrivateThread == top) PrivateThread = nil; return; }
    if (!PMIsPrivate(conversation)) { if (PrivateThread == top) PrivateThread = nil; return; }
    PrivateThread = top;
    if (!PMSessionUnlocked()) dispatch_async(dispatch_get_main_queue(), ^{ PMPopPrivateThread(); });
}
BOOL PMPrivateThreadVisible(void) { return PrivateThread.viewIfLoaded.window != nil; }
void PMPopPrivateThread(void) {
    UINavigationController *nav = PrivateThread.navigationController;
    if (nav.viewControllers.count > 1 && nav.topViewController == PrivateThread) [nav popToRootViewControllerAnimated:NO];
    PrivateThread = nil;
}

BOOL PMSessionUnlocked(void) { return SessionOn; }
void PMSessionBegin(void) { SessionOn = YES; }
void PMSessionEnd(void) { SessionOn = NO; }

// ---- hiding at the data-source level ------------------------------------------------------------------------------------------------------
// Whatever feeds the list, the rows applied to it are checked too: an item whose identifier is a private thread's chat identifier (alone or after one of
// ChatKit's own list prefixes) is removed from the snapshot. The identifiers are held in memory only and never stored.
static NSArray<NSString *> *HiddenStrings(void) {
    static NSArray *cache; static NSInteger generation = -1; static CFAbsoluteTime stamp; static NSString *reveal;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (cache && generation == Generation && [reveal isEqual:RevealIdentity] && now - stamp < 2) return cache;
    NSMutableArray *strings = [NSMutableArray array];
    for (id conversation in AllConversations()) {
        if (!PMIsPrivate(conversation) || [PMIdentity(conversation) isEqual:RevealIdentity]) continue;
        for (id object in @[conversation, ChatOf(conversation) ?: NSNull.null]) {
            if (object == NSNull.null) continue;
            for (NSString *name in @[@"guid", @"chatIdentifier", @"groupID", @"pinningIdentifier", @"uniqueIdentifier"]) {
                SEL selector = NSSelectorFromString(name);
                if (![object respondsToSelector:selector]) continue;
                id value = MSG(id)(object, selector);
                if ([value isKindOfClass:NSString.class] && [value length] >= 4 && ![strings containsObject:value]) [strings addObject:value];
            }
        }
    }
    cache = strings; generation = Generation; stamp = now; reveal = RevealIdentity;
    return strings;
}
static BOOL MatchesHidden(NSString *identifier, NSArray<NSString *> *strings) {
    if ([strings containsObject:identifier]) return YES;
    for (NSString *symbol in @[@"CKConversationListCollectionViewListItemIdentifierPrefix", @"CKConversationListCollectionViewPinnedItemIdentifierPrefix",
                               @"CKConversationListCollectionViewListJunkItemIdentifierPrefix", @"CKConversationListCollectionViewRecentlyDeletedListItemIdentifierPrefix"]) {
        NSString *const *address = (NSString *const *)dlsym(RTLD_DEFAULT, symbol.UTF8String);
        NSString *prefix = address ? *address : nil;
        if (prefix.length && [identifier hasPrefix:prefix] && [strings containsObject:[identifier substringFromIndex:prefix.length]]) return YES;
    }
    return NO;
}
// Search results are objects, not strings. An object is private when its own chat or conversation is, or when one of its identifier strings is a
// private chat's identifier. Only names and lengths of what answered are noted, and only for a few Messages results, so the next build can be exact.
static id ObjectValue(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (!object || ![object respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
    return MSG(id)(object, selector);
}
static BOOL ObjectHidden(id item, NSArray *strings, int depth, NSMutableArray *seen) {
    if (!item || depth > 2) return NO;
    for (NSString *name in @[@"conversation", @"chat"]) {
        id nested = ObjectValue(item, name);
        if (nested && nested != item) { [seen addObject:name]; if (PMIsPrivate(nested)) return YES; }
    }
    for (NSString *name in @[@"chatGUID", @"chatIdentifier", @"guid", @"identifier", @"uniqueIdentifier", @"domainIdentifier"]) {
        id value = ObjectValue(item, name);
        if ([value isKindOfClass:NSString.class]) { [seen addObject:[NSString stringWithFormat:@"%@:%lu", name, (unsigned long)[value length]]]; if (MatchesHidden(value, strings)) return YES; }
    }
    for (NSString *name in @[@"result", @"searchResult", @"item", @"message", @"representedObject"]) {
        id nested = ObjectValue(item, name);
        if (nested && nested != item && ![nested isKindOfClass:NSString.class]) { [seen addObject:name]; if (ObjectHidden(nested, strings, depth + 1, seen)) return YES; }
    }
    return NO;
}
static void FilterSnapshot(id snapshot) {
    if (!PMSwitchOn() || !Hidden().count) return;
    if (![snapshot respondsToSelector:@selector(itemIdentifiers)] || ![snapshot respondsToSelector:@selector(deleteItemsWithIdentifiers:)]) return;
    NSArray *strings = HiddenStrings();
    if (!strings.count) return;
    NSMutableArray *drop = [NSMutableArray array];
    NSArray *items = MSG(id)(snapshot, @selector(itemIdentifiers));
    for (id item in items) {
        if ([item isKindOfClass:NSString.class]) { if (MatchesHidden(item, strings)) [drop addObject:item]; continue; }
        if ([item isKindOfClass:NSNumber.class] || [item isKindOfClass:NSNull.class]) continue;
        NSMutableArray *seen = [NSMutableArray array];
        if (ObjectHidden(item, strings, 0, seen)) { [drop addObject:item]; continue; }
        if (SearchProbe.count < 6 && seen.count) {
            NSString *shape = [NSString stringWithFormat:@"%@ [%@]", NSStringFromClass([item class]), [seen componentsJoinedByString:@","]];
            if (![SearchProbe containsObject:shape]) [SearchProbe addObject:shape];
        }
    }
    if (drop.count) MSG(void, id)(snapshot, @selector(deleteItemsWithIdentifiers:), drop);
    else if (items.count && IdShapes.count < 6) {   // what the identifiers look like, without their content
        id first = items.firstObject;
        NSString *shape = [first isKindOfClass:NSString.class] ? [NSString stringWithFormat:@"NSString len %lu", (unsigned long)[first length]] : NSStringFromClass([first class]);
        if (![IdShapes containsObject:shape]) [IdShapes addObject:shape];
    }
}
static void HookSnapshotClass(Class source);
static void HookSnapshots(void) {
    IdShapes = [NSMutableArray array];
    SearchProbe = [NSMutableArray array];
    HookSnapshotClass(NSClassFromString(@"UICollectionViewDiffableDataSourceReference"));
    HookSnapshotClass(NSClassFromString(@"UITableViewDiffableDataSourceReference"));
    SearchClasses = [NSMutableArray array];       // Messages search screens: class names only
    unsigned int count = 0; Class *all = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count && SearchClasses.count < 30; i++) {
        NSString *name = NSStringFromClass(all[i]);
        if ([name hasPrefix:@"CK"] && [name containsString:@"Search"]) [SearchClasses addObject:name];
    }
    free(all);
}
static void HookSnapshotClass(Class source) {
    if (!source) return;
    SEL a1 = @selector(applySnapshot:animatingDifferences:), a2 = @selector(applySnapshot:animatingDifferences:completion:),
        a3 = @selector(applySnapshotUsingReloadData:), a4 = @selector(applySnapshotUsingReloadData:completion:);
    Method m1 = class_getInstanceMethod(source, a1), m2 = class_getInstanceMethod(source, a2), m3 = class_getInstanceMethod(source, a3), m4 = class_getInstanceMethod(source, a4);
    if (m1) { IMP o = method_getImplementation(m1); method_setImplementation(m1, imp_implementationWithBlock(^(id self, id snapshot, BOOL animated) { FilterSnapshot(snapshot); ((void (*)(id, SEL, id, BOOL))o)(self, a1, snapshot, animated); })); }
    if (m2) { IMP o = method_getImplementation(m2); method_setImplementation(m2, imp_implementationWithBlock(^(id self, id snapshot, BOOL animated, id completion) { FilterSnapshot(snapshot); ((void (*)(id, SEL, id, BOOL, id))o)(self, a2, snapshot, animated, completion); })); }
    if (m3) { IMP o = method_getImplementation(m3); method_setImplementation(m3, imp_implementationWithBlock(^(id self, id snapshot) { FilterSnapshot(snapshot); ((void (*)(id, SEL, id))o)(self, a3, snapshot); })); }
    if (m4) { IMP o = method_getImplementation(m4); method_setImplementation(m4, imp_implementationWithBlock(^(id self, id snapshot, id completion) { FilterSnapshot(snapshot); ((void (*)(id, SEL, id, id))o)(self, a4, snapshot, completion); })); }
}

void PMInstallHooks(void) {
    Lock = [NSObject new];
    PMReloadPrefs();
    SaveEntries(Entries());                       // loads the hidden set
    HookList();
    HookMenu();
    HookSwipe();
    HookSnapshots();
    ResolveMute();
    ListenForMuteNotice();
    PMPublishStatus();
}
