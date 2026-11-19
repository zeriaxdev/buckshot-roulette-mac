#import <Cocoa/Cocoa.h>
#include "gdextension_interface.h"
#include <stdlib.h>

static NSMutableArray *observers;
static __weak NSWindow *shadow_window;
static BOOL original_shadow;

static void set_notch_shadow(NSWindow *window) {
    if (shadow_window == window) return;
    if (shadow_window) [shadow_window setHasShadow:original_shadow];
    shadow_window = window;
    if (window) {
        original_shadow = [window hasShadow];
        [window setHasShadow:NO]; // Borderless windows still receive the macOS shadow/rim.
    }
}

static void update_presentation() {
    if (![NSApp isActive] || getenv("BUCKSHOT_WINDOW_TRANSITION")) return;
    NSWindow *window = [NSApp keyWindow];
    if (!window || ([window styleMask] & NSWindowStyleMaskFullScreen)) {
        set_notch_shadow(nil);
        return;
    }
    // Only the borderless window covering a whole screen is our notch-inclusive mode.
    bool covers_screen = !([window styleMask] & NSWindowStyleMaskTitled)
        && NSEqualRects([window frame], [[window screen] frame]);
    set_notch_shadow(covers_screen ? window : nil);
    NSApplicationPresentationOptions wanted = covers_screen
        ? (NSApplicationPresentationHideDock | NSApplicationPresentationHideMenuBar)
        : NSApplicationPresentationDefault;
    if ([NSApp presentationOptions] != wanted) [NSApp setPresentationOptions:wanted];
}

static void initialize(void *, GDExtensionInitializationLevel level) {
    if (level != GDEXTENSION_INITIALIZATION_SERVERS) return;
    observers = [NSMutableArray new];
    unsetenv("BUCKSHOT_WINDOW_TRANSITION");
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    for (NSNotificationName name in @[NSWindowDidBecomeKeyNotification, NSWindowDidResizeNotification,
             NSWindowDidMoveNotification, NSApplicationDidBecomeActiveNotification]) {
        [observers addObject:[center addObserverForName:name object:nil queue:nil
            usingBlock:^(NSNotification *) { update_presentation(); }]];
    }
    [observers addObject:[center addObserverForName:NSApplicationDidResignActiveNotification object:nil queue:nil
        usingBlock:^(NSNotification *) { set_notch_shadow(nil); [NSApp setPresentationOptions:NSApplicationPresentationDefault]; }]];
    for (NSNotificationName name in @[NSWindowWillEnterFullScreenNotification, NSWindowWillExitFullScreenNotification]) {
        [observers addObject:[center addObserverForName:name object:nil queue:nil
            usingBlock:^(NSNotification *) { setenv("BUCKSHOT_WINDOW_TRANSITION", "1", 1); }]];
    }
    for (NSNotificationName name in @[NSWindowDidEnterFullScreenNotification, NSWindowDidExitFullScreenNotification]) {
        [observers addObject:[center addObserverForName:name object:nil queue:nil
            usingBlock:^(NSNotification *) { unsetenv("BUCKSHOT_WINDOW_TRANSITION"); }]];
    }
}

static void deinitialize(void *, GDExtensionInitializationLevel level) {
    if (level != GDEXTENSION_INITIALIZATION_SERVERS) return;
    for (id observer in observers) [[NSNotificationCenter defaultCenter] removeObserver:observer];
    observers = nil;
    unsetenv("BUCKSHOT_WINDOW_TRANSITION");
    set_notch_shadow(nil);
    [NSApp setPresentationOptions:NSApplicationPresentationDefault];
}

extern "C" GDExtensionBool buckshot_fullscreen_init(GDExtensionInterfaceGetProcAddress,
        GDExtensionClassLibraryPtr, GDExtensionInitialization *initialization) {
    initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SERVERS;
    initialization->userdata = nullptr;
    initialization->initialize = initialize;
    initialization->deinitialize = deinitialize;
    return true;
}
