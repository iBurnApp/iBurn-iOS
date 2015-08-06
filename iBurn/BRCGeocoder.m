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
@property (nonatomic, strong) NSOperationQueue *jsQueue;

@end

@implementation BRCGeocoder

- (instancetype)init{
    if (self = [super init]) {
        self.jsQueue = [[NSOperationQueue alloc] init];
        self.jsQueue.maxConcurrentOperationCount = 1;
        __weak typeof(self)weakSelf = self;
        
        [self.jsQueue addOperationWithBlock:^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf.jsQueue setSuspended:YES];
            NSString *path = [[NSBundle mainBundle] pathForResource:@"bundle" ofType:@"js"];
            
            NSString *string = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            
            string = [NSString stringWithFormat:@"var window = this; %@",string];
            
            strongSelf.context = [[JSContext alloc] init];
            
            [strongSelf.context evaluateScript:string];
            
            __weak typeof(self)weakSelf1 = strongSelf;
            strongSelf.context[@"OBJCallback"] = ^(JSValue *coder) {
                __strong typeof(weakSelf)strongSelf1 = weakSelf1;
                strongSelf1.context[@"reverseGeocoder"] = coder;
                [strongSelf1.jsQueue setSuspended:NO];
            };
            
            [strongSelf.context evaluateScript:@"prepare(OBJCallback)"];
        }];
    }
    return self;
}

- (void)reverseLookup:(CLLocationCoordinate2D)location completionQueue:(dispatch_queue_t)queue completion:(void (^)(NSString *))completion
{
    if (!completion) {
        return;
    }
    
    if (!queue) {
        queue = dispatch_get_main_queue();
    }
    
    [self.jsQueue addOperationWithBlock:^{
        NSString *format = [NSString stringWithFormat:@"reverseGeocode(reverseGeocoder, %f, %f)", location.latitude, location.longitude];
        JSValue *result = [self.context evaluateScript:format];
        NSString *string = [result toString];
        dispatch_async(queue, ^{
            completion(string);
        });
    }];
}

@end
