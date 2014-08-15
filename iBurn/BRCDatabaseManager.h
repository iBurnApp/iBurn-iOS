//
//  BRCDatabaseManager.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "YapDatabase.h"
#import "YapDatabaseFilteredViewTypes.h"
#import "YapDatabaseFilteredView.h"
#import "YapDatabaseFullTextSearch.h"

typedef NS_ENUM(NSUInteger, BRCDatabaseViewExtensionType) {
    BRCDatabaseViewExtensionTypeUnknown,
    BRCDatabaseViewExtensionTypeDistance,
    BRCDatabaseViewExtensionTypeTimeThenDistance,
};

typedef NS_ENUM(NSUInteger, BRCDatabaseFilteredViewType) {
    BRCDatabaseFilteredViewTypeUnknown,
    BRCDatabaseFilteredViewTypeEverything,
    BRCDatabaseFilteredViewTypeFavoritesOnly,
    BRCDatabaseFilteredViewTypeEventExpirationAndType,
    BRCDatabaseFilteredViewTypeEventSelectedDayOnly,
    BRCDatabaseFilteredViewTypeFullTextSearch
};

@interface BRCDatabaseManager : NSObject

@property (nonatomic, strong, readonly) YapDatabase *database;
@property (nonatomic, strong, readonly) YapDatabaseConnection *readWriteDatabaseConnection;

/** Check to see if a file exists at the correct path */
- (BOOL)existsDatabaseWithName:(NSString *)databaseName;

/** move pre-polulated database from bundle to correct directory of the same name */
- (BOOL)copyDatabaseFromBundle;

/** Do all the necessary setup and creates the database if none exists */
- (BOOL)setupDatabaseWithName:(NSString*)databaseName;


+ (instancetype) sharedInstance;

+ (YapDatabaseViewBlockType) filteringBlockType;
+ (YapDatabaseViewFilteringBlock) favoritesOnlyFilteringBlock;
+ (YapDatabaseViewFilteringBlock) eventsFilteringBlock;
+ (YapDatabaseViewFilteringBlock) allItemsFilteringBlock;

+ (YapDatabaseViewBlockType) eventsSelectedDayOnlyFilteringBlockType;
+ (YapDatabaseViewFilteringBlock) eventsSelectedDayOnlyFilteringBlock;

+ (YapDatabaseViewBlockType)sortingBlockTypeForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType;
+ (YapDatabaseViewSortingBlock)sortingBlockForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType fromLocation:(CLLocation*)fromLocation;

+ (YapDatabaseViewBlockType)groupingBlockTypeForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType;
+ (YapDatabaseViewGroupingBlock)groupingBlockForClass:(Class)viewClass extensionType:(BRCDatabaseViewExtensionType)extensionType;

/**
 *  Creates a new databaseView extension that should be registered with the name
 *  extensionNameForClass:extensionType:
 */
+ (YapDatabaseView*) databaseViewForClass:(Class)viewClass
                            extensionType:(BRCDatabaseViewExtensionType)extensionType
                             fromLocation:(CLLocation*)fromLocation;
+ (NSString*) databaseViewNameForClass:(Class)viewClass
                         extensionType:(BRCDatabaseViewExtensionType)extensionType;

/**
 *  Creates a new filteredView extension that should be registered with the name
 *  filteredExtensionNameForType:parentViewName:
 */
+ (YapDatabaseFilteredView*) filteredViewForType:(BRCDatabaseFilteredViewType)filterType
                                  parentViewName:(NSString*)parentViewName
                              allowedCollections:(NSSet*)allowedCollections;
+ (NSString*) filteredViewNameForType:(BRCDatabaseFilteredViewType)filterType
                       parentViewName:(NSString*)parentViewName;

/**
 *  Creates a new FTS extension that should be registered with the name
 *  fullTextSearchExtensionNameForClass:withIndexedProperties:
 */
+ (YapDatabaseFullTextSearch*) fullTextSearchForClass:(Class)viewClass
                                withIndexedProperties:(NSArray *)properties;
+ (NSString*) fullTextSearchNameForClass:(Class)viewClass
                            withIndexedProperties:(NSArray *)properties;


@end
