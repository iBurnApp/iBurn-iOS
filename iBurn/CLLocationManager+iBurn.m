//
//  CLLocationManager+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/5/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "CLLocationManager+iBurn.h"

@implementation CLLocationManager (iBurn)


+ (instancetype) brc_locationManager {
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager.activityType = CLActivityTypeFitness;
    locationManager.distanceFilter = 25;
    return locationManager;
}


@end
