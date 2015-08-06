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

- (void)reverseLookup:(CLLocationCoordinate2D)location completionQueue:(dispatch_queue_t)queue completion:(void (^)(NSString *locationString))completion;

@end
