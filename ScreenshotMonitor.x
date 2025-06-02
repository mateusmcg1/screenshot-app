#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

// Configuration
static NSString *DEVICE_ID = nil;
static NSMutableArray *systemLogs = nil;

// Declare interfaces
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (SBApplication *)frontmostApplication;
@end

@interface SpringBoard (ScreenshotMonitor)
- (void)logSystemActivity;
- (NSString *)getCurrentApp;
@end

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // Initialize logs array
    if (!systemLogs) {
        systemLogs = [NSMutableArray new];
    }
    
    // Get device ID if not set
    if (!DEVICE_ID) {
        DEVICE_ID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    
    // Single timer for logging (every 30 seconds)
    [NSTimer scheduledTimerWithTimeInterval:30.0
                                   target:self
                                 selector:@selector(logSystemActivity)
                                 userInfo:nil
                                  repeats:YES];
    
    NSLog(@"[SystemMonitor] Initialized");
}

%new
-(NSString *)getCurrentApp {
    @try {
        SBApplicationController *appController = [%c(SBApplicationController) sharedInstance];
        if (!appController) return @"unknown";
        
        SBApplication *frontApp = [appController frontmostApplication];
        return frontApp ? [frontApp bundleIdentifier] : @"unknown";
    } @catch (NSException *exception) {
        return @"unknown";
    }
}

%new
-(void)logSystemActivity {
    @try {
        // Get current app
        NSString *currentApp = [self getCurrentApp];
        if ([currentApp isEqualToString:@"unknown"]) return;
        
        // Create timestamp
        NSString *timestamp = [[NSDate date] description];
        
        // Create log entry
        NSString *logEntry = [NSString stringWithFormat:@"%@|%@|%@", DEVICE_ID, timestamp, currentApp];
        
        // Log the entry
        NSLog(@"[SystemMonitor] %@", logEntry);
        
        // Add to logs array
        [systemLogs addObject:logEntry];
        
        // Keep only last 100 logs
        if (systemLogs.count > 100) {
            [systemLogs removeObjectAtIndex:0];
        }
    } @catch (NSException *exception) {
        NSLog(@"[SystemMonitor] Error logging: %@", exception);
    }
}

%end

// Required constructor
%ctor {
    @autoreleasepool {
        NSLog(@"[SystemMonitor] Tweak loaded");
    }
}