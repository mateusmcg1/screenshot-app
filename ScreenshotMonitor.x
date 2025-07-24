#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

@interface SpringBoard (DebugPolling)
- (void)startDebugPolling;
- (void)sendDebugRequest;
@end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [self startDebugPolling];
}

- (void)startDebugPolling {
    [NSTimer scheduledTimerWithTimeInterval:10.0
                                     target:self
                                   selector:@selector(sendDebugRequest)
                                   userInfo:nil
                                    repeats:YES];
    // Also run immediately on launch
    [self sendDebugRequest];
}

- (void)sendDebugRequest {
    NSString *deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *urlString = [NSString stringWithFormat:@"http://186.190.215.38:3000/devices/device-command?device_id=%@", deviceID];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSLog(@"[RemoteControl] Device ID: %@", deviceID);
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *message;
        if (error) {
            message = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
            NSLog(@"[RemoteControl] Request error: %@", error.localizedDescription);
        } else if (data) {
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            message = [NSString stringWithFormat:@"Response: %@", result];
            NSLog(@"[RemoteControl] Response for device %@: %@", deviceID, result);
        } else {
            message = @"No data received.";
            NSLog(@"[RemoteControl] No data received for device %@", deviceID);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Debug" message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:ok];
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    }];
    [task resume];
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[RemoteControl] Debug tweak loaded into SpringBoard.");
    }
}