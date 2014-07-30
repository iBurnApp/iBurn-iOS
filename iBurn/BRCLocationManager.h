//
//  BRCLocationManager.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "YapDatabaseConnection.h"

@interface BRCLocationManager : NSObject <CLLocationManagerDelegate>

@property (nonatomic, strong, readonly) CLLocation *recentLocation;

/**
 *  Updates the "distanceFromUser" property on every BRCDataObject
 *  subclass that you specify.
 *
 *  @param objectClass     subclass of BRCDataObject
 *  @param location        most recent location
 *  @param completionBlock always called on main thread
 */
- (void) updateDistanceForAllObjectsOfClass:(Class)objectClass
                               fromLocation:(CLLocation*)location
                            completionBlock:(dispatch_block_t)completionBlock;

/**
 *  Fetch an updated value for recentLocation (watch for KVO on recentLocation)
 */
- (void) updateRecentLocation;

+ (instancetype) sharedInstance;

@end
