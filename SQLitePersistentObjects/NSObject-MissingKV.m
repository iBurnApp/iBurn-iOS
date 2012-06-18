//
//  NSObject-MissingKV.m
//  iContractor
//
//  Created by Jeff LaMarche on 2/18/09.
//  Copyright 2009 Jeff LaMarche Consulting. All rights reserved.
//

#import "NSObject-MissingKV.h"

#ifdef TARGET_OS_IPHONE
@implementation NSObject(MissingKV)
- (void)takeValuesFromDictionary:(NSDictionary *)properties
{
	for (id oneKey in [properties allKeys])
	{
		id oneObject = [properties objectForKey:oneKey];
		[self setValue:oneObject forKey:oneKey];
	}
}
- (void)takeValue:(id)value forKey:(NSString *)key
{
	[self setValue:value forKey:key];
}
@end
#endif