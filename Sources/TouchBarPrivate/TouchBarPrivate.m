#import "TouchBarPrivate.h"
#import <objc/message.h>
#import <dlfcn.h>

typedef void (*CPTBOneObjectMessage)(id, SEL, id);
typedef void (*CPTBTwoObjectMessage)(id, SEL, id, id);
typedef void (*CPTBPresentMessage)(id, SEL, id, long long, id);

BOOL CPTouchBarAddSystemTrayItem(NSTouchBarItem *item) {
    Class cls = NSClassFromString(@"NSTouchBarItem");
    SEL selector = NSSelectorFromString(@"addSystemTrayItem:");
    if (!cls || ![(id)cls respondsToSelector:selector]) return NO;
    ((CPTBOneObjectMessage)objc_msgSend)((id)cls, selector, item);
    return YES;
}

void CPTouchBarRemoveSystemTrayItem(NSTouchBarItem *item) {
    Class cls = NSClassFromString(@"NSTouchBarItem");
    SEL selector = NSSelectorFromString(@"removeSystemTrayItem:");
    if (cls && [(id)cls respondsToSelector:selector]) {
        ((CPTBOneObjectMessage)objc_msgSend)((id)cls, selector, item);
    }
}

BOOL CPTouchBarPresentSystemModal(NSTouchBar *touchBar, NSString *trayIdentifier) {
    Class cls = NSClassFromString(@"NSTouchBar");
    if (!cls) return NO;

    NSArray<NSString *> *placementSelectors = @[
        @"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:",
        @"presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:"
    ];
    for (NSString *name in placementSelectors) {
        SEL selector = NSSelectorFromString(name);
        if ([(id)cls respondsToSelector:selector]) {
            ((CPTBPresentMessage)objc_msgSend)((id)cls, selector, touchBar, 1, trayIdentifier);
            return YES;
        }
    }

    NSArray<NSString *> *simpleSelectors = @[
        @"presentSystemModalTouchBar:systemTrayItemIdentifier:",
        @"presentSystemModalFunctionBar:systemTrayItemIdentifier:"
    ];
    for (NSString *name in simpleSelectors) {
        SEL selector = NSSelectorFromString(name);
        if ([(id)cls respondsToSelector:selector]) {
            ((CPTBTwoObjectMessage)objc_msgSend)((id)cls, selector, touchBar, trayIdentifier);
            return YES;
        }
    }
    return NO;
}

void CPTouchBarDismissSystemModal(NSTouchBar *touchBar) {
    Class cls = NSClassFromString(@"NSTouchBar");
    if (!cls) return;
    NSArray<NSString *> *selectors = @[
        @"dismissSystemModalTouchBar:",
        @"dismissSystemModalFunctionBar:"
    ];
    for (NSString *name in selectors) {
        SEL selector = NSSelectorFromString(name);
        if ([(id)cls respondsToSelector:selector]) {
            ((CPTBOneObjectMessage)objc_msgSend)((id)cls, selector, touchBar);
            return;
        }
    }
}

void CPTouchBarSetCloseBoxVisible(BOOL visible) {
    typedef void (*CloseBoxFunction)(BOOL);
    CloseBoxFunction function = (CloseBoxFunction)dlsym(RTLD_DEFAULT, "DFRSystemModalShowsCloseBoxWhenFrontMost");
    if (function) function(visible);
}
