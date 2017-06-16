//
//  BRCGeocoder.m
//  iBurn
//
//  Created by David Chiles on 8/5/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCGeocoder.h"
@import BButton;
@import JavaScriptCore;

@interface BRCGeocoder()

@property (nonatomic, strong) JSContext *context;
@property (nonatomic, strong) dispatch_queue_t internalQueue;

@end

@implementation BRCGeocoder

+ (BRCGeocoder*) shared {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

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

- (void)asyncReverseLookup:(CLLocationCoordinate2D)coordinate completionQueue:(dispatch_queue_t)queue completion:(void (^)(NSString * _Nullable))completion
{
    NSParameterAssert(CLLocationCoordinate2DIsValid(coordinate));
    if (!completion) {
        return;
    }
    if (!queue) {
        queue = dispatch_get_main_queue();
    }
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        completion(nil);
        return;
    }
    dispatch_async(self.internalQueue, ^{
        NSString *result = [self executeReverseLookup:coordinate];
        dispatch_async(queue, ^{
            completion(result);
        });
    });
}

/** only call from internalQueue! */
- (nullable NSString*) executeReverseLookup:(CLLocationCoordinate2D)coordinate {
    NSParameterAssert(CLLocationCoordinate2DIsValid(coordinate));
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return nil;
    }
    NSString *format = [NSString stringWithFormat:@"reverseGeocode(reverseGeocoder, %f, %f)", coordinate.latitude, coordinate.longitude];
    JSValue *result = [self.context evaluateScript:format];
    NSString *locationString = [result toString];
    return locationString;
}

/** Synchronously lookup location. WARNING: This may block for a long time! */
- (nullable NSString*) reverseLookup:(CLLocationCoordinate2D)location {
    __block NSString *locationString = nil;
    dispatch_sync(self.internalQueue, ^{
        locationString = [self executeReverseLookup:location];
    });
    return locationString;
}

@end

@implementation NSString (BRCGeocoder)
/** Add font-awesome crosshairs */
- (NSAttributedString*) brc_attributedLocationStringWithCrosshairs {
    NSString *locationString = self;
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
    NSAttributedString *crosshairs = [[NSAttributedString alloc] initWithString:[NSString fa_stringForFontAwesomeIcon:FACrosshairs] attributes:@{NSFontAttributeName: [UIFont fontWithName:kFontAwesomeFont size:17]}];
    [string appendAttributedString:crosshairs];
    [string appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    NSAttributedString *location = [[NSAttributedString alloc] initWithString:locationString attributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]}];
    [string appendAttributedString:location];
    return string;
}
@end

