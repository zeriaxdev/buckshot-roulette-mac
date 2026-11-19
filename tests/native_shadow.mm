#include "../tools/native/presentation.mm"
#include <cassert>

int main() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSWindow *first = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 960, 540)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
        NSWindow *second = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 960, 540)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
        [first setHasShadow:YES];
        [second setHasShadow:NO];
        set_notch_shadow(first);
        assert(![first hasShadow]);
        set_notch_shadow(first); // Repeated resize notifications must retain the original value.
        set_notch_shadow(second);
        assert([first hasShadow] && ![second hasShadow]);
        set_notch_shadow(nil);
        assert(![second hasShadow]);
        set_notch_shadow(first);
        deinitialize(nullptr, GDEXTENSION_INITIALIZATION_SERVERS);
        assert([first hasShadow]);
        puts("PASS native shadow suppression, repeated calls, window switch and restoration");
    }
}
