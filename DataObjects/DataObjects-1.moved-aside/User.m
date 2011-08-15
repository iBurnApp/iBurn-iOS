//
//  User.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-17.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#include "User.h"

@implementation User

@synthesize username, name, emailAddress;

DECLARE_PROPERTIES(
				   DECLARE_PROPERTY(@"username", @"@\"NSString\""),
				   DECLARE_PROPERTY(@"name", @"@\"NSString\""),
				   DECLARE_PROPERTY(@"emailAddress", @"@\"NSString\"")			   
)

- (void)dealloc
{
	[username release];
	[name release];	
	[emailAddress release];	
	[super dealloc];
}

@end