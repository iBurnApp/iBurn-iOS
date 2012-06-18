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

#import "SQLitePersistentObject.h"
#import "SQLiteInstanceManager.h"
#import "NSString-SQLiteColumnName.h"
#import "NSObject-SQLitePersistence.h"
#import "NSString-UppercaseFirst.h"
#import "NSString-NumberStuff.h"
#import "NSObject-ClassName.h"
#import "NSObject-MissingKV.h"
#ifdef TARGET_OS_COCOTRON
#import <objc/objc-class.h>
#endif

static id aggregateMethodWithCriteriaImp(id self, SEL _cmd, id value)
{
	NSString *methodBeingCalled = [NSString stringWithUTF8String:sel_getName(_cmd)];
	NSRange rangeOfOf = [methodBeingCalled rangeOfString:@"Of"];
	NSString *operation = [methodBeingCalled substringToIndex:rangeOfOf.location];
			
	if ([operation isEqualToString:@"average"])
		operation = @"avg";
	
	
	NSRange criteriaRange = [methodBeingCalled rangeOfString:@"WithCriteria"];
	NSString *property = nil;
	if (criteriaRange.location == NSNotFound)
	{
		NSRange theRange = NSMakeRange(rangeOfOf.location + rangeOfOf.length, [methodBeingCalled length] - (rangeOfOf.location + rangeOfOf.length));
		property = [[methodBeingCalled substringWithRange:theRange] stringByLowercasingFirstLetter];
	}
	else
	{
		// sumOfamountWithCriteria
		NSRange propRange = NSMakeRange(rangeOfOf.location + rangeOfOf.length, [methodBeingCalled length] - (rangeOfOf.location + rangeOfOf.length) - criteriaRange.length - 1);
		property = [methodBeingCalled substringWithRange:propRange];
	}
	
	
	NSString *query = [NSString stringWithFormat:@"select %@(%@) from %@ %@",operation, [property stringAsSQLColumnName], [self tableName], value];
	double avg = [self performSQLAggregation:query];
	return [NSNumber numberWithDouble:avg];
}
static id aggregateMethodImp(id self, SEL _cmd, id value)
{
	return aggregateMethodWithCriteriaImp(self, _cmd, @"");
}
static id findByMethodImp(id self, SEL _cmd, id value)
{
	NSString *methodBeingCalled = [NSString stringWithUTF8String:sel_getName(_cmd)];
	
	NSRange theRange = NSMakeRange(6, [methodBeingCalled length] - 7);
	NSString *property = [[methodBeingCalled substringWithRange:theRange] stringByLowercasingFirstLetter];
	NSMutableString *queryCondition = [NSMutableString stringWithFormat:@"WHERE %@ like ", [property stringAsSQLColumnName]];
	if (![value isKindOfClass:[NSNumber class]])
		[queryCondition appendString:@"'"];
	
	if ([value conformsToProtocol:@protocol(SQLitePersistence)])
	{
		if ([[value class] shouldBeStoredInBlob])
		{
			NSLog(@"*** Can't search on BLOB fields");
			return nil;
		}
		else
			[queryCondition appendString:[value sqlColumnRepresentationOfSelf]];
	}
	else
	{
		[queryCondition appendString:[value stringValue]];
	}
	
	if (![value isKindOfClass:[NSNumber class]])	
		[queryCondition appendString:@"'"];	
	
	return [self findByCriteria:queryCondition];
}



@interface SQLitePersistentObject (private)
+ (void)tableCheck;
- (void)setPk:(int)newPk;
+ (NSString *)classNameForTableName:(NSString *)theTable;
//+ (void)setUpDynamicMethods;
- (void)makeClean;
- (void)markDirty;
- (BOOL)isDirty;
@end
@interface SQLitePersistentObject (private_memory)
+ (NSString *)memoryMapKeyForObject:(NSInteger)thePK;
+ (void)registerObjectInMemory:(SQLitePersistentObject *)theObject;
+ (void)unregisterObject:(SQLitePersistentObject *)theObject;
- (NSString *)memoryMapKey;
@end

NSMutableDictionary *objectMap;
NSMutableArray *checkedTables;

@implementation SQLitePersistentObject

#pragma mark -
#pragma mark Public Class Methods
+ (double)performSQLAggregation: (NSString *)query, ...
{
	double ret = -1.0;
	sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
	
	// Added variadic ability to all criteria accepting methods -SLyons (10/03/2009)
	va_list argumentList;
	va_start(argumentList, query);
	NSString *queryString = [[NSString alloc] initWithFormat:query arguments:argumentList];
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2( database,  [queryString UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		if (sqlite3_step(stmt) == SQLITE_ROW)
			ret = sqlite3_column_double(stmt, 0);
		sqlite3_finalize(stmt);
	}
	[queryString release];
	return ret;
}

+ (void)clearCache
{
	if(objectMap != nil)
		[objectMap removeAllObjects];
	
	if(checkedTables != nil)
		[checkedTables removeAllObjects];
	
}

+(NSArray *)indices
{
	return nil;
}

+(NSArray *)transients
{
	return [NSMutableArray array];
}

+(SQLitePersistentObject *)findFirstByCriteria:(NSString *)criteriaString, ...
{
	// Added variadic ability to all criteria accepting methods -SLyons (10/03/2009)
	va_list argumentList;
	va_start(argumentList, criteriaString);
	NSString *queryString = [[NSString alloc] initWithFormat:criteriaString arguments:argumentList];
	NSArray *array = [self findByCriteria:queryString];
	[queryString release];
	
	if (array != nil)
		if ([array count] > 0)
			return [array objectAtIndex:0];
	return  nil;
}
+ (NSInteger)count
{
    return [self countByCriteria:@""];
}
+ (NSInteger)countByCriteria:(NSString *)criteriaString, ...
{
	[self tableCheck];
	NSInteger countOfRecords;
	countOfRecords = 0;
	NSString *countQuery;
	
	// Added variadic ability to all criteria accepting methods -SLyons (10/03/2009)
	va_list argumentList;
	va_start(argumentList, criteriaString);
	NSString *queryString = [[NSString alloc] initWithFormat:criteriaString arguments:argumentList];
	
	countQuery = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ %@", [self tableName], queryString];
	[queryString release];
	sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
	sqlite3_stmt *statement;
	if (sqlite3_prepare_v2(database, [countQuery UTF8String], -1, &statement, nil) == SQLITE_OK) 
	{
		if (sqlite3_step(statement) == SQLITE_ROW)
			countOfRecords = sqlite3_column_int(statement, 0);
	} 
	else NSLog(@"Error determining count of rows in table %@", [self  tableName]);
	
	sqlite3_finalize(statement);
	return countOfRecords;
}
+(NSArray *)allObjects
{
	return [[self class] findByCriteria:@""];
}
+(void)deleteObject:(NSInteger)inPk cascade:(BOOL)cascade
{
	if(inPk < 0)
		return;

	SQLitePersistentObject* objToDelete = [self findByPK:inPk];
	if(objToDelete == nil)
		return;
	
	[objToDelete deleteObjectCascade:cascade];
	
}
+(SQLitePersistentObject *)findByPK:(int)inPk
{
	return [self findFirstByCriteria:[NSString stringWithFormat:@"WHERE pk = %d", inPk]];
}

+(NSArray *)findByCriteria:(NSString *)criteriaString, ...
{
	[[self class] tableCheck];
	NSMutableArray *ret = [NSMutableArray array];
	NSDictionary *theProps = [self propertiesWithEncodedTypes];
	sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
	
	// Added variadic ability to all criteria accepting methods -SLyons (10/03/2009)
	va_list argumentList;
	va_start(argumentList, criteriaString);
	NSString *queryString = [[NSString alloc] initWithFormat:criteriaString arguments:argumentList];
	
	NSString *query = [NSString stringWithFormat:@"SELECT pk,* FROM %@ %@", [[self class] tableName], queryString];
	[queryString release];
	
	sqlite3_stmt *statement;
	if (sqlite3_prepare_v2( database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
	{
		while (sqlite3_step(statement) == SQLITE_ROW)
		{
			int pk = sqlite3_column_int(statement, 0);
			NSString* memoryMapKey = [[self class] memoryMapKeyForObject:pk];
			id oneItem = [objectMap objectForKey:memoryMapKey];
			if (oneItem)
			{
				[ret addObject:[oneItem retain]];
				continue;
			}
			
			oneItem = [[[self class] alloc] init];
			[oneItem setPk:pk];
			[[self class] registerObjectInMemory:oneItem];			
			
			int i;
			for (i=0; i <  sqlite3_column_count(statement); i++)
			{
				NSString *colName = [NSString stringWithUTF8String:sqlite3_column_name(statement, i)];
				if ([colName isEqualToString:@"pk"])
				{
					//already set
					continue;
				}
				else
				{
					
					NSString *propName = [colName stringAsPropertyString];
					
					NSString *colType = [theProps valueForKey:propName];
					if (colType == nil)
						break;
					if ([colType isEqualToString:@"i"] || // int
						[colType isEqualToString:@"l"] || // long
						[colType isEqualToString:@"q"] || // long long
						[colType isEqualToString:@"s"] || // short
						[colType isEqualToString:@"B"] )  // bool or _Bool
						
					{
						long long value = sqlite3_column_int64(statement, i);
						NSNumber *colValue = [NSNumber numberWithLongLong:value];
						[oneItem setValue:colValue forKey:propName];
					}
					else if  ([colType isEqualToString:@"I"] || // unsigned int
							  [colType isEqualToString:@"L"] || // usigned long
							  [colType isEqualToString:@"Q"] || // unsigned long long
							  [colType isEqualToString:@"S"]) // unsigned short
					{
						unsigned long long value = sqlite3_column_int64(statement, i);
						NSNumber *colValue = [NSNumber numberWithUnsignedLongLong:value];
						[oneItem setValue:colValue forKey:propName];
					}
					else if ([colType isEqualToString:@"f"] || // float
							 [colType isEqualToString:@"d"] )  // double
					{
						NSNumber *colVal = [NSNumber numberWithFloat:sqlite3_column_double(statement, i)];
						[oneItem setValue:colVal forKey:propName];
					}
					else if ([colType isEqualToString:@"c"] ||	// char
							 [colType isEqualToString:@"C"] ) // unsigned char
						
					{
						const char *colVal = (const char *)sqlite3_column_text(statement, i);
						
						if (colVal != nil)
						{
							NSString *colValString = [NSString stringWithUTF8String:colVal];
							if ([colValString holdsFloatingPointValue])
							{
								NSNumber *number = [NSNumber numberWithDouble:[colValString doubleValue]];
								[oneItem setValue:number forKey:propName];
							}
							else if ([colValString holdsIntegerValue])
							{
								NSNumber *number = [NSNumber numberWithInt:[colValString intValue]];
								[oneItem setValue:number forKey:propName];
							}
							else
							{
								[oneItem setValue:colValString forKey:propName];
							}
						}
					}
					else if ([colType hasPrefix:@"@"])
					{
						NSString *className = [colType substringWithRange:NSMakeRange(2, [colType length]-3)];
						Class propClass = objc_lookUpClass([className UTF8String]);
						
						if ([propClass isSubclassOfClass:[SQLitePersistentObject class]])
						{
							const char* sqlKey = (const char *)sqlite3_column_text(statement, i);
							if(sqlKey != nil)
							{
								NSString *objMemoryMapKey = [NSString stringWithUTF8String:sqlKey];
								NSArray *parts = [objMemoryMapKey componentsSeparatedByString:@"-"];
								NSString *classString = [parts objectAtIndex:0];
								int fk = [[parts objectAtIndex:1] intValue];
								Class propClass = objc_lookUpClass([classString UTF8String]);
								id fkObj = [propClass findByPK:fk];
								[oneItem setValue:fkObj forKey:propName];
							}
						}
						else if ([propClass shouldBeStoredInBlob])
						{
							const char * rawData = sqlite3_column_blob(statement, i);
							int rawDataLength = sqlite3_column_bytes(statement, i);
							NSData *data = [NSData dataWithBytes:rawData length:rawDataLength];
							id colData = [propClass objectWithSQLBlobRepresentation:data];
							[oneItem setValue:colData forKey:propName];
						}
						else
						{
							id colData = nil;
							const char *columnText = (const char *)sqlite3_column_text(statement, i);
							if (NULL != columnText)
								colData = [propClass objectWithSqlColumnRepresentation:[NSString stringWithUTF8String:columnText]];
							
							
							[oneItem setValue:colData forKey:propName];
						}
					}
					
				}
			}
			
			// Loop through properties and look for collections classes
			for (NSString *propName in theProps)
			{
				NSString *propType = [theProps objectForKey:propName];
				if ([propType hasPrefix:@"@"])
				{
					NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
					if (isCollectionType(className))
					{
						if (isNSSetType(className))
						{
							NSMutableSet *set = [NSMutableSet set];
							[oneItem setValue:set forKey:propName];
							/*
							 parent_pk INTEGER, fk INTEGER, fk_table_name TEXT, object_data TEXT
							 */
							NSString *setQuery = [NSString stringWithFormat:@"SELECT fk, fk_table_name, object_data, object_class FROM %@_%@ WHERE parent_pk = %d", [[self class] tableName], [propName stringAsSQLColumnName], [oneItem pk]];
							sqlite3_stmt *setStmt;
							if (sqlite3_prepare_v2(database, [setQuery UTF8String], -1, &setStmt, NULL) == SQLITE_OK)
							{
								while (sqlite3_step(setStmt) == SQLITE_ROW)
								{
									int fk = sqlite3_column_int(setStmt, 0);
									
									if (fk > 0)
									{
										const char *fkTableNameRaw = (const char *)sqlite3_column_text(setStmt, 1);
										NSString *fkTableName = (fkTableNameRaw == nil) ? nil : [NSString stringWithUTF8String:fkTableNameRaw];
										NSString *propClassName = [[self class] classNameForTableName:fkTableName];
										Class propClass = objc_lookUpClass([propClassName UTF8String]);
										id oneObject = [propClass findFirstByCriteria:[NSString stringWithFormat:@"where pk = %d", fk]];
										if (oneObject != nil)
											[set addObject:oneObject];
									}
									else
									{
										
										const char *objectClassRaw = (const char *)sqlite3_column_text(setStmt, 3);
										NSString *objectClassName = (objectClassRaw == nil) ? nil : [NSString stringWithUTF8String:objectClassRaw];
										
										Class objectClass = objc_lookUpClass([objectClassName UTF8String]);
										if ([objectClass shouldBeStoredInBlob])
										{
											NSData *data = [NSData dataWithBytes:sqlite3_column_blob(setStmt, 2) length:sqlite3_column_bytes(setStmt, 2)];
											id theObject = [objectClass objectWithSQLBlobRepresentation:data];
											[set addObject:theObject];
										}
										else
										{
											const char *objectDataRaw = (const char *)sqlite3_column_text(setStmt, 2);
											NSString *objectData = (objectDataRaw == nil) ? nil : [NSString stringWithUTF8String:objectDataRaw];
											
											id theObject = [objectClass objectWithSqlColumnRepresentation:objectData];
											[set addObject:theObject];
										}
									}
								}
							}
							sqlite3_finalize(setStmt);
						}
						else if (isNSArrayType(className))
						{
							NSMutableArray *array = [NSMutableArray array];
							[oneItem setValue:array forKey:propName];
							
							NSString *arrayQuery = [NSString stringWithFormat:@"SELECT fk, fk_table_name, object_data, object_class FROM %@_%@ WHERE parent_pk = %d order by array_index", [[self class] tableName], [propName stringAsSQLColumnName], [oneItem pk]];
							sqlite3_stmt *arrayStmt;
							if (sqlite3_prepare_v2(database, [arrayQuery UTF8String], -1, &arrayStmt, NULL) == SQLITE_OK)
							{
								while (sqlite3_step(arrayStmt) == SQLITE_ROW)
								{
									
									int fk = sqlite3_column_int(arrayStmt, 0);
									
									if (fk > 0)
									{
										const char *fkTableNameRaw = (const char *)sqlite3_column_text(arrayStmt, 1);
										NSString *fkTableName = (fkTableNameRaw == nil) ? nil : [NSString stringWithUTF8String:fkTableNameRaw];
										NSString *propClassName = [[self class] classNameForTableName:fkTableName];
										Class propClass = objc_lookUpClass([propClassName UTF8String]);
										id oneObject = [propClass findFirstByCriteria:[NSString stringWithFormat:@"where pk = %d", fk]];
										if (oneObject != nil)
											[array addObject:oneObject];
									}
									else
									{
										
										const char *objectClassRaw = (const char *)sqlite3_column_text(arrayStmt, 3);
										NSString *objectClassName = (objectClassRaw == nil) ? nil : [NSString stringWithUTF8String:objectClassRaw];
										
										Class objectClass = objc_lookUpClass([objectClassName UTF8String]);
										if ([objectClass shouldBeStoredInBlob])
										{
											NSData *data = [NSData dataWithBytes:sqlite3_column_blob(arrayStmt, 2) length:sqlite3_column_bytes(arrayStmt, 2)];
											id theObject = [objectClass objectWithSQLBlobRepresentation:data];
											[array addObject:theObject];
										}
										else
										{
											const char *objectDataRaw = (const char *)sqlite3_column_text(arrayStmt, 2);
											NSString *objectData = (objectDataRaw == nil) ? nil : [NSString stringWithUTF8String:objectDataRaw];
											
											id theObject = [objectClass objectWithSqlColumnRepresentation:objectData];
											if (theObject)
												[array addObject:theObject];
										}
									}
								}
							}
							sqlite3_finalize(arrayStmt);
						}
						else if (isNSDictionaryType(className))
						{
							NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
							[oneItem setValue:dictionary forKey:propName];
							/* parent_pk integer, dictionary_key TEXT, fk INTEGER, fk_table_name TEXT, object_data BLOB, object_class  */
							
							NSString *dictionaryQuery = [NSString stringWithFormat:@"SELECT dictionary_key, fk, fk_table_name, object_data, object_class FROM %@_%@ WHERE parent_pk = %d", [[self class] tableName], [propName stringAsSQLColumnName], [oneItem pk]];
							sqlite3_stmt *dictionaryStmt;
							if (sqlite3_prepare_v2(database, [dictionaryQuery UTF8String], -1, &dictionaryStmt, NULL) == SQLITE_OK)
							{
								while (sqlite3_step(dictionaryStmt) == SQLITE_ROW)
								{
									NSString *key = [NSString stringWithUTF8String:(char *)sqlite3_column_text(dictionaryStmt, 0)];
									int fk = sqlite3_column_int(dictionaryStmt, 1);
									
									if (fk > 0)
									{
										const char *fkTableNameRaw = (const char *)sqlite3_column_text(dictionaryStmt, 2);
										NSString *fkTableName = (fkTableNameRaw == nil) ? nil : [NSString stringWithUTF8String:fkTableNameRaw];
										NSString *propClassName = [[self class] classNameForTableName:fkTableName];
										Class propClass = objc_lookUpClass([propClassName UTF8String]);
										id oneObject = [propClass findFirstByCriteria:[NSString stringWithFormat:@"where pk = %d", fk]];
										if (oneObject != nil)
											[dictionary setObject:oneObject forKey:key];
									}
									else
									{
										
										const char *objectClassRaw = (const char *)sqlite3_column_text(dictionaryStmt, 4);
										NSString *objectClassName = (objectClassRaw == nil) ? nil : [NSString stringWithUTF8String:objectClassRaw];
										
										Class objectClass = objc_lookUpClass([objectClassName UTF8String]);
										if ([objectClass shouldBeStoredInBlob])
										{
											NSData *data = [NSData dataWithBytes:sqlite3_column_blob(dictionaryStmt, 3) length:sqlite3_column_bytes(dictionaryStmt, 3)];
											id theObject = [objectClass objectWithSQLBlobRepresentation:data];
											if (theObject)
												[dictionary setObject:theObject forKey:key];
											
										}
										else
										{
											const char *objectDataRaw = (const char *)sqlite3_column_text(dictionaryStmt, 3);
											NSString *objectData = (objectDataRaw == nil) ? nil : [NSString stringWithUTF8String:objectDataRaw];
											
											id theObject = [objectClass objectWithSqlColumnRepresentation:objectData];
											if (theObject != nil)
												[dictionary setObject:theObject forKey:key];
										}
									}
								}
							}
							sqlite3_finalize(dictionaryStmt);
						}
					}
				}
			}
			[oneItem makeClean];
			
			[ret addObject:oneItem];
			[oneItem release];
		}
		sqlite3_finalize(statement);
	}
	
	return ret;
}
// This functionality has changed. Now the keys are the PK values, and the values are the values from the specified field. The old version wouldn't allow duplicates because it was using the name as the key, which rather eliminated the usefulness of the method.
+(NSMutableDictionary *)sortedFieldValuesWithKeysForProperty:(NSString *)theProp 
{
	NSMutableDictionary *ret = [NSMutableDictionary dictionary];
	[[self class] tableCheck];
	sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
	
	NSString *query = [NSString stringWithFormat:@"SELECT pk, %@ FROM %@ ORDER BY %@, pk", [theProp stringAsSQLColumnName], [[self class] tableName],  [theProp stringAsSQLColumnName]];
	sqlite3_stmt *statement;
	if (sqlite3_prepare_v2( database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
	{
		while (sqlite3_step(statement) == SQLITE_ROW)
		{
			NSNumber *thePK = [NSNumber numberWithInt:sqlite3_column_int(statement, 0)];
			NSString *theName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
			[ret setObject:theName forKey:[thePK stringValue]];
		}
	}
	sqlite3_finalize(statement);
	return ret;
}
+(NSArray *)pairedArraysForProperties:(NSArray *)theProps
{
	return [self pairedArraysForProperties:theProps withCriteria:@""];
}
+(NSArray *)pairedArraysForProperties:(NSArray *)theProps withCriteria:(NSString *)criteriaString, ...
{
	NSMutableArray *ret = [NSMutableArray array];
	[[self class] tableCheck];
	
	sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
	
	NSMutableString *query = [NSMutableString stringWithString:@"select pk"];
	
	for (NSString *oneProp in theProps)
		[query appendFormat:@", %@", [oneProp stringAsSQLColumnName]];
	
	// Added variadic ability to all criteria accepting methods -SLyons (10/03/2009)
	va_list argumentList;
	va_start(argumentList, criteriaString);
	NSString *queryString = [[NSString alloc] initWithFormat:criteriaString arguments:argumentList];
	
	[query appendFormat:@" FROM %@ %@ ORDER BY PK", [[self class] tableName], queryString];
	[queryString release];
	
	for (int i = 0; i <= [theProps count]; i++)
		[ret addObject:[NSMutableArray array]];
	
	sqlite3_stmt *statement;
	if (sqlite3_prepare_v2( database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
	{
		while (sqlite3_step(statement) == SQLITE_ROW)
		{
			NSNumber *thePK = [NSNumber numberWithInt:sqlite3_column_int(statement, 0)];
			[[ret objectAtIndex:0] addObject:thePK];
			
			for (int i = 1; i <= [theProps count]; i++)
			{
				NSMutableArray *fieldArray = [ret objectAtIndex:i];
				const char *theValueAsString = (const char *)sqlite3_column_text(statement, i);
				if (theValueAsString)
				{
					NSString *theValue = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, i)];
					[fieldArray addObject:theValue];
				}
				else
					[fieldArray addObject:[NSNull null]];
				
			}
		}
	}
	sqlite3_finalize(statement);
	
	return ret;
}
#ifdef TARGET_OS_COCOTRON
+ (NSArray *)getPropertiesList
{
	return [NSArray array];
}
#endif

+(NSDictionary *)propertiesWithEncodedTypes
{
	// Recurse up the classes, but stop at NSObject. Each class only reports its own properties, not those inherited from its superclass
	NSMutableDictionary *theProps;
	
	if ([self superclass] != [NSObject class])
		theProps = (NSMutableDictionary *)[[self superclass] propertiesWithEncodedTypes];
	else
		theProps = [NSMutableDictionary dictionary];
	
	unsigned int outCount;
	
#ifndef TARGET_OS_COCOTRON
	objc_property_t *propList = class_copyPropertyList([self class], &outCount);
#else
	NSArray *propList = [[self class] getPropertiesList];
	outCount = [propList count];
#endif
	int i;
	
	// Loop through properties and add declarations for the create
	for (i=0; i < outCount; i++)
	{
#ifndef TARGET_OS_COCOTRON
		objc_property_t oneProp = propList[i];
		NSString *propName = [NSString stringWithUTF8String:property_getName(oneProp)];
		NSString *attrs = [NSString stringWithUTF8String: property_getAttributes(oneProp)];
		// Read only attributes are assumed to be derived or calculated
		// See http://developer.apple.com/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/chapter_8_section_3.html
		if ([attrs rangeOfString:@",R,"].location == NSNotFound)
		{
			NSArray *attrParts = [attrs componentsSeparatedByString:@","];
			if (attrParts != nil)
			{
				if ([attrParts count] > 0)
				{
					NSString *propType = [[attrParts objectAtIndex:0] substringFromIndex:1];
					[theProps setObject:propType forKey:propName];
				}
			}
		}
#else
		NSArray *oneProp = [propList objectAtIndex:i];
		NSString *propName = [oneProp objectAtIndex:0];
		NSString *attrs = [oneProp objectAtIndex:1];
		[theProps setObject:attrs forKey:propName];
#endif
	}
	
#ifndef TARGET_OS_COCOTRON	
	free( propList );
#endif
	
	return theProps;	
}
#pragma mark -
#pragma mark Public Instance Methods
-(int)pk
{
	return pk;
}
-(void)save
{
	if (alreadySaving)
		return;
	alreadySaving = YES;
	
	[[self class] tableCheck];
	
    if (pk == 0)
    {
        NSLog(@"Object of type '%@' seems to be uninitialised, perhaps init does not call super init.", [[self class] description] );
        return;
    }
	
	NSDictionary *props = [[self class] propertiesWithEncodedTypes];
    
	if (!dirty)
	{
		// Check child and owned objects to see if any of them are dirty
		// Just tell children and composed objects to save themselves
		
		for (NSString *propName in props)
		{
			NSString *propType = [props objectForKey:propName];
			//int colIndex = sqlite3_bind_parameter_index(stmt, [[propName stringAsSQLColumnName] UTF8String]);
			id theProperty = [self valueForKey:propName];
			if ([propType hasPrefix:@"@"] ) // Object
			{
				NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
				
				
				if (! (isCollectionType(className)) )
				{
					if ([[theProperty class] isSubclassOfClass:[SQLitePersistentObject class]])
						if ([theProperty isDirty])
							dirty = YES;
				}
				else
				{
					if (isNSSetType(className) || isNSArrayType(className))
						for (id oneObject in (NSArray *)theProperty)
							if ([oneObject isKindOfClass:[SQLitePersistentObject class]])
								if ([oneObject isDirty])
									dirty = YES;					
								else if (isNSDictionaryType(className))
								{
									for (id oneKey in [theProperty allKeys])
									{
										id oneObject = [theProperty objectForKey:oneKey];
										if ([oneObject isKindOfClass:[SQLitePersistentObject class]])
											if ([oneObject isDirty])
												dirty = YES;
									}
								}
				}
			}
		}
	}
	
	NSArray *theTransients = [[self class] transients];
	
	if (dirty)
	{
		dirty = NO;
		
		sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
		
		// If this object is new, we need to figure out the correct primary key value, 
		// which will be one higher than the current highest pk value in the table.
		
		if (pk < 0)
		{
			NSString *pkQuery = [NSString stringWithFormat:@"SELECT SEQ FROM SQLITESEQUENCE WHERE NAME='%@'", [[self class] tableName]];
			sqlite3_stmt *statement;
			if (sqlite3_prepare_v2(database, [pkQuery UTF8String], -1, &statement, nil) == SQLITE_OK) 
			{
				if (sqlite3_step(statement) == SQLITE_ROW) 
				{
					pk = sqlite3_column_int(statement, 0)+1;
					char* errmsg;
					
					NSString *seqIncrementQuery = [NSString stringWithFormat:@"UPDATE SQLITESEQUENCE set seq=%d WHERE name='%@'", pk, [[self class] tableName]];
					if (sqlite3_exec (database, [seqIncrementQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)		
						NSLog(@"Error Message: %s", errmsg);
				}
				
			}
			else 
				NSLog(@"Error determining next PK value in table %@", [[self class] tableName]);
			
			sqlite3_finalize(statement);
		}
		
		NSMutableString *updateSQL = [NSMutableString stringWithFormat:@"INSERT OR REPLACE INTO %@ (pk", [[self class] tableName]];
		
		NSMutableString *bindSQL = [NSMutableString string];
		
		for (NSString *propName in props)
		{
			if ([theTransients containsObject:propName]) continue;
			
			NSString *propType = [props objectForKey:propName];
			NSString *className = @"";
			if ([propType hasPrefix:@"@"])
				className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
			if (! (isCollectionType(className)))
			{
				[updateSQL appendFormat:@", %@", [propName stringAsSQLColumnName]];
				[bindSQL appendString:@", ?"];
			}
		}
		
		[updateSQL appendFormat:@") VALUES (?%@)", bindSQL];
		
		sqlite3_stmt *stmt;
		int result = sqlite3_prepare_v2( database, [updateSQL UTF8String], -1, &stmt, nil);
		
		// if sql statement bound ok, now bind the column values
		if (result == SQLITE_OK)
		{
			int colIndex = 1;
			sqlite3_bind_int(stmt, colIndex++, pk);
			
			for (NSString *propName in props)
			{
				if ([theTransients containsObject:propName]) continue;
				
				NSString *propType = [props objectForKey:propName];
				NSString *className = propType;
				if ([propType hasPrefix:@"@"])
					className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
				//int colIndex = sqlite3_bind_parameter_index(stmt, [[propName stringAsSQLColumnName] UTF8String]);
				id theProperty = [self valueForKey:propName];
				if (theProperty == nil && ! (isCollectionType(className)))
				{
					sqlite3_bind_null(stmt, colIndex++);
				}
				else if ([propType isEqualToString:@"i"] || // int
						 [propType isEqualToString:@"I"] || // unsigned int
						 [propType isEqualToString:@"l"] || // long
						 [propType isEqualToString:@"L"] || // usigned long
						 [propType isEqualToString:@"q"] || // long long
						 [propType isEqualToString:@"Q"] || // unsigned long long
						 [propType isEqualToString:@"s"] || // short
						 [propType isEqualToString:@"S"] || // unsigned short
						 [propType isEqualToString:@"B"] || // bool or _Bool
						 [propType isEqualToString:@"f"] || // float
						 [propType isEqualToString:@"d"] )  // double
				{
					sqlite3_bind_text(stmt, colIndex++, [[theProperty stringValue] UTF8String], -1, NULL);
				}	
				else if ([propType isEqualToString:@"c"] ||	// char
						 [propType isEqualToString:@"C"] ) // unsigned char
					
				{
					NSString *theString = [theProperty stringValue];
					sqlite3_bind_text(stmt, colIndex++, [theString UTF8String], -1, NULL);
				}
				else if ([propType hasPrefix:@"@"] ) // Object
				{
					NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
					
					
					if (! (isCollectionType(className)) )
					{
						
						if ([[theProperty class] isSubclassOfClass:[SQLitePersistentObject class]])
						{
							[theProperty save];
							sqlite3_bind_text(stmt, colIndex++, [[theProperty memoryMapKey] UTF8String], -1, NULL);
						}
						else if ([[theProperty class] shouldBeStoredInBlob])
						{
							NSData *data = [theProperty sqlBlobRepresentationOfSelf];
							sqlite3_bind_blob(stmt, colIndex++, [data bytes], [data length], NULL);
						}
						else
						{
							sqlite3_bind_text(stmt, colIndex++, [[theProperty sqlColumnRepresentationOfSelf] UTF8String], -1, NULL);
						}
					}
					else
					{
						// Too difficult to try and figure out what's changed, just wipe rows and re-insert the current data.
						NSString *xrefDelete = [NSString stringWithFormat:@"delete from %@_%@ where parent_pk = %d", [[self class] tableName], [propName stringAsSQLColumnName], pk];
						char *errmsg = NULL;
						if (sqlite3_exec (database, [xrefDelete UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
							NSLog(@"Error deleting child rows in xref table for array: %s", errmsg);
						sqlite3_free(errmsg);
						
						
						if (isNSArrayType(className))
						{
							int arrayIndex = 0;
							for (id oneObject in (NSArray *)theProperty)
							{
								if ([oneObject isKindOfClass:[SQLitePersistentObject class]])
								{
									[oneObject save];
									NSString *xrefInsert = [NSString stringWithFormat:@"insert into %@_%@ (parent_pk, array_index, fk, fk_table_name) values (%d, %d, %d, '%@')", [[self class] tableName], [propName stringAsSQLColumnName],  pk, arrayIndex++, [oneObject pk], [[oneObject class] tableName]];
									if (sqlite3_exec (database, [xrefInsert UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
										NSLog(@"Error inserting child rows in xref table for array: %s", errmsg);
									sqlite3_free(errmsg);
								}
								else 
								{
									if ([[oneObject class] canBeStoredInSQLite])
									{
										NSString *xrefInsert = [NSString stringWithFormat:@"insert into %@_%@ (parent_pk, array_index, object_data, object_class) values (%d, %d, ?, '%@')", [[self class] tableName], [propName stringAsSQLColumnName], pk, arrayIndex++, [oneObject className]];
										
										sqlite3_stmt *xStmt;
										if (sqlite3_prepare_v2( database, [xrefInsert UTF8String], -1, &xStmt, nil) == SQLITE_OK)
										{
											if ([[oneObject class] shouldBeStoredInBlob])
											{
												NSData *data = [oneObject sqlBlobRepresentationOfSelf];
												sqlite3_bind_blob(xStmt, 1, [data bytes], [data length], NULL);
											}
											else
											{
												sqlite3_bind_text(xStmt, 1, [[oneObject sqlColumnRepresentationOfSelf] UTF8String], -1, NULL);	
											}
											
											if (sqlite3_step(xStmt) != SQLITE_DONE)
												NSLog(@"Error inserting or updating cross-reference row");
											sqlite3_finalize(xStmt);
										}
									}
									else 
										NSLog(@"Could not save object at array index: %d", arrayIndex++);
								}
							}
						}
						else if (isNSDictionaryType(className))
						{
							for (NSString *oneKey in (NSDictionary *)theProperty)
							{
								id oneObject = [(NSDictionary *)theProperty objectForKey:oneKey];
								if ([(NSObject *)oneObject isKindOfClass:[SQLitePersistentObject class]])
								{
									[(SQLitePersistentObject *)oneObject save];
									NSString *xrefInsert = [NSString stringWithFormat:@"insert into %@_%@ (parent_pk, dictionary_key, fk, fk_table_name) values (%d, '%@', %d, '%@')",  [[self class] tableName], [propName stringAsSQLColumnName], pk, oneKey, [(SQLitePersistentObject *)oneObject pk], [[oneObject class] tableName]];
									if (sqlite3_exec (database, [xrefInsert UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
										NSLog(@"Error inserting child rows in xref table for array: %s", errmsg);
									sqlite3_free(errmsg);
								}
								else
								{
									if ([[oneObject class] canBeStoredInSQLite])
									{
										NSString *xrefInsert = [NSString stringWithFormat:@"insert into %@_%@ (parent_pk, dictionary_key, object_data, object_class) values (%d, '%@', ?, '%@')", [[self class] tableName], [propName stringAsSQLColumnName], pk, oneKey, [oneObject className]];
										sqlite3_stmt *xStmt;
										if (sqlite3_prepare_v2( database, [xrefInsert UTF8String], -1, &xStmt, nil) == SQLITE_OK)
										{
											if ([[oneObject class] shouldBeStoredInBlob])
											{
												NSData *data = [oneObject sqlBlobRepresentationOfSelf];
												sqlite3_bind_blob(xStmt, 1, [data bytes], [data length], NULL);
											}
											else
												sqlite3_bind_text(xStmt, 1, [[oneObject sqlColumnRepresentationOfSelf] UTF8String], -1, NULL);
											
											if (sqlite3_step(xStmt) != SQLITE_DONE)
												NSLog(@"Error inserting or updating cross-reference row");
											
											sqlite3_finalize(xStmt);
											
										}
									}
								}
							}
						}
						else // NSSet
						{
							for (id oneObject in (NSSet *)theProperty)
							{
								if ([oneObject isKindOfClass:[SQLitePersistentObject class]])
								{
									[oneObject save];
									NSString *xrefInsert = [NSString stringWithFormat:@"insert into %@_%@ (parent_pk, fk, fk_table_name) values (%d, %d, '%@')", [[self class] tableName], [propName stringAsSQLColumnName],  pk, [oneObject pk], [[oneObject class] tableName]];
									if (sqlite3_exec (database, [xrefInsert UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
										NSLog(@"Error inserting child rows in xref table for array: %s", errmsg);
									sqlite3_free(errmsg);
								}
								else
								{
									if ([[oneObject class] canBeStoredInSQLite])
									{
										NSString *xrefInsert = [NSString stringWithFormat:@"insert into %@_%@ (parent_pk, object_data, object_class) values (%d, ?, '%@')", [[self class] tableName], [propName stringAsSQLColumnName], pk, [oneObject className]];
										
										sqlite3_stmt *xStmt;
										if (sqlite3_prepare_v2( database, [xrefInsert UTF8String], -1, &xStmt, nil) == SQLITE_OK)
										{
											if ([[oneObject class] shouldBeStoredInBlob])
											{
												NSData *data = [oneObject sqlBlobRepresentationOfSelf];
												sqlite3_bind_blob(xStmt, 1, [data bytes], [data length], NULL);
											}
											else
												sqlite3_bind_text(xStmt, 1, [[oneObject sqlColumnRepresentationOfSelf] UTF8String], -1, NULL);
											
											if (sqlite3_step(xStmt) != SQLITE_DONE)
												NSLog(@"Error inserting or updating cross-reference row");
											
											sqlite3_finalize(xStmt);
										}
									}
									else 
										NSLog(@"Could not save object from set");
								}
							}
						}
					}
				}
			}
			if (sqlite3_step(stmt) != SQLITE_DONE)
				NSLog(@"Error inserting or updating row");
			sqlite3_finalize(stmt);
		}
		else
			NSLog(@"Error preparing save SQL: %s", sqlite3_errmsg(database));
		// Can't register in memory map until we have PK, so do that now.
		if (![[objectMap allKeys] containsObject:[self memoryMapKey]])
			[[self class] registerObjectInMemory:self];
		
		
	}
	
	alreadySaving = NO;
}

/*
 * Reverts the object back to database state. Any changes that have been
 * made since the object was loaded are undone.
 */
-(void)revert
{
	if(![self existsInDB])
	{
		NSLog(@"Object must exist in database before it can be reverted.");
		return;
	}
	
	[[self class] unregisterObject:self];
	SQLitePersistentObject* dbObj = [[self class] findByPK:[self pk]];
	for(NSString *fieldName in [[self class] propertiesWithEncodedTypes])
	{
		if([dbObj valueForKey:fieldName] != [self valueForKey:fieldName])
			[self setValue:[dbObj valueForKey:fieldName] forKey:fieldName];
	}
	[[self class] registerObjectInMemory:self];
}

/*
 * Reverts the given field name back to its database state. 
 */
-(void)revertProperty:(NSString *)propName
{
	if(![self existsInDB])
	{
		NSLog(@"Object must exist in database before it can be reverted.");
		return;
	}
	
	[[self class] unregisterObject:self];
	SQLitePersistentObject* dbObj = [[self class] findByPK:[self pk]];
	if([dbObj valueForKey:propName] != [self valueForKey:propName])
		[self setValue:[dbObj valueForKey:propName] forKey:propName];
	[[self class] registerObjectInMemory:self];
}

/*
 * Reverts an NSArray of field names back to their database states. 
 */
-(void)revertProperties:(NSArray *)propNames
{
	if(![self existsInDB])
	{
		NSLog(@"Object must exist in database before it can be reverted.");
		return;
	}
	
	[[self class] unregisterObject:self];
	SQLitePersistentObject* dbObj = [[self class] findByPK:[self pk]];
	for(NSString *fieldName in propNames)
	{
		if([dbObj valueForKey:fieldName] != [self valueForKey:fieldName])
			[self setValue:[dbObj valueForKey:fieldName] forKey:fieldName];
	}
	[[self class] registerObjectInMemory:self];
}

-(BOOL) existsInDB
{
    // pk must be greater than 0 if its on the db
	return pk > 0;
}
-(void)deleteObject
{
	[self deleteObjectCascade:NO];
}
-(void)deleteObjectCascade:(BOOL)cascade
{
	if(pk < 0)
		return;
	
	if(alreadyDeleting)
		return;
	alreadyDeleting = TRUE;
	//Primary key set implies object already saved and table checked
	//[self tableCheck];
	
	[[self class] unregisterObject:self];
	
	NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE pk = %d", [[self class] tableName], pk];
	sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
	char *errmsg = NULL;
	if (sqlite3_exec (database, [deleteQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
		NSLog(@"Error deleting row in table: %s", errmsg);
	sqlite3_free(errmsg);
	
	NSDictionary *theProps = [[self class] propertiesWithEncodedTypes];
	
	for (NSString *prop in [theProps allKeys])
	{
		NSString *colType = [theProps valueForKey:prop];
		if ([colType hasPrefix:@"@"])
		{
			NSString *className = [colType substringWithRange:NSMakeRange(2, [colType length]-3)];
			if (isCollectionType(className))
			{
				if (cascade)
				{
					
					NSString *xRefLoopQuery = [NSString stringWithFormat:@"select fk_table_name, fk from %@_%@ where parent_pk = %d", [[self class] tableName], [prop stringAsSQLColumnName], pk];
					
					sqlite3_stmt *xLoopStmt;
					if (sqlite3_prepare_v2( database, [xRefLoopQuery UTF8String], -1, &xLoopStmt, NULL) == SQLITE_OK)
					{
						while (sqlite3_step(xLoopStmt) == SQLITE_ROW)
						{
							const unsigned char *fk_table = sqlite3_column_text(xLoopStmt, 0);
							int fk_value = sqlite3_column_int(xLoopStmt, 1);
							if (fk_table != NULL)
							{
								NSString *fkTableString = [NSString stringWithUTF8String:(const char *)fk_table];
								NSString *xRefDeleteQuery = [NSString stringWithFormat:@"delete from %@ where pk = %d",fkTableString, fk_value];
								
								if (sqlite3_exec (database, [xRefDeleteQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
									NSLog(@"Error deleting foreign key rows in table: %s", errmsg);
								sqlite3_free(errmsg);
							}
							
						}
					}
					sqlite3_finalize(xLoopStmt);
					//					
					//					Class fkClass = objc_lookUpClass([prop UTF8String]);
					//					NSString *fkDeleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE PK IN (SELECT FK FROM %@_%@_XREF WHERE pk = %d)",  [fkClass tableName],  [[self class] tableName],  [prop stringAsSQLColumnName], inPk];
					//					// Suppress the error if there was one: it's faster than checking to see if the table exists. 
					//					// It may not if the property was used to store strings or another storage class but never
					//					// a subclass of SQLitePersistentObject
					//					sqlite3_exec (database, [fkDeleteQuery UTF8String], NULL, NULL, NULL);
					
				}
				
				NSString *xRefDeleteQuery = [NSString stringWithFormat:@"DELETE FROM %@_%@ WHERE parent_pk = %d",  [[self class] tableName], [prop stringAsSQLColumnName], pk];
				if (sqlite3_exec (database, [xRefDeleteQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
					NSLog(@"Error deleting from foreign key table: %s", errmsg);
				sqlite3_free(errmsg);
			}
			else
			{
				Class propClass = objc_lookUpClass([className UTF8String]);
				if ([propClass isSubclassOfClass:[SQLitePersistentObject class]] && cascade)
				{
					id theProperty = [self valueForKey:prop];
					[theProperty deleteObjectCascade:cascade];
				}
			}
			
		}
	}
	alreadyDeleting = FALSE;
}

- (NSArray *)findRelated:(Class)cls forProperty:(NSString *)prop filter:(NSString *)filter, ...
{
	NSString *q = [NSString stringWithFormat:@"WHERE %@ = \"%@\"", prop, [self memoryMapKey]];
	if(filter)
	{
		// Added variadic ability to all criteria accepting methods -SLyons (10/03/2009)
		va_list argumentList;
		va_start(argumentList, filter);
		NSString *queryString = [[NSString alloc] initWithFormat:filter arguments:argumentList];
		q = [q stringByAppendingFormat:@" AND %@", queryString];
		[queryString release];
	}

	return [cls findByCriteria:q];
}

- (NSArray *)findRelated:(Class)cls filter:(NSString *)filter, ...
{
	// Added variadic ability to all criteria accepting methods -SLyons (10/03/2009)
	va_list argumentList;
	va_start(argumentList, filter);
	NSString *queryString = [[[NSString alloc] initWithFormat:filter arguments:argumentList] autorelease];
	return [self findRelated:cls forProperty:[[self class] tableName] filter:queryString];	
}

- (NSArray *)findRelated:(Class)cls
{
	return [self findRelated:cls forProperty:[[self class] tableName] filter:nil];
}

#pragma mark -
#pragma mark NSObject Overrides 
+ (BOOL)resolveClassMethod:(SEL)theMethod
{
	@synchronized(self)
	{
		
		
		const char *methodName = sel_getName(theMethod);
		NSString *methodBeingCalled = [NSString stringWithUTF8String:methodName];
		
		if ([methodBeingCalled hasPrefix:@"findBy"])
		{
			NSRange theRange = NSMakeRange(6, [methodBeingCalled length] - 7);
			NSString *property = [[methodBeingCalled substringWithRange:theRange] stringByLowercasingFirstLetter];
			NSDictionary *properties = [self propertiesWithEncodedTypes];
			NSLog(@"Property: %@", property);	
			if ([[properties allKeys] containsObject:property])
			{
				SEL newMethodSelector = sel_registerName([methodBeingCalled UTF8String]);
				
				// Hardcore juju here, this is not documented anywhere in the runtime (at least no
				// anywhere easy to find for a dope like me), but if you want to add a class method
				// to a class, you have to get the metaclass object and add the clas to that. If you
				// add the method
#ifndef TARGET_OS_COCOTRON
				Class selfMetaClass = objc_getMetaClass([[self className] UTF8String]);
				return (class_addMethod(selfMetaClass, newMethodSelector, (IMP) findByMethodImp, "@@:@")) ? YES : [super resolveClassMethod:theMethod];
#else			
				if(class_getClassMethod([self class], newMethodSelector) != NULL) {
					return [super resolveClassMethod:theMethod];
				} else {
					BOOL isNewMethod = YES;
					Class selfMetaClass = objc_getMetaClass([[self className] UTF8String]);
					
					
					struct objc_method *newMethod = calloc(sizeof(struct objc_method), 1);
					struct objc_method_list *methodList = calloc(sizeof(struct objc_method_list)+sizeof(struct objc_method), 1);  
					
					newMethod->method_name = newMethodSelector;
					newMethod->method_types = "@@:@";
					newMethod->method_imp = (IMP) findByMethodImp;
					
					methodList->method_next = NULL;
					methodList->method_count = 1;
					memcpy(methodList->method_list, newMethod, sizeof(struct objc_method));
					free(newMethod);
					class_addMethods(selfMetaClass, methodList);
					
					assert(isNewMethod);
					return YES;
				}
#endif
			}
			else
				return [super resolveClassMethod:theMethod];
		}
		else if ([methodBeingCalled rangeOfString:@"Of"].location != NSNotFound)
		{
			NSRange rangeOfOf = [methodBeingCalled rangeOfString:@"Of"];
			NSString *operation = [methodBeingCalled substringToIndex:rangeOfOf.location];
			if ([operation isEqualToString:@"sum"] || [operation isEqualToString:@"avg"] 
				|| [operation isEqualToString:@"average"] || [operation isEqualToString:@"min"] 
				|| [operation isEqualToString:@"max"] || [operation isEqualToString:@"count"])
			{
				NSRange criteriaRange = [methodBeingCalled rangeOfString:@"WithCriteria"];
				if (criteriaRange.location == NSNotFound)
				{ 
					// Do for all
					NSRange theRange = NSMakeRange(rangeOfOf.location + rangeOfOf.length, [methodBeingCalled length] - (rangeOfOf.location + rangeOfOf.length));
					NSString *property = [[methodBeingCalled substringWithRange:theRange] stringByLowercasingFirstLetter];
					NSDictionary *properties = [self propertiesWithEncodedTypes];
					if ([[properties allKeys] containsObject:property])
					{
						SEL newMethodSelector = sel_registerName([methodBeingCalled UTF8String]);
						Class selfMetaClass = objc_getMetaClass([[self className] UTF8String]);
						return (class_addMethod(selfMetaClass, newMethodSelector, (IMP) aggregateMethodImp, "@@:")) ? YES : [super resolveClassMethod:theMethod];
					}
				}
				else
				{
					// do with criteria
					NSRange theRange = NSMakeRange(rangeOfOf.location + rangeOfOf.length, [methodBeingCalled length] - criteriaRange.length - (rangeOfOf.length + rangeOfOf.location) - 1);
					NSString *property = [[methodBeingCalled substringWithRange:theRange] stringByLowercasingFirstLetter];
					NSDictionary *properties = [self propertiesWithEncodedTypes];
					if ([[properties allKeys] containsObject:property])
					{
						SEL newMethodSelector = sel_registerName([methodBeingCalled UTF8String]);
						Class selfMetaClass = objc_getMetaClass([[self className] UTF8String]);
						return (class_addMethod(selfMetaClass, newMethodSelector, (IMP) aggregateMethodWithCriteriaImp, "@@:@")) ? YES : [super resolveClassMethod:theMethod];
					}
				}
			}
		}
		return [super resolveClassMethod:theMethod];
	}
	return NO;
}
-(id)init
{
	if ((self=[super init]))
	{
		pk = -1;
		dirty = YES;
		alreadySaving = NO;
		for (NSString *oneProp in [[self class] propertiesWithEncodedTypes])
			[self addObserver:self forKeyPath:oneProp options:0 context:nil];
		
		
	}
	return self;
}
- (void)dealloc 
{
	[[self class] unregisterObject:self];
	[super dealloc];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	dirty = YES;
}
#pragma mark -
#pragma mark Private Methods
+ (NSString *)classNameForTableName:(NSString *)theTable
{
	static NSMutableDictionary *classNamesForTables = nil;
	
	if (classNamesForTables == nil)
		classNamesForTables = [[NSMutableDictionary alloc] init];
	
	if ([[classNamesForTables allKeys] containsObject:theTable])
		return [classNamesForTables objectForKey:theTable];
	
	
	NSMutableString *ret = [NSMutableString string];
	
	BOOL lastCharacterWasUnderscore = NO;
	for (int i = 0; i < theTable.length; i++)
	{
		NSRange range = NSMakeRange(i, 1);
		NSString *oneChar = [theTable substringWithRange:range];
		if ([oneChar isEqualToString:@"_"])
			lastCharacterWasUnderscore = YES;
		else
		{
			if (lastCharacterWasUnderscore || i == 0)
				[ret appendString:[oneChar uppercaseString]];
			else
				[ret appendString:oneChar];
			
			lastCharacterWasUnderscore = NO;
		}
	}
	[classNamesForTables setObject:ret forKey:theTable];
	
	return ret;
}
- (void)markDirty
{
	dirty = YES;
}
- (void)makeClean
{
	dirty = NO;
}
- (BOOL)isDirty
{
	return dirty;
}
+ (NSString *)tableName
{
	static NSMutableDictionary *tableNamesByClass = nil;
	
	if (tableNamesByClass == nil)
		tableNamesByClass = [[NSMutableDictionary alloc] init];
	
	if ([[tableNamesByClass allKeys] containsObject:[self className]])
		return [tableNamesByClass objectForKey:[self className]];
	
	// Note: Using a static variable to store the table name
	// will cause problems because the static variable will 
	// be shared by instances of classes and their subclasses
	// Cache in the instances, not here...
	NSMutableString *ret = [NSMutableString string];
	NSString *className = [self className];
	for (int i = 0; i < className.length; i++)
	{
		NSRange range = NSMakeRange(i, 1);
		NSString *oneChar = [className substringWithRange:range];
		if ([oneChar isEqualToString:[oneChar uppercaseString]] && i > 0)
			[ret appendFormat:@"_%@", [oneChar lowercaseString]];
		else
			[ret appendString:[oneChar lowercaseString]];
	}
	
	[tableNamesByClass setObject:ret forKey:[self className]];
	return ret;
}
+(NSArray *)tableColumns
{
	NSMutableArray *ret = [NSMutableArray array];
	// pragma table_info(i_c_project);
	sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
	NSString *query = [NSString stringWithFormat:@"pragma table_info(%@);", [self tableName]];
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2( database,  [query UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		while (sqlite3_step(stmt) == SQLITE_ROW)
		{
			const unsigned char *colName = sqlite3_column_text(stmt, 1);
			NSString *colString = [NSString stringWithUTF8String:(const char *)colName];
			[ret addObject:colString];
		}
		
		sqlite3_finalize(stmt);
	}
	return ret;
	
}
+(void)tableCheck
{
    NSArray *theTransients = [[self class] transients];
	
	if (checkedTables == nil)
		checkedTables = [[NSMutableArray alloc] init];
	
	if (![checkedTables containsObject:[self className]])
	{
		[checkedTables addObject:[self className]];
		
		// Do not use static variables to cache information in this method, as it will be
		// shared across subclasses. Do caching in instance methods.
		sqlite3 *database = [[SQLiteInstanceManager sharedManager] database];
		NSMutableString *createSQL = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (pk INTEGER PRIMARY KEY",[self tableName]];
		
		NSDictionary* props = [[self class] propertiesWithEncodedTypes];
		for (NSString *oneProp in props)
		{ 
			if ([theTransients containsObject:oneProp]) continue;
			
			NSString *propName = [oneProp stringAsSQLColumnName];
			
			NSString *propType = [props objectForKey:oneProp];
			// Integer Types
			if ([propType isEqualToString:@"i"] || // int
				[propType isEqualToString:@"I"] || // unsigned int
				[propType isEqualToString:@"l"] || // long
				[propType isEqualToString:@"L"] || // usigned long
				[propType isEqualToString:@"q"] || // long long
				[propType isEqualToString:@"Q"] || // unsigned long long
				[propType isEqualToString:@"s"] || // short
				[propType isEqualToString:@"S"] ||  // unsigned short
				[propType isEqualToString:@"B"] )   // bool or _Bool
			{
				[createSQL appendFormat:@", %@ INTEGER", propName];		
			}	
			// Character Types
			else if ([propType isEqualToString:@"c"] ||	// char
					 [propType isEqualToString:@"C"] )  // unsigned char
			{
				[createSQL appendFormat:@", %@ TEXT", propName];
			}
			else if ([propType isEqualToString:@"f"] || // float
					 [propType isEqualToString:@"d"] )  // double
			{		 
				[createSQL appendFormat:@", %@ REAL", propName];
			}
			else if ([propType hasPrefix:@"@"] ) // Object
			{
				
				
				NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
				
				// Collection classes have to be handled differently. Instead of adding a column, we add a child table.
				// Child tables will have a field for holding data and also a non-required foreign key field. If the
				// object stored in the collection is a subclass of SQLitePersistentObject, then it is stored as
				// a reference to the row in the table that holds the object. If it's not, then it is stored
				// in the field using the SQLitePersistence protocol methods. If it's not a subclass of 
				// SQLitePersistentObject and doesn't conform to NSCoding then the object won't get persisted.
				if (isNSArrayType(className))
				{
					NSString *xRefQuery = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@_%@ (parent_pk, array_index INTEGER, fk INTEGER, fk_table_name TEXT, object_data TEXT, object_class BLOB, PRIMARY KEY (parent_pk, array_index))", [self tableName], propName];
					char *errmsg = NULL;
					if (sqlite3_exec (database, [xRefQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)		
						NSLog(@"Error Message: %s", errmsg);
					
				}
				else if (isNSDictionaryType(className))
				{
					NSString *xRefQuery = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@_%@ (parent_pk integer, dictionary_key TEXT, fk INTEGER, fk_table_name TEXT, object_data BLOB, object_class TEXT, PRIMARY KEY (parent_pk, dictionary_key))", [self tableName], propName];
					char *errmsg = NULL;
					if (sqlite3_exec (database, [xRefQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)		
						NSLog(@"Error Message: %s", errmsg);
					
				}
				else if (isNSSetType(className))
				{
					NSString *xRefQuery = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@_%@ (parent_pk INTEGER, fk INTEGER, fk_table_name TEXT, object_data BLOB, object_class TEXT)", [self tableName], propName];
					char *errmsg = NULL;
					if (sqlite3_exec (database, [xRefQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)		
						NSLog(@"Error Message: %s", errmsg);
				}
				else
				{
					Class propClass = objc_lookUpClass([className UTF8String]);
					
					if ([propClass isSubclassOfClass:[SQLitePersistentObject class]])
					{
						// Store persistent objects as quasi foreign-key reference. We don't use
						// datbase's referential integrity tools, but rather use the memory map
						// key to store the table and fk in a single text field
						[createSQL appendFormat:@", %@ TEXT", propName];
					}
					else if ([propClass canBeStoredInSQLite])
					{
						[createSQL appendFormat:@", %@ %@", propName, [propClass columnTypeForObjectStorage]];
					}
				}
				
			}
			
			
		}	 
		[createSQL appendString:@")"];
		
		char *errmsg = NULL;
		if (sqlite3_exec (database, [createSQL UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)		
			NSLog(@"Error Message: %s", errmsg);
		
		if (sqlite3_exec (database, "CREATE TABLE IF NOT EXISTS SQLITESEQUENCE (name TEXT PRIMARY KEY, seq INTEGER)", NULL, NULL, &errmsg) != SQLITE_OK)		
			NSLog(@"Error Message: %s", errmsg);
		
		NSMutableString *addSequenceSQL = [NSMutableString stringWithFormat:@"INSERT OR IGNORE INTO SQLITESEQUENCE (name,seq) VALUES ('%@', 0)", [[self class] tableName]];
		if (sqlite3_exec (database, [addSequenceSQL UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)		
			NSLog(@"Error Message: %s", errmsg);
		
		NSArray *theIndices = [self indices];
		if (theIndices != nil)
		{
			if ([theIndices count] > 0)
			{
				for (NSArray *oneIndex in theIndices)
				{
					NSMutableString *indexName = [NSMutableString stringWithString:[self tableName]];
					NSMutableString *fieldCondition = [NSMutableString string];
					BOOL first = YES;
					for (NSString *oneField in oneIndex)
					{
						[indexName appendFormat:@"_%@", [oneField stringAsSQLColumnName]];
						
						if (first) 
							first = NO;
						else
							[fieldCondition appendString:@", "];
						[fieldCondition appendString:[oneField stringAsSQLColumnName]];
					}
					NSString *indexQuery = [NSString stringWithFormat:@"create index if not exists %@ on %@ (%@)", indexName, [self tableName], fieldCondition];
					errmsg = NULL;
					if (sqlite3_exec (database, [indexQuery UTF8String], NULL, NULL, &errmsg) != SQLITE_OK)
						NSLog(@"Error creating indices on %@: %s", [self tableName], errmsg);
				}
			}
		}
		
		// Now, make sure that every property has a corresponding column, alter the table for any that are missing
		NSArray *tableCols = [self tableColumns];
		for (NSString *oneProp in props)
		{ 
			if ([theTransients containsObject:oneProp]) continue;
			
			NSString *propName = [oneProp stringAsSQLColumnName];
			if (![tableCols containsObject:propName])
			{
				// No underlying column - could be a collection
				NSString *propType = [[[self class] propertiesWithEncodedTypes] objectForKey:oneProp];
				if ([propType hasPrefix:@"@"])
				{
					NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
					if (isNSArrayType(className) || isNSDictionaryType(className) || isNSSetType(className))
					{
						// It's a collection, it's okay for there to be no column, and we don't even need to 
						// check if it exists, because we used create if not exists above, so it will get created
						// no matter what. I'm going to leave the if clause and this comment here though so
						// nobody spends time doing unnecessary work implementing this...
					}
					else
					{
						Class propClass = objc_lookUpClass([className UTF8String]);
						NSString *colType = nil;
						
						if ([propClass isSubclassOfClass:[SQLitePersistentObject class]])
							colType = @"TEXT";
						else if ([propClass canBeStoredInSQLite])
							colType = [propClass columnTypeForObjectStorage];
						
						[[SQLiteInstanceManager sharedManager] executeUpdateSQL:[NSString stringWithFormat:@"alter table %@ add column %@ %@", [self tableName], propName, colType]];
					}
				}
				else
				{
					// TODO: Refactor out the col-type for property type into a single method or inline function
					NSString *colType = @"TEXT";
					if ([propType isEqualToString:@"i"] || // int
						[propType isEqualToString:@"I"] || // unsigned int
						[propType isEqualToString:@"l"] || // long
						[propType isEqualToString:@"L"] || // usigned long
						[propType isEqualToString:@"q"] || // long long
						[propType isEqualToString:@"Q"] || // unsigned long long
						[propType isEqualToString:@"s"] || // short
						[propType isEqualToString:@"S"] ||  // unsigned short
						[propType isEqualToString:@"B"] )   // bool or _Bool
						colType = @"INTEGER";	
					else if ([propType isEqualToString:@"f"] || // float
							 [propType isEqualToString:@"d"] )  // double
						colType = @"REAL";
					
					[[SQLiteInstanceManager sharedManager] executeUpdateSQL:[NSString stringWithFormat:@"alter table %@ add column %@ %@", [self tableName], propName, colType]];
				}
			}
			
		}
	}
}
- (void)setPk:(int)newPk
{
	pk = newPk;
}
#pragma mark -
#pragma mark KV
- (void)takeValuesFromDictionary:(NSDictionary *)properties
{
	[self markDirty];
	[super takeValuesFromDictionary:properties];
}
- (void)takeValue:(id)value forKey:(NSString *)key
{
	[self markDirty];
	[super takeValue:value forKey:key];
}
- (void)setValue:(id)value forKey:(NSString *)key
{
	[self markDirty];
	[super setValue:value forKey:key];
}
#pragma mark -
#pragma mark Memory Map Methods
+ (NSString *)memoryMapKeyForObject:(NSInteger)thePK
{
	return [NSString stringWithFormat:@"%@-%d", [self className], thePK];
}
- (NSString *)memoryMapKey
{
	return [[self class] memoryMapKeyForObject:[self pk]];
}
+ (void)registerObjectInMemory:(SQLitePersistentObject *)theObject
{
	if (objectMap == nil)
		objectMap = [[NSMutableDictionary alloc] init];
	
	[objectMap setObject:theObject forKey:[theObject memoryMapKey]];
	
}
+ (void)unregisterObject:(SQLitePersistentObject *)theObject
{
	if (objectMap == nil)
		objectMap = [[NSMutableDictionary alloc] init];
	
	// We have to make sure we're not removing objects from memory map when deleting partially created ones...
	SQLitePersistentObject *compare = [objectMap objectForKey:[theObject memoryMapKey]];
	if (compare == theObject)
		[objectMap removeObjectForKey:[theObject memoryMapKey]]; 
}
@end
