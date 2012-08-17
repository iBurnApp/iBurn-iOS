//
//  SQLiteInstanceManager.h
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
#if (TARGET_OS_MAC && ! (TARGET_OS_EMBEDDED || TARGET_OS_ASPEN || TARGET_OS_IPHONE))	
#import <Foundation/Foundation.h>
#else
#import <UIKit/UIKit.h>
#endif
//#import "/usr/include/sqlite3.h"
#import <sqlite3.h>

#if (! TARGET_OS_IPHONE)
#import <objc/objc-runtime.h>
#else
#import <objc/runtime.h>
#import <objc/message.h>
#endif

typedef enum SQLITE3AutoVacuum
{
	kSQLITE3AutoVacuumNoAutoVacuum = 0,
	kSQLITE3AutoVacuumFullVacuum,
	kSQLITE3AutoVacuumIncrementalVacuum,
		
} SQLITE3AutoVacuum;
typedef enum SQLITE3LockingMode
{
	kSQLITE3LockingModeNormal = 0,
	kSQLITE3LockingModeExclusive,
} SQLITE3LockingMode;


@interface SQLiteInstanceManager : NSObject {

	@private
	SQLiteInstanceManager *singleton;
	NSString *databaseFilepath;
	sqlite3 *database;
}

@property (readwrite,retain) NSString *databaseFilepath;

+ (id)sharedManager;
- (sqlite3 *)database;
- (BOOL)tableExists:(NSString *)tableName;
- (void)setAutoVacuum:(SQLITE3AutoVacuum)mode;
- (void)setCacheSize:(NSUInteger)pages;
- (void)setLockingMode:(SQLITE3LockingMode)mode;
- (void)deleteDatabase;
- (void)vacuum;
- (void)executeUpdateSQL:(NSString *) updateSQL;
@end
