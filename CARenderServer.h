
#ifndef CARENDERSERVER_H
#define CARENDERSERVER_H

#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

int CARenderServerRenderDisplay(uintptr_t server, CFStringRef display, CGContextRef context, CGRect bounds, int flags);

#ifdef __cplusplus
}
#endif

#endif /* CARENDERSERVER_H */
