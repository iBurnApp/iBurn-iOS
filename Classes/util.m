//
//  util.m
//  iBurn
//
//  Created by Anna Hentzel on 8/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "util.h"


@implementation util

RMTile RMTileFromKey(uint64_t tilekey)
{
	RMTile t;
	t.zoom = tilekey >> 56;
	t.x = tilekey >> 28 & 0xFFFFFFFLL;
	t.y = tilekey & 0xFFFFFFFLL;
	return t;
}


+ (NSString*) formatDecimal_0:(float)num {
	static NSNumberFormatter *numFormatter;
	if (!numFormatter) {
		numFormatter = [[[NSNumberFormatter alloc] init] retain];
		[numFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numFormatter setLocale:[NSLocale currentLocale]];
		[numFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
		[numFormatter setMaximumFractionDigits:0];
		[numFormatter setMinimumFractionDigits:0];
	}
	return [numFormatter stringFromNumber:F(num)];
}


+ (NSString*) formatDecimal_1:(float)num {
	static NSNumberFormatter *numFormatter;
	if (!numFormatter) {
		numFormatter = [[[NSNumberFormatter alloc] init] retain];
		[numFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numFormatter setLocale:[NSLocale currentLocale]];
		[numFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
		[numFormatter setMaximumFractionDigits:1];
		[numFormatter setMinimumFractionDigits:1];
	}
	return [numFormatter stringFromNumber:F(num)];
}

+ (NSString*) formatDecimal_2:(double)num {
	static NSNumberFormatter *numFormatter;
	if (!numFormatter) {
		numFormatter = [[[NSNumberFormatter alloc] init] retain];
		[numFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numFormatter setLocale:[NSLocale currentLocale]];
		[numFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
		[numFormatter setMaximumFractionDigits:2];
		[numFormatter setMinimumFractionDigits:2];
	}
	return [numFormatter stringFromNumber:F(num)];
}


+ (float) getDistanceFloat:(float)distance convertMax:(int)convertMax {
  if (distance == 0) return 0;
  
  BOOL useMetric = NO;

  if (useMetric) {
		if (convertMax != -1 && distance > convertMax) {
      return distance / 1000;
		}
    return distance;
  } else if (!useMetric) {
    if (convertMax != -1 && distance > convertMax) {
      
      distance = distance / 5280;
      return metersToFeet(distance);
    
    }
    return metersToFeet(distance);
  }
	return distance;
}


// Returns a formatted string represented the distance in the correct units.
// If distance is greater than convert max in feet or meters, the distance in miles or km is returned
+ (NSString*) distanceString:(float)distance 
                 convertMax:(int)convertMax 
                includeUnit:(BOOL)includeUnit 
              decimalPlaces:(int)decimalPlaces {
  NSString* unitName = @"m";
  
  BOOL useMetric = NO;
  if (useMetric) {
		if (convertMax != -1 && distance > convertMax) {
    
      unitName = @"km";
		}
  } else if (!useMetric) {
    if (convertMax != -1 && distance > convertMax) {
      unitName = @"mi";
    } else {
      unitName = @"ft";
    }
  } 
	
  float displayDistance = [util getDistanceFloat:distance convertMax:convertMax];
  if (decimalPlaces == 0) {
    displayDistance = floor(displayDistance);
  }
  
  NSString* formattedDecimal;
  if (distance < convertMax || decimalPlaces == 0) {
    formattedDecimal = [util formatDecimal_0:displayDistance];
  } else if (decimalPlaces == 1) {
    formattedDecimal = [util formatDecimal_1:displayDistance];
  } else {
    formattedDecimal = [util formatDecimal_2:displayDistance];
  }
  if (includeUnit) return [NSString stringWithFormat:@"%@ %@", formattedDecimal, unitName];
	return formattedDecimal;
}


@end
