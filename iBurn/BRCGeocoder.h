//
//  BRCGeocoder.h
//  iBurn
//
//  Created by David Chiles on 8/5/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (BRCGeocoder)
/** Add font-awesome crosshairs */
@property (nonatomic, readonly) NSAttributedString *brc_attributedLocationStringWithCrosshairs;
@end

@interface BRCGeocoder : NSObject

/** Async lookup location */
- (void)asyncReverseLookup:(CLLocationCoordinate2D)coordinate completionQueue:(nullable dispatch_queue_t)queue completion:(void (^)(NSString * _Nullable locationString))completion;

/** Synchronously lookup location. WARNING: This may block for a long time! */
- (nullable NSString*) reverseLookup:(CLLocationCoordinate2D)location;

@property (nonatomic, class, readonly) BRCGeocoder *shared;

@end
NS_ASSUME_NONNULL_END
