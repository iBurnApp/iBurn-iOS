//
//  SQLitePersistentObject.h
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

#import <Foundation/Foundation.h>
//#import "/usr/include/sqlite3.h"
#import <sqlite3.h>

#if (! TARGET_OS_IPHONE)
#import <objc/objc-runtime.h>
#else
#import <objc/runtime.h>
#import <objc/message.h>
#endif

#define isCollectionType(x) (isNSSetType(x) || isNSArrayType(x) || isNSDictionaryType(x))
#define isNSArrayType(x) ([x isEqualToString:@"NSArray"] || [x isEqualToString:@"NSMutableArray"])
#define isNSDictionaryType(x) ([x isEqualToString:@"NSDictionary"] || [x isEqualToString:@"NSMutableDictionary"])
#define isNSSetType(x) ([x isEqualToString:@"NSSet"] || [x isEqualToString:@"NSMutableSet"])

#define DECLARE_PROPERTIES(...) + (NSArray *)getPropertiesList \
	{ \
		return [NSArray arrayWithObjects: \
		__VA_ARGS__ \
		, nil]; \
	}
#define DECLARE_PROPERTY(n,t) [NSArray arrayWithObjects:n, t, nil]

/*! 
 Any class that subclasses this class can have their properties automatically persisted into a sqlite database. There are some limits - currently certain property types aren't supported like void *, char *, structs and unions. Anything that doesn't work correctly with Key Value Coding will not work with this. Ordinary scalars (ints, floats, etc) will be converted to NSNumber, as will BOOL.
 
 SQLite is very good about converting types, so you can search on a number field passing in a number in a string, and can search on a string field by passing in a number. The only limitation we place on the search methods is that we don't allow searching on blobs, which is simply for performance reasons. 
 
 */
// TODO: Look at marking object "dirty" when changes are made, and if it's not dirty, save becomes a no-op.

@interface SQLitePersistentObject : NSObject {

@private
	NSInteger	pk;	
	BOOL		dirty;
	BOOL		alreadySaving;
	BOOL		alreadyDeleting;
}

/*!
 Returns the name of the table that this object will use to save its data
 */
+ (NSString *)tableName;

+ (void)clearCache;

/*!
 Find by criteria lets you specify the SQL conditions that will be used. The string passed in should start with the word WHERE. So, to search for a value with a pk value of 1, you would pass in @"WHERE pk = 1". When comparing to strings, the string comparison must be in single-quotes like this @"WHERE name = 'smith'".
 */
+(NSArray *)findByCriteria:(NSString *)criteriaString, ...;
+(SQLitePersistentObject *)findFirstByCriteria:(NSString *)criteriaString, ...;
+(SQLitePersistentObject *)findByPK:(int)inPk;
+(NSArray *)allObjects;

/*!
 Find related objects
 */
-(NSArray *)findRelated:(Class)cls forProperty:(NSString *)prop filter:(NSString *)filter, ...;
-(NSArray *)findRelated:(Class)cls filter:(NSString *)filter, ...;
-(NSArray *)findRelated:(Class)cls;


// Allows easy execution of SQL commands that return a single row, good for getting sums and averages of a single property
+ (double)performSQLAggregation: (NSString *)query, ...;
/*!
 This method should be overridden by subclasses in order to specify performance indices on the underyling table. 
 @result Should return an array of arrays. Each array represents one index, and should contain a list of the properties that the index should be created on, in the order the database should use to create it. This is case sensitive, and the values must match the value of property names
 */
+(NSArray *)indices;

/*!
 This method should be overridden by subclasses in order to specify transient properties on the underlying table. 
 @result Should return an array of property names to be ignored.  These are case sensitive, and the values must match the value of property names
 */
+(NSArray *)transients;

// This method returns a list of the names of thecolumns actually used in the database 
// table backing this class. It's used to make sure that all properties have a corresponding column 
+(NSArray *)tableColumns;

/*!
 Deletes this object's corresponding row from the database table. This version does NOT cascade to child objects in other tables.
 */
-(void)deleteObject;
+(void)deleteObject:(NSInteger)pk cascade:(BOOL)cascade;

/*!
 Deletes this object's corresponding row from the database table.
 @param cascade Specifies whether child rows should be also deleted
 */
-(void)deleteObjectCascade:(BOOL)cascade;

/*!
 This is just a convenience routine; in several places we have to iterate through the properties and take some action based
 on their type. This method creates an array with all the property names and their types in a dictionary. The values for 
 the encoded types will be one of:
 
 c	A char
 i	An int
 s	A short
 l	A long
 q	A long long
 C	An unsigned char
 I	An unsigned int
 S	An unsigned short
 L	An unsigned long
 Q	An unsigned long long
 f	A float
 d	A double
 B	A C++ bool or a C99 _Bool
 v	A void
 *	A character string (char *)
 @	An object (whether statically typed or typed id)
 #	A class object (Class)
 :	A method selector (SEL)
 [array type]	An array
 {name=type...}	A structure
 (name=type...)	A union
 bnum	A bit field of num bits
 ^type	A pointer to type
 ?	An unknown type (among other things, this code is used for function pointers)

 Currently, the following properties cannot be persisted using this class:  C, c, v, #, :, [array type], *, {name=type...}, (name=type...), bnum, ^type, or ?
 TODO: Look at finding ways to allow people to use some or all of the currently unsupported types... we could probably use sizeof to store the structs and unions maybe??.
 TODO: Look at overriding valueForUndefinedKey: to handle the char, char * and unsigned char property types - valueForKey: doesn't return anything for these, so currently they do not work.
 */
+ (NSDictionary *)propertiesWithEncodedTypes;

/*!
 Indicates whether this object has ever been saved to the database. It does not indicate that the data matches what's in the database, just that there is a corresponding row
 */
-(BOOL) existsInDB;

/*!
 Saves this object's current data to the database. If it has never been saved before, it will assign a primary key value based on the database contents. Scalar values (ints, floats, doubles, etc.) will be stored in appropriate database columns, objects will be stored using the SQLitePersistence protocol methods - objects that don't implement that protocol will be archived into the database. Collection clases will be stored in child cross-reference tables that serve double duty. Any object they contain that is a subclass of SQLItePersistentObject will be stored as a foreign key to the appropriate table, otherwise objects will be stored in a column according to SQLitePersistence. Currently, collection classes inside collection classes are simply serialized into the x-ref table, which works, but is not the most efficient means. 
 
 //TODO: Look at adding recursion of some form to allow collection objects within collection objects to be stored in a normalized fashion
 */
-(void)save;

/*
 * Reverts the object back to database state. Any changes that have been
 * made since the object was loaded are undone.
 */
-(void)revert;

/*
 * Reverts the given property (by name) back to its database state. 
 */
-(void)revertProperty:(NSString *)propName;

/*
 * Reverts an NSArray of property names back to their database states. 
 */
-(void)revertProperties:(NSArray *)propNames;

/*!
 Returns this objects primary key
 */
-(int)pk;

/*! 
 This method will return a dictionary using the value for one specified field as the key and the pk stored as an NSNumber as the object. This is designed for letting you retrieve a list for display without having to load all objects into memory.
 */
+(NSMutableDictionary *)sortedFieldValuesWithKeysForProperty:(NSString *)theProp;

/*!
 This method will return paired mutable arrays (packed into an array) for each of the specified fields in the theProps array. The number of returned arrays will always be one greater than the number of values in theProps (assuming all of the passed values are valid fields), as the first mutable array will contain the primary key values for the object; the remainder of the arrays will correspond to the props in the same order they were passed in. The paired arrays will containe information at the same index about the same object. The values will be returned as formatted strings, as this method is intended for display in an iPhone table
 */
+(NSArray *)pairedArraysForProperties:(NSArray *)theProps withCriteria:(NSString *)criteriaString, ...;
+(NSArray *)pairedArraysForProperties:(NSArray *)theProps;

+ (NSInteger)count; 
+ (NSInteger)countByCriteria:(NSString *)criteriaString, ...;

#ifdef TARGET_OS_COCOTRON
+ (NSArray *)getPropertiesList;
#endif

@end
