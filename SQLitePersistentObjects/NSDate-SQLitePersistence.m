//
//  NSDate-SQLitePersistence.m
// ----------------------------------------------------------------------
// Part of the SQLite Persistent Objects for Cocoa and Cocoa Touch
//
// Original Version: (c) 2008 Jeff LaMarche (jeff_Lamarche@mac.com)
// ----------------------------------------------------------------------
// This code may be used without restriction in any software, commercial,
// free, or otherwise. There are no attribution requirements, and no
// requirement that you distribute your changes, although bugfixes and 
// enhancements are welcome.
// 
// If you do choose to re-distribute the source code, you must retain the
// copyright notice and this license information. I also request that you
// place comments in to identify your changes.
//
// For information on how to use these classes, take a look at the 
// included Readme.txt file
// ----------------------------------------------------------------------
#import "NSDate-SQLitePersistence.h"


@implementation NSDate(SQLitePersistence)
+ (id)objectWithSqlColumnRepresentation:(NSString *)columnData;
{
#ifdef TARGET_OS_COCOTRON
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S.%F" allowNaturalLanguage:NO] autorelease];
	NSDate *d;
	BOOL cvt = [dateFormatter getObjectValue:&d forString:columnData errorDescription:nil];
	assert(cvt);
	return d;
#else
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSS"];
	return [dateFormatter dateFromString:columnData];
#endif
}
- (NSString *)sqlColumnRepresentationOfSelf
{
#ifdef TARGET_OS_COCOTRON
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S.%F" allowNaturalLanguage:NO] autorelease];
	return [dateFormatter stringForObjectValue:self];
#else
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	NSString *formattedDateString = [dateFormatter stringFromDate:self];
	[dateFormatter release];
	
	return formattedDateString;
#endif
}
+ (BOOL)canBeStoredInSQLite
{
	return YES;
}
+ (NSString *)columnTypeForObjectStorage
{
	return kSQLiteColumnTypeReal;
}
+ (BOOL)shouldBeStoredInBlob
{
	return NO;
}
@end
