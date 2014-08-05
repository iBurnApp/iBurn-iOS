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
 *  Fetch an updated value for recentLocation (watch for KVO on recentLocation)
 */
- (void) updateRecentLocation;

+ (instancetype) sharedInstance;

@end
