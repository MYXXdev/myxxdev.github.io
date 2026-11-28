#import "PCPhone.h"
#import "PCStore.h"
#import <UIKit/UIKit.h>
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import "../MYBPrivatePhotos/PrivateUI.h"
#import "../../Shared/MYBConnectivity.h"
#import "../../Shared/MYBPrivateCalls.h"
#import "../../Shared/MYBPCContacts.h"

#define SEND(ret, ...) ((ret (*)(id, SEL, ##__VA_ARGS__))objc_msgSend)

static NSObject *Lock;
// Phone keeps more than one call-history controller (the Recents screen, the Missed filter, the tab badge), and some of them only hold part of the
// history. The list of each is kept apart, and the longest one is the full Recents list. Memory only, and only while Private Calls is on.
static NSMapTable *Lists;
static __weak id HistoryController;        // Phone's own call-history controller (the one whose list the screen shows)
static NSMutableDictionary *Status;        // class and selector names only
static UINavigationController *PrivateNav;
static UIWindow *CoverWindow;
static BOOL SessionOn;

static BOOL Has(id object, SEL selector) { return object && [object respondsToSelector:selector]; }
static NSString *StripDigits(const char *encoding) {
    NSMutableString *out = [NSMutableString string];
    for (const char *p = encoding; p && *p; p++) if (*p < '0' || *p > '9') [out appendFormat:@"%c", *p];
    return out;
}
static UIViewController *TopController(void) {
    UIViewController *top = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal) top = window.rootViewController;
    }
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
    return top;
}
static void Publish(void) {
    @synchronized (Lock) { NSMutableDictionary *out = [Status mutableCopy]; out[@"store"] = PCStoreState(); PCPublish(@"com.apple.mobilephone", @"MYBPCStatus", out); }
}
static void Note(NSString *key, id value) { @synchronized (Lock) { Status[key] = value; } }
static void Count(NSString *key) { @synchronized (Lock) { Status[key] = @([Status[key] integerValue] + 1); } }

// ---- what a call is --------------------------------------------------------------------------------------------------------------------------
// The matching lives in Shared/MYBPrivateCalls.h so the desktop tests run the very same code.
static id ValueFor(id object, NSString *key) { return MYBPCValue(object, key); }
static NSArray *PeopleOfRecent(id call, NSString **region) { return MYBPCPeopleOfRecent(call, region); }
static NSDictionary *EntryForRecent(id call) { return MYBPCEntryForRecent(call, PCEffectiveEntries(), PCRegion()); }
static NSArray *FullList(void) {
    NSArray *best = nil;
    @synchronized (Lock) { for (id key in Lists.keyEnumerator) { NSArray *one = [Lists objectForKey:key]; if (one.count > best.count) best = one; } }
    return best;
}
// Names of the properties of one call record, and the on/off or small values of the ones that are flags (no numbers, names, dates or durations), so the
// settings report shows what this iOS build calls them.
static NSArray *FieldsOf(id call) {
    NSMutableArray *out = [NSMutableArray array];
    for (Class c = object_getClass(call); c && c != NSObject.class && out.count < 60; c = class_getSuperclass(c)) {
        unsigned n = 0; objc_property_t *props = class_copyPropertyList(c, &n);
        for (unsigned i = 0; i < n && out.count < 60; i++) {
            NSString *name = @(property_getName(props[i])); NSString *low = name.lowercaseString;
            id v = MYBPCValue(call, name);
            BOOL sensitive = [low containsString:@"duration"] || [low containsString:@"date"] || [low containsString:@"time"] || [low hasSuffix:@"id"] || [low containsString:@"count"] || [low containsString:@"number"] || [low containsString:@"name"] || [low containsString:@"handle"];
            if ([v isKindOfClass:NSNumber.class] && !sensitive) [out addObject:[NSString stringWithFormat:@"%@=%@", name, v]]; else [out addObject:name];
        }
        free(props);
    }
    return out;
}
static void Remember(id controller, NSArray *all) {
    @synchronized (Lock) {
        if (!Lists) Lists = [NSMapTable weakToStrongObjectsMapTable];
        [Lists setObject:[all copy] forKey:controller];
        NSArray *best = nil; id bestController = nil;
        for (id key in Lists.keyEnumerator) { NSArray *one = [Lists objectForKey:key]; if (one.count > best.count) { best = one; bestController = key; } }
        HistoryController = bestController;                                                 // the controller whose list is the full one
        if (!Status[@"callFields"] && best.count) { id first = best.firstObject; Status[@"callFields"] = FieldsOf(first); Status[@"callClass"] = NSStringFromClass([first class]); }
        if (best.count) {                                                                   // shapes only: no numbers, names or dates
            NSMutableOrderedSet *shapes = [NSMutableOrderedSet orderedSet];
            for (id call in best) {
                id st = MYBPCValue(call, @"callStatus"), mo = MYBPCValue(call, @"mobileOriginated"), iso = MYBPCValue(call, @"isoCountryCode"), cid = MYBPCValue(call, @"callerId");
                NSString *c = [cid isKindOfClass:NSString.class] ? cid : @"";
                [shapes addObject:[NSString stringWithFormat:@"status%@ out%@ %@ %@%lu", st, mo, [iso isKindOfClass:NSString.class] ? iso : @"-", [c hasPrefix:@"+"] ? @"+" : @"", (unsigned long)c.length]];
                if (shapes.count >= 24) break;
            }
            Status[@"callShapes"] = shapes.array;
        }
        Status[@"fullCalls"] = @(best.count); Status[@"historyLists"] = @(Lists.count);
    }
}
static NSArray *Hide(NSArray *all, id controller, BOOL remember) {
    if (![all isKindOfClass:NSArray.class] || !PCSwitchOn()) return all;
    @try {
        if (remember && controller) Remember(controller, all);
        return MYBPCFilterRecents(all, PCEffectiveEntries(), PCRegion());
    } @catch (NSException *e) { (void)e; return all; }
}
static NSString *RecentKind(id call) { return MYBPCKindOfRecent(call); }

// ---- hooks on the call-history list ----------------------------------------------------------------------------------------------------------
static BOOL HookShape(Class cls, SEL selector, NSString *shape, IMP (^make)(IMP original)) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || ![StripDigits(method_getTypeEncoding(method)) isEqualToString:shape]) return NO;   // a different signature on this iOS build: not hooked
    IMP original = method_getImplementation(method);
    method_setImplementation(method, make(original));
    return YES;
}
static void InstallHistoryHooks(void) {
    Class cls = objc_getClass("TUCallHistoryController");
    BOOL list = NO, predicate = NO, unread = NO;
    if (cls) {
        list = HookShape(cls, NSSelectorFromString(@"recentCalls"), @"@@:", ^IMP(IMP original) {
            return imp_implementationWithBlock(^id(id self) {
                id all = ((id (*)(id, SEL))original)(self, NSSelectorFromString(@"recentCalls"));
                return Hide(all, self, YES);
            });
        });
        predicate = HookShape(cls, NSSelectorFromString(@"recentCallsWithPredicate:"), @"@@:@", ^IMP(IMP original) {
            return imp_implementationWithBlock(^id(id self, id pred) {
                id all = ((id (*)(id, SEL, id))original)(self, NSSelectorFromString(@"recentCallsWithPredicate:"), pred);
                return Hide(all, nil, NO);
            });
        });
        unread = HookShape(cls, NSSelectorFromString(@"unreadCallCount"), @"Q@:", ^IMP(IMP original) {
            return imp_implementationWithBlock(^unsigned long long(id self) {
                unsigned long long count = ((unsigned long long (*)(id, SEL))original)(self, NSSelectorFromString(@"unreadCallCount"));
                if (!PCSwitchOn() || !count) return count;
                NSArray *full = FullList();
                unsigned long long hidden = 0;
                @try { for (id call in full) if (EntryForRecent(call) && ![ValueFor(call, @"read") boolValue]) { unsigned long long n = [ValueFor(call, @"unreadCount") unsignedLongLongValue]; hidden += n ?: 1; } } @catch (NSException *e) { (void)e; }
                return hidden >= count ? 0 : count - hidden;
            });
        });
    }
    Note(@"historyClass", @(cls != nil)); Note(@"listHooked", @(list)); Note(@"predicateHooked", @(predicate)); Note(@"unreadHooked", @(unread));
}
static BOOL HidingWorks(void) { NSDictionary *s; @synchronized (Lock) { s = [Status copy]; } return [s[@"listHooked"] boolValue]; }

// ---- adding numbers ---------------------------------------------------------------------------------------------------------------------------
static void AfterChange(void) {
    // Phone's own list reloads when the call history says it changed
    void *symbol = dlsym(RTLD_DEFAULT, "TUCallHistoryControllerRecentCallsDidChangeNotification");
    NSString *name = symbol ? *(__unsafe_unretained NSString **)symbol : nil;
    if (![name isKindOfClass:NSString.class]) name = @"TUCallHistoryControllerRecentCallsDidChangeNotification";
    [NSNotificationCenter.defaultCenter postNotificationName:name object:HistoryController];
}
// A number is accepted with or without a country code: one typed the way a caller shows up (612 34 56 78) and one with +34 are the same number.
static BOOL AddNumber(NSString *raw, NSString *name, NSString *action, NSString *region, UIViewController *host, BOOL quiet) {
    if (MYBPCIsProtectedNumber(raw)) { if (!quiet) MYXXShowMessage(host, @"Not allowed", @"Emergency numbers can't be made private.", NO); return NO; }
    NSString *key = MYBPCKey(raw, region.length ? region : PCRegion());                      // read in the country the call itself came from, as matching does
    if (!key) { if (!quiet) MYXXShowMessage(host, @"Not a phone number", @"Type the number the way it shows when they call. A country code is not needed.", NO); return NO; }
    NSDictionary *existing = MYBPCEntryForKeyLoose(PCEffectiveEntries(), key);              // already private under another spelling: that entry is kept, not duplicated
    if (existing) { key = existing[@"k"]; action = existing[@"a"]; }
    NSString *label = MYBPCNameOnly(name) ?: MYBPCContactName(key) ?: MYBPCFormat(key, PCRegion());
    if (!PCSetEntry(key, label, action, YES)) { if (!quiet) MYXXShowMessage(host, @"Couldn't save", @"Not saved. Nothing was changed.", NO); return NO; }
    AfterChange();
    return YES;
}
@interface PCContactDelegate : NSObject <CNContactPickerDelegate>
@property(nonatomic, copy) void (^done)(NSArray<NSDictionary *> *numbers);
@end
@implementation PCContactDelegate
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)property {   // tapping a number adds it
    id value = property.value;
    NSString *name = [CNContactFormatter stringFromContact:property.contact style:CNContactFormatterStyleFullName];
    if (self.done) self.done([value isKindOfClass:CNPhoneNumber.class] ? @[@{@"number": [(CNPhoneNumber *)value stringValue], @"name": name ?: @""}] : @[]);
}
@end
static PCContactDelegate *PickerDelegate;
static void ChooseFromContacts(UIViewController *host, void (^done)(void)) {
    CNContactPickerViewController *picker = [CNContactPickerViewController new];
    picker.displayedPropertyKeys = @[CNContactPhoneNumbersKey];
    PickerDelegate = [PCContactDelegate new];
    PickerDelegate.done = ^(NSArray<NSDictionary *> *numbers) {
        NSInteger added = 0, refused = 0;
        for (NSDictionary *item in numbers) { if (AddNumber(item[@"number"], item[@"name"], MYB_PC_ACTION_MUTE, nil, host, YES)) added++; else refused++; }
        if (added) { if (done) done(); }
        UIViewController *top = TopController() ?: host;
        if (added || refused) MYXXShowMessage(top, added ? @"Added" : @"Not added",
            [NSString stringWithFormat:@"%ld number%@ added.%@", (long)added, added == 1 ? @"" : @"s", refused ? [NSString stringWithFormat:@" %ld could not be read as a phone number.", (long)refused] : @""], added > 0);
    };
    picker.delegate = PickerDelegate;
    [host presentViewController:picker animated:YES completion:nil];
}
static void AskForNumber(UIViewController *host, void (^done)(void)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add a Number" message:@"Type it the way it shows when they call. A country code is not needed." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.keyboardType = UIKeyboardTypePhonePad; field.placeholder = @"Phone number"; field.autocorrectionType = UITextAutocorrectionTypeNo; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak UIAlertController *weak = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { (void)a; if (AddNumber(weak.textFields.firstObject.text, nil, MYB_PC_ACTION_MUTE, nil, host, NO) && done) done(); }]];
    [host presentViewController:alert animated:YES completion:nil];
}
// The next screen opens only after the choice sheet has gone, and on whatever is on top then (presenting on a screen that is still covered does nothing).
static void AfterSheet(UIViewController *host, void (^next)(UIViewController *top)) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *top = TopController() ?: host;
        next(top);
    });
}
static void ShowAddChoices(UIViewController *host, void (^done)(void)) {
    MYXXShowChoice(host, @"Add to Private Calls", @"New numbers start on Mute. You can change that for each number afterwards.", @"phone.badge.plus", @[
        @{@"title": @"Enter a Number", @"style": @"primary", @"handler": ^{ AfterSheet(host, ^(UIViewController *top) { AskForNumber(top, done); }); }},
        @{@"title": @"Choose from Contacts", @"style": @"secondary", @"handler": ^{ AfterSheet(host, ^(UIViewController *top) { ChooseFromContacts(top, done); }); }},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}

// ---- Private Recents ---------------------------------------------------------------------------------------------------------------------------
@interface PCListController : UITableViewController
@property(nonatomic, copy) NSArray *entries;
@property(nonatomic, copy) NSArray *calls;
@property(nonatomic) UISegmentedControl *filter;
@property(nonatomic) UILabel *footerLabel;
@property(nonatomic) CGFloat footerWidthLaidOutFor;
@end
@implementation PCListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = MYXXBackground();
    self.tableView.separatorColor = [UIColor.whiteColor colorWithAlphaComponent:0.12];
    self.filter = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Missed"]];
    self.filter.selectedSegmentIndex = 0;
    [self.filter addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.filter;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"] style:UIBarButtonItemStylePlain target:self action:@selector(add)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Add a number";
    // This lived as a Settings footer before Private Calls moved entirely in here; it stays with the list itself now, so it is still read before anyone
    // relies on it, not lost when the Settings page was removed.
    self.footerLabel = [UILabel new];
    self.footerLabel.text = @"Private numbers are kept out of Recents in Phone on this iPhone and shown in Private Recents after Face ID or your passcode. No call record is changed or deleted, and they show normally whenever MYbloXX® is not active. Hiding a call here does not hide it from your carrier, voicemail, other devices signed in to your Apple ID, contact cards or Settings.";
    self.footerLabel.numberOfLines = 0; self.footerLabel.textColor = MYXXMuted(); self.footerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; self.footerLabel.adjustsFontForContentSizeCategory = YES;
    [self reload];
}
// viewDidLoad runs before the table has ever been laid out, so its bounds are still zero there; sizing the footer off that width is what produced the
// one-character-per-line text down the left edge. Laying it out here instead, only when the width actually changed, uses the real width every time.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.tableView.bounds.size.width;
    if (width <= 0 || width == self.footerWidthLaidOutFor) return;
    self.footerWidthLaidOutFor = width;
    self.footerLabel.frame = CGRectMake(16, 0, width - 32, 1);
    [self.footerLabel sizeToFit];
    self.footerLabel.frame = CGRectMake(16, 12, width - 32, self.footerLabel.frame.size.height + 12);
    UIView *footerHost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, self.footerLabel.frame.size.height + 24)];
    [footerHost addSubview:self.footerLabel];
    self.tableView.tableFooterView = footerHost;
}
- (void)reload {
    PCReload();
    id controller = HistoryController;
    NSArray *fresh = Has(controller, NSSelectorFromString(@"recentCalls")) ? ValueFor(controller, @"recentCalls") : nil;   // refreshes the in-memory full list
    (void)fresh;
    NSArray *full = FullList();
    NSMutableArray *mine = [NSMutableArray array];
    BOOL missedOnly = self.filter.selectedSegmentIndex == 1;
    for (id call in full) {
        if (!EntryForRecent(call)) continue;
        if (missedOnly && ![RecentKind(call) isEqual:@"Missed"]) continue;
        [mine addObject:call];
    }
    self.entries = PCEffectiveEntries();
    self.calls = mine;
    [self.tableView reloadData];
    [self syncEmpty];
}
- (void)syncEmpty {
    if (self.entries.count || self.calls.count) { self.tableView.backgroundView = nil; return; }
    UILabel *label = [UILabel new];
    label.text = @"Nothing here yet.\nTap + to add a number, or press and hold a call in Recents and choose Make Private.";
    label.numberOfLines = 0; label.textAlignment = NSTextAlignmentCenter; label.textColor = MYXXMuted();
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]; label.adjustsFontForContentSizeCategory = YES;
    UIView *host = [UIView new]; host.backgroundColor = MYXXBackground();
    label.translatesAutoresizingMaskIntoConstraints = NO; [host addSubview:label];
    [NSLayoutConstraint activateConstraints:@[[label.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:32], [label.trailingAnchor constraintEqualToAnchor:host.trailingAnchor constant:-32],
        [label.centerYAnchor constraintEqualToAnchor:host.centerYAnchor constant:-40]]];
    self.tableView.backgroundView = host;
}
- (void)done { [self.navigationController dismissViewControllerAnimated:YES completion:nil]; }
- (void)add { ShowAddChoices(self, ^{ [self reload]; }); }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)(s == 0 ? self.entries.count : self.calls.count); }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return s == 0 ? (self.entries.count ? @"PRIVATE NUMBERS" : nil) : (self.calls.count ? @"CALLS" : nil); }
- (void)tableView:(UITableView *)t willDisplayHeaderView:(UIView *)view forSection:(NSInteger)s { if ([view isKindOfClass:UITableViewHeaderFooterView.class]) ((UITableViewHeaderFooterView *)view).textLabel.textColor = MYXXMuted(); }
- (NSString *)titleForCall:(id)call {
    NSDictionary *entry = EntryForRecent(call);
    if (entry) {                                                                        // the name on the rule or in Contacts, the same as the list above
        NSString *name = nil;
        for (NSString *field in @[@"callerName", @"callerIdForDisplay"]) { name = MYBPCNameOnly(ValueFor(call, field)); if (name) break; }
        return MYBPCLabel(entry, name ?: MYBPCContactName(entry[@"k"]), PCRegion());
    }
    for (NSString *name in @[@"callerIdForDisplay", @"callerName", @"callerId"]) { id v = ValueFor(call, name); if ([v isKindOfClass:NSString.class] && [v length]) return v; }
    return @"Private number";
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:@"v"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"v"];
    cell.backgroundColor = MYXXPanel(); cell.textLabel.textColor = UIColor.whiteColor; cell.detailTextLabel.textColor = MYXXMuted(); cell.imageView.image = nil;
    if (p.section == 0) {
        NSDictionary *entry = self.entries[(NSUInteger)p.row];
        cell.textLabel.text = MYBPCLabelWithNumber(entry, MYBPCContactName(entry[@"k"]), PCRegion());
        cell.detailTextLabel.text = MYBPCActionName(entry[@"a"]);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    id call = self.calls[(NSUInteger)p.row];
    NSString *kind = RecentKind(call);
    cell.textLabel.text = [self titleForCall:call];
    NSDate *date = ValueFor(call, @"date");
    NSDateFormatter *format = [NSDateFormatter new]; format.dateStyle = NSDateFormatterShortStyle; format.timeStyle = NSDateFormatterShortStyle; format.doesRelativeDateFormatting = YES;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", kind, [date isKindOfClass:NSDate.class] ? [format stringFromDate:date] : @""];
    NSString *symbol = [kind isEqual:@"Missed"] ? @"phone.arrow.down.left" : [kind isEqual:@"Outgoing"] ? @"phone.arrow.up.right" : @"phone.arrow.down.left";
    cell.imageView.image = [UIImage systemImageNamed:symbol];
    cell.imageView.tintColor = [kind isEqual:@"Missed"] ? UIColor.systemRedColor : MYXXMuted();
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}
- (void)chooseActionFor:(NSDictionary *)entry {
    NSString *key = entry[@"k"], *shown = MYBPCLabelWithNumber(entry, MYBPCContactName(entry[@"k"]), PCRegion());
    void (^set)(NSString *) = ^(NSString *action) { if (!PCSetEntry(key, entry[@"d"], action, YES)) MYXXShowMessage(self, @"Couldn't save", @"Not saved. Nothing was changed.", NO); AfterChange(); [self reload]; };
    MYXXShowChoice(self, shown, @"What should happen when this number calls? A caller ID match is only a rule match: it does not prove who is calling.", @"phone.badge.waveform", @[
        @{@"title": @"Mute", @"detail": @"Silences the ringer. The caller keeps ringing.", @"style": @"primary", @"handler": ^{ set(MYB_PC_ACTION_MUTE); }},
        @{@"title": @"Decline", @"detail": @"Declines the moment it rings.", @"style": @"secondary", @"handler": ^{ set(MYB_PC_ACTION_DECLINE); }},
        @{@"title": @"Hang up", @"detail": @"Picks up and hangs up at once. The caller hears it was answered.", @"style": @"secondary", @"handler": ^{ set(MYB_PC_ACTION_HANGUP); }},
        @{@"title": @"Remove from Private Calls", @"style": @"destructive", @"handler": ^{ [self confirmRemove:entry]; }},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}
- (void)confirmRemove:(NSDictionary *)entry {
    MYXXShowChoice(self, @"Remove this number?", @"Its calls show in normal Recents again. No call record is deleted or changed.", @"arrow.uturn.backward", @[
        @{@"title": @"Remove", @"style": @"primary", @"handler": ^{
            if (!PCSetEntry(entry[@"k"], entry[@"d"], entry[@"a"], NO)) MYXXShowMessage(self, @"Couldn't save", @"Not saved. Nothing was changed.", NO);
            AfterChange(); [self reload]; }},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];
    if (p.section == 0) { [self chooseActionFor:self.entries[(NSUInteger)p.row]]; return; }
    id call = self.calls[(NSUInteger)p.row];
    NSDictionary *entry = EntryForRecent(call);
    NSString *key = entry[@"k"];
    NSString *digits = [key hasPrefix:@"+"] ? key : [[key componentsSeparatedByString:@":"] lastObject];
    if (!digits.length) return;
    MYXXShowChoice(self, [self titleForCall:call], @"Call this number?", @"phone.fill", @[
        @{@"title": @"Call", @"style": @"primary", @"handler": ^{
            NSURL *url = [NSURL URLWithString:[@"tel:" stringByAppendingString:digits]];
            if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil]; }},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)t trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)p {
    NSDictionary *entry = p.section == 0 ? self.entries[(NSUInteger)p.row] : EntryForRecent(self.calls[(NSUInteger)p.row]);
    if (!entry) return nil;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Remove" handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        (void)a; (void)v; [self confirmRemove:entry]; done(YES);
    }];
    remove.backgroundColor = MYXXAccent();
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}
@end

static void Present(UIViewController *host) {
    if (PrivateNav && !PrivateNav.presentingViewController) PrivateNav = nil;
    if (PrivateNav || host.presentedViewController) return;
    SessionOn = YES;
    PCListController *list = [PCListController new];
    list.title = @"Private Recents";
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    MYXXStyleNavigation(nav);
    PrivateNav = nav;
    [host presentViewController:nav animated:YES completion:nil];
}
// The gesture only starts the prompt. Access exists only after iOS reports success; a cancel, a failure or a phone without a passcode opens nothing.
static void OpenFromGesture(UIViewController *host) {
    if (PrivateNav && !PrivateNav.presentingViewController) PrivateNav = nil;
    if (!PCSwitchOn() || !HidingWorks() || !host || PrivateNav) return;
    MYXXAuthenticate(host, @"Open Private Recents", ^{ Present(TopController() ?: host); });
}
void PCPhoneLockAll(void) {
    SessionOn = NO;
    @synchronized (Lock) { [Lists removeAllObjects]; }                         // the full list is not kept once the session closes
    if (PrivateNav) {
        PrivateNav.view.hidden = YES;
        UIViewController *presenter = PrivateNav.presentingViewController;
        PrivateNav = nil;
        [presenter dismissViewControllerAnimated:NO completion:nil];
    }
}
void PCPhoneCoverIfNeeded(void) {
    if (CoverWindow || !(SessionOn || PrivateNav)) return;
    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) if ([candidate isKindOfClass:UIWindowScene.class]) { scene = (UIWindowScene *)candidate; break; }
    if (!scene) return;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.windowLevel = UIWindowLevelAlert + 1000;
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = UIColor.clearColor;
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];   // the screen behind, softly blurred
    blur.frame = root.view.bounds; blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIView *tint = [[UIView alloc] initWithFrame:blur.bounds]; tint.backgroundColor = [UIColor colorWithWhite:0 alpha:0.30]; tint.autoresizingMask = blur.autoresizingMask;
    [blur.contentView addSubview:tint];
    [root.view addSubview:blur];
    UIImageView *mark = [[UIImageView alloc] initWithImage:MYXXMarkImage()];
    mark.contentMode = UIViewContentModeScaleAspectFit;
    mark.frame = CGRectMake(0, 0, 84, 84);
    mark.center = CGPointMake(CGRectGetMidX(root.view.bounds), CGRectGetMidY(root.view.bounds));
    mark.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [root.view addSubview:mark];
    window.rootViewController = root;
    window.hidden = NO;
    CoverWindow = window;
}
void PCPhoneUncover(void) { CoverWindow.hidden = YES; CoverWindow = nil; }

// ---- five taps on Recents ---------------------------------------------------------------------------------------------------------------------
static void DiscoverRecents(UIViewController *top);
static void InstallSwipe(UIViewController *top, UITableView *table);
static char TapsKey, DelegateKey;
static BOOL IsRecentsNav(UINavigationController *nav) {
    UIViewController *top = nav.topViewController;
    if (!top || nav.viewControllers.count != 1) return NO;
    NSString *name = NSStringFromClass(top.class);
    if ([name containsString:@"Recents"] && ![name containsString:@"Search"] && ![name containsString:@"Cell"] && ![name containsString:@"Detail"] && ![name containsString:@"Info"] && ![name containsString:@"Header"]) return YES;
    UITabBarController *tabs = nav.tabBarController;
    return tabs && tabs.viewControllers.count >= 4 && tabs.viewControllers[1] == nav;       // the Recents tab is the second one; the class name was not enough
}
@interface PCTapDelegate : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UINavigationController *navigation;
@end
@implementation PCTapDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    UINavigationController *nav = self.navigation;
    if (!nav || !PCSwitchOn() || !HidingWorks() || nav.presentedViewController || !IsRecentsNav(nav)) return NO;
    Count(@"tapTouches");
    UIView *bar = gesture.view;
    if (bar == nav.navigationBar) {                                                            // anywhere on the bar that is not a button
        for (UIView *v = touch.view; v && v != bar; v = v.superview)
            if ([v isKindOfClass:UIControl.class] || [NSStringFromClass(v.class) containsString:@"Button"] || [NSStringFromClass(v.class) containsString:@"SearchBar"]) return NO;
        return YES;
    }
    UITabBar *tabBar = nav.tabBarController.tabBar;                                            // the Recents tab button: the second of the tabs, by position
    NSUInteger tabs = nav.tabBarController.viewControllers.count;
    if (bar != tabBar || tabs < 4) return NO;
    CGFloat x = [touch locationInView:tabBar].x, width = tabBar.bounds.size.width / (CGFloat)tabs;
    return x >= width && x < 2 * width;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
- (void)taps:(UITapGestureRecognizer *)gesture {
    UINavigationController *nav = self.navigation;
    if (gesture.state != UIGestureRecognizerStateRecognized || !nav || nav.presentedViewController || !PCSwitchOn()) return;
    Count(@"tapsRecognized"); Publish();
    OpenFromGesture(nav);
}
@end
static void AttachTaps(UINavigationController *nav) {
    if (objc_getAssociatedObject(nav.navigationBar, &TapsKey)) return;
    PCTapDelegate *delegate = [PCTapDelegate new];
    delegate.navigation = nav;
    for (UIView *view in @[nav.navigationBar, nav.tabBarController.tabBar ?: nav.navigationBar]) {
        if (objc_getAssociatedObject(view, &TapsKey)) continue;
        UITapGestureRecognizer *taps = [[UITapGestureRecognizer alloc] initWithTarget:delegate action:@selector(taps:)];
        taps.numberOfTapsRequired = 5; taps.cancelsTouchesInView = NO; taps.delaysTouchesEnded = NO; taps.delegate = delegate;
        [view addGestureRecognizer:taps];
        objc_setAssociatedObject(view, &TapsKey, taps, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(nav.navigationBar, &DelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void InstallTapHook(void) {
    BOOL hooked = HookShape(UINavigationController.class, @selector(viewDidLayoutSubviews), @"v@:", ^IMP(IMP original) {
        return imp_implementationWithBlock(^(UINavigationController *self) {
            ((void (*)(id, SEL))original)(self, @selector(viewDidLayoutSubviews));
            if (!PCSwitchOn() || !HidingWorks()) return;
            @try { if (IsRecentsNav(self) && self.view.window) { AttachTaps(self); DiscoverRecents(self.topViewController); } } @catch (NSException *e) { (void)e; }
        });
    });
    Note(@"tapHooked", @(hooked));
}

// ---- long-press: Make Private ----------------------------------------------------------------------------------------------------------------
// Phone's Recents rows already have a press-and-hold menu. Make Private is added to it only when the row's call can be read with certainty (it is a
// call-history entry). If it cannot, the menu is left exactly as Apple ships it.
// Looks at the instance variables of an object (and its parents, never UIKit's): a single call-history entry, or, with a table, an array whose size matches
// the rows on screen and whose entry for this row is one. Names are never read out, only classes are compared.
static __weak UITableView *RecentsTable;
static __weak id RecentsController;
static BOOL IsAppleUIClass(const char *name);
static id ScanForCall(id object, UITableView *table, NSIndexPath *path) {
    Class recentClass = objc_getClass("CHRecentCall");
    if (!object || !recentClass) return nil;
    for (Class cls = [object class]; cls && !IsAppleUIClass(class_getName(cls)); cls = class_getSuperclass(cls)) {
        unsigned int n = 0; Ivar *ivars = class_copyIvarList(cls, &n); id result = nil;
        for (unsigned int i = 0; i < n && !result; i++) {
            const char *type = ivar_getTypeEncoding(ivars[i]);
            if (!type || type[0] != '@') continue;
            id value = object_getIvar(object, ivars[i]);
            if (!table && [value isKindOfClass:recentClass]) result = value;
            else if (table && [value isKindOfClass:NSArray.class] && path.section == 0 && table.numberOfSections == 1 && (NSInteger)[value count] == [table numberOfRowsInSection:0] && (NSUInteger)path.row < [value count]) {
                id element = [value objectAtIndex:(NSUInteger)path.row];
                if ([element isKindOfClass:recentClass]) result = element;
            }
        }
        free(ivars);
        if (result) return result;
    }
    return nil;
}
static id CallForRow(id controller, UITableView *table, NSIndexPath *path) {
    Class recentClass = objc_getClass("CHRecentCall");
    UITableViewCell *cell = [table cellForRowAtIndexPath:path];
    for (NSString *key in @[@"recentCall", @"call", @"callGroup", @"representedCall", @"representedObject"]) {
        id v = ValueFor(cell, key);
        if (v && recentClass && [v isKindOfClass:recentClass]) { Note(@"rowResolved", [@"cell." stringByAppendingString:key]); return v; }
    }
    for (NSString *name in @[@"recentCallAtIndexPath:", @"callAtIndexPath:", @"recentCallForIndexPath:"]) {
        SEL s = NSSelectorFromString(name);
        if (Has(controller, s)) { id v = SEND(id, id)(controller, s, path); if (v && recentClass && [v isKindOfClass:recentClass]) { Note(@"rowResolved", [@"controller." stringByAppendingString:name]); return v; } }
    }
    for (NSString *key in @[@"recentCalls", @"calls", @"displayedCalls", @"filteredCalls", @"callGroups"]) {   // the list the screen shows (already without private calls)
        id delegateObject = table.delegate;
        for (id owner in @[controller ?: (id)NSNull.null, delegateObject ?: (id)NSNull.null]) {
            id arr = owner == (id)NSNull.null ? nil : ValueFor(owner, key);
            if ([arr isKindOfClass:NSArray.class] && path.section == 0 && (NSInteger)[arr count] == [table numberOfRowsInSection:0] && (NSUInteger)path.row < [arr count]) {
                id v = [arr objectAtIndex:(NSUInteger)path.row];
                if (v && recentClass && [v isKindOfClass:recentClass]) { Note(@"rowResolved", [@"list." stringByAppendingString:key]); return v; }
            }
        }
    }
    {   // any list the screen holds that matches the rows on screen, and any call a row keeps
        id cellCall = cell ? ScanForCall(cell, nil, nil) : nil;
        if (cellCall) { Note(@"rowResolved", @"cell.ivar"); return cellCall; }
        for (id owner in @[controller ?: (id)NSNull.null, table.delegate ?: (id)NSNull.null]) {
            if (owner == (id)NSNull.null) continue;
            id found = ScanForCall(owner, table, path);
            if (found) { Note(@"rowResolved", @"list.ivar"); return found; }
        }
    }
    Note(@"rowResolved", @"none"); Note(@"cellClass", cell ? NSStringFromClass(cell.class) : @"none");
    return nil;
}
static void MakePrivate(id call, UIViewController *host) {
    NSString *region = nil;
    NSArray *people = PeopleOfRecent(call, &region);
    if (people.count != 1) { MYXXShowMessage(host, @"Not added", @"This call has more than one person, so it can't be made private as a whole.", NO); return; }
    NSString *raw = nil;
    for (NSString *form in people.firstObject) if (MYBPCKey(form, region ?: PCRegion())) { raw = form; break; }
    if (!raw) { MYXXShowMessage(host, @"Not added", @"This call has no number that can be matched safely.", NO); return; }
    NSString *callName = nil;
    for (NSString *field in @[@"callerName", @"callerIdForDisplay"]) { NSString *candidate = MYBPCNameOnly(ValueFor(call, field)); if (candidate) { callName = candidate; break; } }
    if (AddNumber(raw, callName, MYB_PC_ACTION_MUTE, region, host, NO)) MYXXShowConfirmation(TopController() ?: host, @"Made private", @"lock.fill");
}
static BOOL IsAppleUIClass(const char *name) { return !name || !strncmp(name, "UI", 2) || !strncmp(name, "_UI", 3) || !strncmp(name, "NS", 2) || !strncmp(name, "PC", 2) || strstr(name, "MYXX"); }
static UIView *FindOfClass(UIView *root, Class cls, int depth) {
    if (depth > 6) return nil;
    if ([root isKindOfClass:cls]) return root;
    for (UIView *child in root.subviews) { UIView *found = FindOfClass(child, cls, depth + 1); if (found) return found; }
    return nil;
}
// The Recents list is found when it is on screen, and the swipe action is added to it once (see below).
static void DiscoverRecents(UIViewController *top) {
    static BOOL done;
    if (done || !top.isViewLoaded) return;
    UITableView *table = (UITableView *)FindOfClass(top.view, UITableView.class, 0);
    Note(@"recentsClass", NSStringFromClass(top.class));
    Note(@"recentsView", table ? @"table" : @"other");
    if (!table) return;
    RecentsTable = table; RecentsController = top;
    InstallSwipe(top, table);
    done = YES;
    Publish();
}
// Swipe on a Recents row: "Private", shown only while Private Recents is unlocked this session (after the five taps and authentication).
// Swipe right is added to the screen as a new action; swipe left gets the action added to Phone's own (Delete stays first).
static id SwipeWith(id existing, id call) {
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Private" handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        (void)a; (void)v; MakePrivate(call, TopController()); done(YES);
    }];
    action.backgroundColor = UIColor.systemIndigoColor;
    action.image = [UIImage systemImageNamed:@"lock.fill"];
    NSMutableArray *all = [NSMutableArray array];
    if ([existing isKindOfClass:UISwipeActionsConfiguration.class]) [all addObjectsFromArray:[(UISwipeActionsConfiguration *)existing actions]];
    [all addObject:action];
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:all];
    if ([existing isKindOfClass:UISwipeActionsConfiguration.class]) config.performsFirstActionWithFullSwipe = [(UISwipeActionsConfiguration *)existing performsFirstActionWithFullSwipe];
    else config.performsFirstActionWithFullSwipe = NO;
    return config;
}
static void InstallSwipe(UIViewController *top, UITableView *table) {
    static BOOL installed;
    if (installed || !top || !table) return;
    Class cls = top.class;
    for (NSString *name in @[@"tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:"]) {       // the left side only: swipe a call to the right
        SEL sel = NSSelectorFromString(name);
        Method own = class_getInstanceMethod(cls, sel);
        IMP (^make)(IMP) = ^IMP(IMP original) {
            return imp_implementationWithBlock(^id(id self, UITableView *t, NSIndexPath *path) {
                id existing = original ? ((id (*)(id, SEL, id, id))original)(self, sel, t, path) : nil;
                if (!SessionOn || !PCSwitchOn() || !HidingWorks() || t != RecentsTable) return existing;
                @try {
                    id call = CallForRow(self, t, path);
                    return call ? SwipeWith(existing, call) : existing;
                } @catch (NSException *e) { (void)e; return existing; }
            });
        };
        if (own && ![StripDigits(method_getTypeEncoding(own)) isEqualToString:@"@@:@@"]) continue;
        if (own && ![name hasPrefix:@"tableView:leading"] && class_getMethodImplementation(cls, sel) == method_getImplementation(own)) {
            method_setImplementation(own, make(method_getImplementation(own)));
        } else if (own) {
            method_setImplementation(own, make(method_getImplementation(own)));
        } else {
            class_addMethod(cls, sel, make(NULL), "@@:@@");
        }
    }
    id delegate = table.delegate; table.delegate = nil; table.delegate = delegate;       // the list asks again which swipe actions the screen has
    installed = YES;
    Note(@"swipeInstalled", @YES);
}

void PCPhoneInstall(void) {
    MYBPCContactFallback = MYBPCContactEntry;                                                // another number of a private contact is the same person
    Lock = [NSObject new];
    Status = [NSMutableDictionary dictionary];
    PCReload();
    if ([PCStoreState()[@"oldListPending"] boolValue] || [PCStoreState()[@"queued"] integerValue]) notify_post(MYB_PC_REQUEST_NOTIFY);   // ask the helper to merge the r18 list
    PCRetire();
    InstallHistoryHooks();
    InstallTapHook();
    static int token = 0;
    notify_register_dispatch(MYB_PRIV_NOTIFY, &token, dispatch_get_main_queue(), ^(int t) {
        (void)t;
        PCReload();
        PCRetire();
        Publish();
        if (!PCSwitchOn()) PCPhoneLockAll();                            // switched off: Private Recents closes and every call shows again
        AfterChange();
    });
    Publish();
}
