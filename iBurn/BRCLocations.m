//
//  BRCLocations.m
//  iBurn
//
//  Created by David Chiles on 8/4/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCLocations.h"

static double const blackRockCityCenterLongitude = -119.20315;
static double const blackRockCityCenterLatitude = 40.78880;

@implementation BRCLocations

+ (CLLocationCoordinate2D)blackRockCityCenter
{
    return CLLocationCoordinate2DMake(blackRockCityCenterLatitude, blackRockCityCenterLongitude);
}

@end
