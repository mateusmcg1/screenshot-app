#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#import <AudioToolbox/AudioToolbox.h>

// Configuration - Change these values
static NSString *API_ENDPOINT = @"http://186.190.215.38:3000/screenshots/device/";
static NSInteger SCREENSHOT_INTERVAL = 60; // 1 minute in seconds
static NSString *DEVICE_ID = nil; // Will be set to device UDID

// Declare the new methods in SpringBoard interface
@interface SpringBoard (ScreenshotMonitor)
- (void)logDeviceInfo;
@end

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // Get device ID if not set
    if (!DEVICE_ID) {
        DEVICE_ID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    
    // Log device info when app starts
    [self performSelector:@selector(logDeviceInfo) withObject:nil afterDelay:2.0];
    
    NSLog(@"[ScreenshotMonitor] Initialized with endpoint: %@", API_ENDPOINT);
}

%new
-(void)logDeviceInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [NSString stringWithFormat:@"API Endpoint: %@\nDevice ID: %@", API_ENDPOINT, DEVICE_ID];
        
        // Show alert with device info
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ScreenshotMonitor"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        
        // Keep alert visible for 5 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
        
        // Log to console
        NSLog(@"[ScreenshotMonitor] Device Info:\n%@", message);
    });
}

%end

// Required constructor
%ctor {
    NSLog(@"[ScreenshotMonitor] Tweak loaded");
} 