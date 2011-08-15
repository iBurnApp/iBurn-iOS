//
//  ArtInstall.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-17.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#include "ArtInstall.h"

@implementation ArtInstall

@synthesize year, name, slug, artist, description, url, contactEmail, circularStreet, timeAddress, latitude, longitude;

DECLARE_PROPERTIES(
	DECLARE_PROPERTY(@"year", @"@\"NSNumber\""),
	DECLARE_PROPERTY(@"name", @"@\"NSString\""),
	DECLARE_PROPERTY(@"slug", @"@\"NSString\""),
	DECLARE_PROPERTY(@"artist", @"@\"NSString\""),
	DECLARE_PROPERTY(@"description", @"@\"NSString\""),
	DECLARE_PROPERTY(@"url", @"@\"NSString\""),
	DECLARE_PROPERTY(@"contactEmail", @"@\"NSString\""),
	DECLARE_PROPERTY(@"circularStreet", @"@\"NSNumber\""),
	DECLARE_PROPERTY(@"timeAddress", @"@\"NSString\""),
	DECLARE_PROPERTY(@"latitude", @"@\"NSNumber\""),
	DECLARE_PROPERTY(@"longitude", @"@\"NSNumber\"")
)

- (void)dealloc
{	
	[name release];
	[slug release];
	[artist release];
	[description release];
	[url release];
	[contactEmail release];	
	[timeAddress release];
	[super dealloc];
}

@end
