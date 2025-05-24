#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#import <AudioToolbox/AudioToolbox.h>
#import "CARenderServer.h"
#import <CoreGraphics/CoreGraphics.h>

// Configuration - Change these values
static NSString *API_ENDPOINT = @"https://186.190.215.38:3000/screenshots/device/";
static NSInteger SCREENSHOT_INTERVAL = 60; // 1 minute in seconds
static NSString *DEVICE_ID = nil; // Will be set to device UDID

// Declare the new methods in SpringBoard interface
@interface SpringBoard (ScreenshotMonitor)
- (void)captureAndUploadScreenshot;
- (UIImage *)takeScreenshot;
- (void)uploadScreenshot:(UIImage *)screenshot;
@end

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // Get device ID if not set
    if (!DEVICE_ID) {
        DEVICE_ID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    
    // Schedule periodic screenshots
    [NSTimer scheduledTimerWithTimeInterval:SCREENSHOT_INTERVAL
                                     target:self
                                   selector:@selector(captureAndUploadScreenshot)
                                   userInfo:nil
                                    repeats:YES];
    
    // Take initial screenshot
    [self performSelector:@selector(captureAndUploadScreenshot) withObject:nil afterDelay:10.0];
    
    NSLog(@"[ScreenshotMonitor] Initialized with endpoint: %@", API_ENDPOINT);
}

%new
-(void)captureAndUploadScreenshot {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            UIImage *screenshot = [self takeScreenshot];
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            NSLog(@"[ScreenshotMonitor] Screenshot (dummy)!");
            // Show a visual alert
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ScreenshotMonitor"
                                                                           message:@"Timer fired!"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [alert dismissViewControllerAnimated:YES completion:nil];
            });
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];

            // Test upload with dummy image
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [self uploadScreenshot:screenshot];
            });
        }
    });
}

%new
-(UIImage *)takeScreenshot {
    CGSize size = CGSizeMake(100, 100);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

%new
-(void)uploadScreenshot:(UIImage *)screenshot {
    // Convert image to JPEG data
    NSData *imageData = UIImageJPEGRepresentation(screenshot, 0.8);
    if (!imageData) {
        NSLog(@"[ScreenshotMonitor] Failed to convert screenshot to JPEG");
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ScreenshotMonitor"
                                                                           message:@"Failed to convert screenshot"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [alert dismissViewControllerAnimated:YES completion:nil];
            });
        });
        return;
    }

    // Build the URL with device ID in the path
    NSString *urlString = [NSString stringWithFormat:@"%@%@", API_ENDPOINT, DEVICE_ID];
    
    // Show alert with API info instead of making the request
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [NSString stringWithFormat:@"Would upload to:\n%@\n\nDevice ID: %@", urlString, DEVICE_ID];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ScreenshotMonitor"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    });
    
    NSLog(@"[ScreenshotMonitor] Would upload to: %@", urlString);
}

%end

// Required constructor
%ctor {
    NSLog(@"[ScreenshotMonitor] Tweak loaded");
} 