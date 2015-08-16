//
//  BRCLocations.m
//  iBurn
//
//  Created by David Chiles on 8/4/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCLocations.h"

// TODO: don't hardcode this, load from JSON
#warning Hardcoded 2015 Man coordinates
static double const blackRockCityCenterLongitude = -119.2065;
static double const blackRockCityCenterLatitude = 40.7864;

static NSString * const kBRCManRegionIdentifier = @"kBRCManRegionIdentifier";

@implementation BRCLocations

+ (CLLocationCoordinate2D)blackRockCityCenter
{
    return CLLocationCoordinate2DMake(blackRockCityCenterLatitude, blackRockCityCenterLongitude);
}

/** Within 5 miles of the man */
+ (CLCircularRegion*) burningManRegion {
    CLLocationCoordinate2D manCoordinate = [BRCLocations blackRockCityCenter];
    CLLocationDistance radius = 5 * 8046.72; // Within 5 miles of the man
    CLCircularRegion *burningManRegion = [[CLCircularRegion alloc] initWithCenter:manCoordinate radius:radius identifier:kBRCManRegionIdentifier];
    return burningManRegion;
}

@end
