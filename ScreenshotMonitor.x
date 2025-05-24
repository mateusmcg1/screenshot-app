#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#import <AudioToolbox/AudioToolbox.h>

// Configuration - Change these values
static NSString *API_ENDPOINT = @"http://186.190.215.38:3000/screenshots/device/";
static NSString *DEVICE_ID = nil; // Will be set to device UDID
static NSMutableArray *actionLogs = nil; // Store recent action logs
static const NSInteger MAX_LOGS = 5; // Maximum number of logs to keep
static NSTimer *updateTimer = nil; // Timer for periodic updates

// Declare the new methods in SpringBoard interface
@interface SpringBoard (ScreenshotMonitor)
- (void)logDeviceInfo;
- (void)logAction:(NSString *)action;
- (void)startPeriodicUpdates;
@end

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // Initialize action logs array
    if (!actionLogs) {
        actionLogs = [NSMutableArray new];
    }
    
    // Get device ID if not set
    if (!DEVICE_ID) {
        DEVICE_ID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    
    // Log initial actions
    [self logAction:@"App Launched"];
    [self logAction:@"Device ID Initialized"];
    
    // Start periodic updates
    [self startPeriodicUpdates];
    
    // Initial log display
    [self performSelector:@selector(logDeviceInfo) withObject:nil afterDelay:2.0];
    
    NSLog(@"[ScreenshotMonitor] Initialized with endpoint: %@", API_ENDPOINT);
}

// Hook into app launch
-(void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended {
    %orig;
    [self logAction:[NSString stringWithFormat:@"App Launched: %@", identifier]];
}

// Hook into app termination
-(void)terminateApplicationWithIdentifier:(NSString *)identifier {
    %orig;
    [self logAction:[NSString stringWithFormat:@"App Terminated: %@", identifier]];
}

// Hook into screen lock
-(void)lockScreen {
    %orig;
    [self logAction:@"Screen Locked"];
}

// Hook into screen unlock
-(void)unlockScreen {
    %orig;
    [self logAction:@"Screen Unlocked"];
}

%new
-(void)startPeriodicUpdates {
    // Create timer that fires every minute
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                  target:self
                                                selector:@selector(logDeviceInfo)
                                                userInfo:nil
                                                 repeats:YES];
    [self logAction:@"Periodic Updates Started"];
}

%new
-(void)logAction:(NSString *)action {
    // Create timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // Create log entry
    NSString *logEntry = [NSString stringWithFormat:@"[%@] %@", timestamp, action];
    
    // Add to logs array
    [actionLogs insertObject:logEntry atIndex:0];
    
    // Keep only recent logs
    if (actionLogs.count > MAX_LOGS) {
        [actionLogs removeLastObject];
    }
    
    // Log to console
    NSLog(@"[ScreenshotMonitor] %@", logEntry);
}

%new
-(void)logDeviceInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Get current time
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *currentTime = [formatter stringFromDate:[NSDate date]];
        
        // Create message with device info and action logs
        NSMutableString *message = [NSMutableString stringWithFormat:@"API Endpoint: %@\nDevice ID: %@\nLast Update: %@\n\nRecent Actions:", 
            API_ENDPOINT, 
            DEVICE_ID,
            currentTime];
        
        // Add action logs to message
        for (NSString *log in actionLogs) {
            [message appendFormat:@"\n%@", log];
        }
        
        // Show alert with device info and logs
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ScreenshotMonitor"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        // Add OK button
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
        [alert addAction:okAction];
        
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        
        // Keep alert visible for 5 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
        
        // Log the update
        [self logAction:@"Periodic Update"];
    });
}

%end

// Required constructor
%ctor {
    NSLog(@"[ScreenshotMonitor] Tweak loaded");
} 