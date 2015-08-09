//
//  BRCGeocoder.m
//  iBurn
//
//  Created by David Chiles on 8/5/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCGeocoder.h"
@import JavaScriptCore;

@interface BRCGeocoder()

@property (nonatomic, strong) JSContext *context;
@property (nonatomic, strong) dispatch_queue_t internalQueue;

@end

@implementation BRCGeocoder

- (instancetype)init{
    if (self = [super init]) {
        self.internalQueue = dispatch_queue_create("reverse geocoder", 0);
        __weak typeof(self)weakSelf = self;
        
        dispatch_async(self.internalQueue, ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            NSString *path = [[NSBundle mainBundle] pathForResource:@"bundle" ofType:@"js"];
            
            NSString *string = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            string = [NSString stringWithFormat:@"var window = this; %@",string];
            
            strongSelf.context = [[JSContext alloc] init];
            
            [strongSelf.context evaluateScript:string];
            [strongSelf.context evaluateScript:@"var reverseGeocoder = prepare()"];
        });
    }
    return self;
}

- (void)asyncReverseLookup:(CLLocationCoordinate2D)location completionQueue:(dispatch_queue_t)queue completion:(void (^)(NSString *))completion
{
    if (!completion) {
        return;
    }
    
    if (!queue) {
        queue = dispatch_get_main_queue();
    }
    
    dispatch_async(self.internalQueue, ^{
        NSString *result = [self executeReverseLookup:location];
        dispatch_async(queue, ^{
            completion(result);
        });
    });
}

/** only call from internalQueue! */
- (NSString*) executeReverseLookup:(CLLocationCoordinate2D)location {
    NSString *format = [NSString stringWithFormat:@"reverseGeocode(reverseGeocoder, %f, %f)", location.latitude, location.longitude];
    JSValue *result = [self.context evaluateScript:format];
    NSString *locationString = [result toString];
    return locationString;
}


/** Synchronously lookup location. WARNING: This may block for a long time! */
- (NSString*) reverseLookup:(CLLocationCoordinate2D)location {
    __block NSString *locationString = nil;
    dispatch_sync(self.internalQueue, ^{
        locationString = [self executeReverseLookup:location];
    });
    return locationString;
}

@end
