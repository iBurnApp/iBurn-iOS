//
//  BRCLocations.m
//  iBurn
//
//  Created by David Chiles on 8/4/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCLocations.h"

// TODO: don't hardcode this, load from JSON
static double const blackRockCityCenterLongitude = -119.2065;
static double const blackRockCityCenterLatitude = 40.7864;

@implementation BRCLocations

+ (CLLocationCoordinate2D)blackRockCityCenter
{
    return CLLocationCoordinate2DMake(blackRockCityCenterLatitude, blackRockCityCenterLongitude);
}

@end
