//
//  BRCGeocoder.h
//  iBurn
//
//  Created by David Chiles on 8/5/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface BRCGeocoder : NSObject

/** Async lookup location */
- (void)asyncReverseLookup:(CLLocationCoordinate2D)location completionQueue:(dispatch_queue_t)queue completion:(void (^)(NSString *locationString))completion;

/** Synchronously lookup location. WARNING: This may block for a long time! */
- (NSString*) reverseLookup:(CLLocationCoordinate2D)location;

+ (instancetype) sharedInstance;

/** Add font-awesome crosshairs */
+ (NSAttributedString*) locationStringWithCrosshairs:(NSString*)locationString;

@end
