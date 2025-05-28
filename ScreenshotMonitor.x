#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

// Configuration
static NSString *API_ENDPOINT = @"http://186.190.215.38:3000/screenshots/log";
static NSString *DEVICE_ID = nil;
static NSMutableArray *systemLogs = nil;
static UIWindow *debugWindow = nil;
static UITextView *debugTextView = nil;

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
- (void)updateDebugWindow:(NSString *)message;
- (void)setupDebugWindow;
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
    
    // Setup debug window with delay to ensure SpringBoard is ready
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setupDebugWindow];
    });
    
    // Single timer for both logging and sending (every 30 seconds)
    [NSTimer scheduledTimerWithTimeInterval:30.0
                                   target:self
                                 selector:@selector(logSystemActivity)
                                 userInfo:nil
                                  repeats:YES];
    
    NSLog(@"[SystemMonitor] Initialized with endpoint: %@", API_ENDPOINT);
}

%new
-(void)setupDebugWindow {
    if (debugWindow) return;
    
    debugWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
    debugWindow.windowLevel = UIWindowLevelStatusBar + 1000; // Much higher level
    debugWindow.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    debugWindow.layer.cornerRadius = 10;
    debugWindow.hidden = NO;
    debugWindow.userInteractionEnabled = NO;
    
    debugTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, 280, 180)];
    debugTextView.backgroundColor = [UIColor clearColor];
    debugTextView.textColor = [UIColor whiteColor];
    debugTextView.font = [UIFont systemFontOfSize:12];
    debugTextView.editable = NO;
    debugTextView.selectable = NO;
    
    [debugWindow addSubview:debugTextView];
    
    // Force window to be visible
    [debugWindow makeKeyAndVisible];
    [[UIApplication sharedApplication].keyWindow makeKeyWindow];
    
    [self updateDebugWindow:@"Debug window initialized"];
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
-(void)updateDebugWindow:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!debugTextView) {
            [self setupDebugWindow];
            return;
        }
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        
        NSString *newMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        debugTextView.text = [newMessage stringByAppendingString:debugTextView.text];
        
        // Keep only last 10 messages
        NSArray *lines = [debugTextView.text componentsSeparatedByString:@"\n"];
        if (lines.count > 10) {
            NSArray *recentLines = [lines subarrayWithRange:NSMakeRange(0, 10)];
            debugTextView.text = [recentLines componentsJoinedByString:@"\n"];
        }
        
        // Ensure window is visible
        if (debugWindow.hidden) {
            debugWindow.hidden = NO;
            [debugWindow makeKeyAndVisible];
            [[UIApplication sharedApplication].keyWindow makeKeyWindow];
        }
    });
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
        
        // Update debug window
        [self updateDebugWindow:[NSString stringWithFormat:@"App logged: %@", currentApp]];
        
        // Send logs if we have any
        [self sendLogsToServer];
    } @catch (NSException *exception) {
        [self updateDebugWindow:[NSString stringWithFormat:@"Error logging: %@", exception]];
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
        
        // Update debug window
        [self updateDebugWindow:@"Sending logs to server..."];
        
        // Send request
        [[[NSURLSession sharedSession] dataTaskWithRequest:request 
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && [(NSHTTPURLResponse *)response statusCode] == 200) {
                [systemLogs removeAllObjects];
                [self updateDebugWindow:@"Logs sent successfully"];
            } else {
                [self updateDebugWindow:[NSString stringWithFormat:@"Failed to send logs: %@", error ? error.localizedDescription : @"Unknown error"]];
            }
        }] resume];
    } @catch (NSException *exception) {
        [self updateDebugWindow:[NSString stringWithFormat:@"Error sending logs: %@", exception]];
    }
}

%end

// Required constructor
%ctor {
    @autoreleasepool {
        NSLog(@"[SystemMonitor] Tweak loaded");
    }
}