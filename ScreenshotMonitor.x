#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

// MARK: - Interfaces

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (void)terminate;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)frontmostApplication;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (void)lockUIFromSource:(int)source;
@end

@interface SpringBoard (RemoteControl)
- (void)startRemoteMonitoring;
- (void)checkRemoteCommand;
- (void)triggerDeviceBlock;
@end

static UIWindow *blockWindow = nil;

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    // Start polling the API
    [self startRemoteMonitoring];
    NSLog(@"[RemoteControl] Tweak initialized.");
}

%new
- (void)startRemoteMonitoring {
    // Poll every 15 seconds
    [NSTimer scheduledTimerWithTimeInterval:15.0
                                     target:self
                                   selector:@selector(checkRemoteCommand)
                                   userInfo:nil
                                    repeats:YES];
}

%new
- (void)checkRemoteCommand {
    @try {
        NSString *deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        NSString *urlString = [NSString stringWithFormat:@"http://186.190.215.38:3000/devices/device-command?device_id=%@", deviceID];
        NSURL *url = [NSURL URLWithString:urlString];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];

        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && data) {
                NSString *command = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                // Trim whitespace and newlines
                command = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                if ([command isEqualToString:@"lock"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self triggerDeviceBlock];
                    });
                }
            }
        }];
        [task resume];
    } @catch (NSException *e) {
        NSLog(@"[RemoteControl] Error checking command: %@", e);
    }
}

%new
- (void)triggerDeviceBlock {
    NSLog(@"[RemoteControl] Triggering device block...");

    // 1. Lock the screen
    SBLockScreenManager *manager = [%c(SBLockScreenManager) sharedInstance];
    if (manager) {
        [manager lockUIFromSource:0];
    }

    // 2. Kill frontmost app
    SBApplication *frontApp = [[%c(SBApplicationController) sharedInstance] frontmostApplication];
    if (frontApp) {
        NSLog(@"[RemoteControl] Killing app: %@", [frontApp bundleIdentifier]);
        [frontApp terminate];
    }

    // 3. Show blocking UI
    if (!blockWindow) {
        blockWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        blockWindow.windowLevel = UIWindowLevelAlert + 1;

        UIView *blockView = [[UIView alloc] initWithFrame:blockWindow.frame];
        blockView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, blockWindow.frame.size.width, 100)];
        label.center = blockWindow.center;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        label.text = @"DEVICE LOCKED";
        label.font = [UIFont boldSystemFontOfSize:28];
        [blockView addSubview:label];

        blockView.userInteractionEnabled = YES;
        blockWindow.userInteractionEnabled = YES;

        [blockWindow addSubview:blockView];
        [blockWindow makeKeyAndVisible];
    }
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[RemoteControl] Tweak loaded into SpringBoard.");
    }
}