//
//  ThemeCamp.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-17.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#include "ThemeCamp.h"

@implementation ThemeCamp

@synthesize name, year, description, url, contactEmail, hometown, location, circularStreet, timeAddress, latitude, longitude;

DECLARE_PROPERTIES(
	DECLARE_PROPERTY(@"name", @"@\"NSString\""),
	DECLARE_PROPERTY(@"year", @"@\"NSNumber\""),
	DECLARE_PROPERTY(@"description", @"@\"NSString\""),
	DECLARE_PROPERTY(@"url", @"@\"NSString\""),
	DECLARE_PROPERTY(@"contactEmail", @"@\"NSString\""),
	DECLARE_PROPERTY(@"hometown", @"@\"NSString\""),
	DECLARE_PROPERTY(@"location", @"@\"NSString\""),
	DECLARE_PROPERTY(@"circularStreet", @"@\"NSNumber\""),
	DECLARE_PROPERTY(@"timeAddress", @"@\"NSString\""),
	DECLARE_PROPERTY(@"latitude", @"@\"NSNumber\""),
	DECLARE_PROPERTY(@"longitude", @"@\"NSNumber\"")
)

- (void)dealloc
{
	[name release];
	[description release];
	[url release];
	[contactEmail release];	
	[hometown release];
	[location release];
	[timeAddress release];
	[super dealloc];
}

@end
