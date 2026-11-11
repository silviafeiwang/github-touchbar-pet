#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

BOOL CPTouchBarAddSystemTrayItem(NSTouchBarItem *item);
void CPTouchBarRemoveSystemTrayItem(NSTouchBarItem *item);
BOOL CPTouchBarPresentSystemModal(NSTouchBar *touchBar, NSString *trayIdentifier);
void CPTouchBarDismissSystemModal(NSTouchBar *touchBar);
void CPTouchBarSetCloseBoxVisible(BOOL visible);

NS_ASSUME_NONNULL_END
