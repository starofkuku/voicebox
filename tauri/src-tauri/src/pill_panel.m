// Native HUD panel hosting the dictate pill's webview.
//
// The dictate pill must render above native fullscreen Spaces. On macOS 15
// a plain NSWindow refuses to join fullscreen Spaces even with
// CanJoinAllSpaces | FullScreenAuxiliary and a high window level (verified
// experimentally); NSPanel — the class the system uses for HUD overlays
// (Spotlight, Raycast, CleanShot) — joins every Space. Tauri/tao cannot
// create panels, so we lift the pill's WKWebView into our own NSPanel.
//
// This lives in Objective-C (compiled by build.rs via cc) rather than Rust
// objc-crate calls because objc 0.2 mis-passes NSRect-sized struct arguments
// through its generic message path on arm64 — the message ends up in
// ___forwarding___ and aborts. Property syntax here is checked by clang.

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

/// Create the pill panel and reparent `webview_view`'s WKWebView into it.
/// Returns a +1 retained panel pointer (leaked intentionally — process
/// lifetime), or NULL when no WKWebView could be located, in which case
/// the webview is untouched and the caller can fall back to the plain
/// Tauri window.
void *voicebox_pill_panel_create(void *webview_view, double w, double h) {
    @autoreleasepool {
        NSPanel *panel = [[NSPanel alloc]
            initWithContentRect:NSMakeRect(0, 0, w, h)
                        styleMask:NSWindowStyleMaskBorderless |
                                  NSWindowStyleMaskNonactivatingPanel
                          backing:NSBackingStoreBuffered
                            defer:NO];
        if (panel == nil) {
            return NULL;
        }
        panel.level = NSStatusWindowLevel;
        panel.collectionBehavior =
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorFullScreenAuxiliary;
        panel.opaque = NO;
        panel.backgroundColor = [NSColor clearColor];
        panel.hasShadow = NO;
        panel.hidesOnDeactivate = NO;
        panel.floatingPanel = YES;

        // `ns_view()` hands us tao's container view; the WKWebView is its
        // first WKWebView-kind subview (window → tao view → WKWebView).
        NSView *candidate = (__bridge NSView *)webview_view;
        NSView *webview = nil;
        if ([candidate isKindOfClass:[WKWebView class]]) {
            webview = candidate;
        } else {
            for (NSView *sub in candidate.subviews) {
                if ([sub isKindOfClass:[WKWebView class]]) {
                    webview = sub;
                    break;
                }
            }
        }
        if (webview == nil) {
            return NULL;
        }

        [webview removeFromSuperview];
        [panel.contentView addSubview:webview];
        webview.frame = NSMakeRect(0, 0, w, h);
        webview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        return (__bridge_retained void *)panel;
    }
}

/// Position the panel (Cocoa coords, origin bottom-left) and order it front
/// without activating the app.
void voicebox_pill_panel_show(void *panel_ptr, double x, double y_cocoa,
                              double w, double h) {
    NSPanel *panel = (__bridge NSPanel *)panel_ptr;
    if (panel == nil) {
        return;
    }
    [panel setFrame:NSMakeRect(x, y_cocoa, w, h) display:YES];
    panel.ignoresMouseEvents = NO;
    [panel orderFrontRegardless];
}

void voicebox_pill_panel_hide(void *panel_ptr) {
    [(__bridge NSPanel *)panel_ptr orderOut:nil];
}
