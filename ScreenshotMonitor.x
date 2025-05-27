#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>
#import <AudioToolbox/AudioToolbox.h>

// Configuration - Change these values
static NSString *API_ENDPOINT = @"http://186.190.215.38:3000/screenshots/log";
static NSString *DEVICE_ID = nil; // Will be set to device UDID
static NSMutableArray *actionLogs = nil; // Store recent action logs
static NSMutableArray *debugLogs = nil; // Store debug logs
static const NSInteger MAX_LOGS = 5; // Maximum number of action logs to keep
static const NSInteger MAX_DEBUG_LOGS = 10; // Maximum number of debug logs to keep
static NSTimer *updateTimer = nil; // Timer for periodic updates
static NSTimer *sendTimer = nil; // Timer for sending logs to API
static NSTimer *debugTimer = nil; // Timer for debug window updates

// Declare the new methods in SpringBoard interface
@interface SpringBoard (ScreenshotMonitor)
- (void)logDeviceInfo;
- (void)logAction:(NSString *)action;
- (void)logDebug:(NSString *)debug;
- (void)startPeriodicUpdates;
- (NSDictionary *)prepareActionsForSending;
- (void)sendActionsToServer;
- (void)showDebugWindow;
@end

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // Initialize logs arrays
    if (!actionLogs) {
        actionLogs = [NSMutableArray new];
    }
    if (!debugLogs) {
        debugLogs = [NSMutableArray new];
    }
    
    // Get device ID if not set
    if (!DEVICE_ID) {
        DEVICE_ID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        [self logDebug:@"Device ID initialized"];
    }
    
    // Log initial actions
    [self logAction:@"App Launched"];
    [self logAction:@"Device ID Initialized"];
    [self logDebug:@"Application finished launching"];
    
    // Start periodic updates
    [self startPeriodicUpdates];
    
    // Start debug window updates (every 10 seconds)
    debugTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                 target:self
                                               selector:@selector(showDebugWindow)
                                               userInfo:nil
                                                repeats:YES];
    
    // Start periodic sending to server (every 5 minutes)
    sendTimer = [NSTimer scheduledTimerWithTimeInterval:300.0
                                                target:self
                                              selector:@selector(sendActionsToServer)
                                              userInfo:nil
                                               repeats:YES];
    
    // Initial log display
    [self performSelector:@selector(logDeviceInfo) withObject:nil afterDelay:2.0];
    [self performSelector:@selector(showDebugWindow) withObject:nil afterDelay:3.0];
    
    NSLog(@"[ScreenshotMonitor] Initialized with endpoint: %@", API_ENDPOINT);
}

// Hook into app launch
-(void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended {
    %orig;
    [self logAction:[NSString stringWithFormat:@"App Launched: %@", identifier]];
    [self logDebug:[NSString stringWithFormat:@"launchApplicationWithIdentifier fired for %@. actionLogs: %@", identifier, actionLogs]];
}

// Hook into app termination
-(void)terminateApplicationWithIdentifier:(NSString *)identifier {
    %orig;
    [self logAction:[NSString stringWithFormat:@"App Terminated: %@", identifier]];
    [self logDebug:[NSString stringWithFormat:@"terminateApplicationWithIdentifier fired for %@. actionLogs: %@", identifier, actionLogs]];
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
-(void)logDebug:(NSString *)debug {
    // Create timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    // Create debug entry
    NSString *debugEntry = [NSString stringWithFormat:@"[%@] DEBUG: %@", timestamp, debug];
    
    // Add to debug logs array
    [debugLogs insertObject:debugEntry atIndex:0];
    
    // Keep only recent debug logs
    if (debugLogs.count > MAX_DEBUG_LOGS) {
        [debugLogs removeLastObject];
    }
    
    // Log to console
    NSLog(@"[ScreenshotMonitor] %@", debugEntry);
}

%new
-(void)showDebugWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Get current time
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *currentTime = [formatter stringFromDate:[NSDate date]];
        
        // Create debug message
        NSMutableString *message = [NSMutableString stringWithFormat:@"Debug Window - %@\n\n", currentTime];
        
        // Add system status
        [message appendFormat:@"System Status:\n"];
        [message appendFormat:@"Device ID: %@\n", DEVICE_ID];
        [message appendFormat:@"API Endpoint: %@\n\n", API_ENDPOINT];
        
        // Add recent actions
        [message appendFormat:@"Recent Actions:\n"];
        for (NSString *log in actionLogs) {
            [message appendFormat:@"%@\n", log];
        }
        
        // Add debug logs
        [message appendFormat:@"\nDebug Logs:\n"];
        for (NSString *log in debugLogs) {
            [message appendFormat:@"%@\n", log];
        }
        
        // Add JSON payload being sent
        NSDictionary *payload = [self prepareActionsForSending];
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&jsonError];
        NSString *jsonString = @"";
        if (!jsonError && jsonData) {
            jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        } else {
            jsonString = [NSString stringWithFormat:@"Error creating JSON: %@", jsonError.localizedDescription];
        }
        [message appendFormat:@"\n\nPayload to be sent:\n%@\n", jsonString];
        
        // Show debug alert
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ScreenshotMonitor Debug"
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
    });
}

%new
-(NSDictionary *)prepareActionsForSending {
    // Create a dictionary with device info and actions
    NSMutableDictionary *dataToSend = [NSMutableDictionary new];
    
    // Add device ID with correct key name
    [dataToSend setObject:DEVICE_ID forKey:@"deviceId"];
    
    // Add timestamp in ISO 8601 format
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    [dataToSend setObject:[formatter stringFromDate:[NSDate date]] forKey:@"timestamp"];
    
    // Combine all actions into a single message
    NSMutableString *combinedMessage = [NSMutableString new];
    for (NSString *log in actionLogs) {
        [combinedMessage appendFormat:@"%@\n", log];
    }
    [dataToSend setObject:combinedMessage forKey:@"message"];
    
    return dataToSend;
}

%new
-(void)sendActionsToServer {
    [self logDebug:@"Starting server communication"];
    
    NSDictionary *dataToSend = [self prepareActionsForSending];
    [self logDebug:@"Data prepared for sending"];
    
    // Convert to JSON
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dataToSend
                                                     options:0
                                                       error:&error];
    
    if (error) {
        [self logDebug:[NSString stringWithFormat:@"JSON conversion failed: %@", error.localizedDescription]];
        [self logAction:@"Failed to prepare data for sending"];
        return;
    }
    
    [self logDebug:@"JSON data prepared successfully"];
    
    // Use API endpoint as-is (deviceId is in the body)
    NSString *urlString = API_ENDPOINT;
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Create request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];
    
    [self logDebug:@"Request prepared, starting network call"];
    
    // Create and start the task
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self logDebug:[NSString stringWithFormat:@"Network error: %@", error.localizedDescription]];
            [self logAction:@"Failed to send data to server"];
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            [self logDebug:[NSString stringWithFormat:@"Server response: %ld", (long)httpResponse.statusCode]];
            [self logAction:@"Successfully sent data to server"];
        }
    }];
    
    [task resume];
    [self logDebug:@"Network task started"];
}

%new
-(void)startPeriodicUpdates {
    // Create timer that fires every 30 seconds
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