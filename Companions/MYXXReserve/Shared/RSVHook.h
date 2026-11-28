// MYXX Reserve — minimal ObjC method hooking without linking Substrate.
// Behaves like MSHookMessageEx: if the selector is inherited, a new method is
// added on the class so the superclass is never modified.
#pragma once
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static inline BOOL RSVHookInstance(Class cls, SEL sel, IMP replacement, IMP *original) {
    if (!cls || !sel || !replacement) return NO;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    IMP old = method_getImplementation(m);
    if (class_addMethod(cls, sel, replacement, method_getTypeEncoding(m))) {
        if (original) *original = old;          // inherited implementation
    } else {
        IMP prev = method_setImplementation(m, replacement);
        if (original) *original = prev;
    }
    return YES;
}

// Records hook results so Settings can show exactly which hooks are missing
// on this iOS build instead of failing silently.
static inline void RSVHookNote(NSMutableArray<NSString *> *missing, BOOL ok, NSString *name) {
    if (!ok && missing) [missing addObject:name];
}
