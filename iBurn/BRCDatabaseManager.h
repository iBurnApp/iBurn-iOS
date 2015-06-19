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

/** View containing all camp objects */
@property (nonatomic, strong, readonly) NSString *campsViewName;
/** View containing all art objects */
@property (nonatomic, strong, readonly) NSString *artViewName;
/** View containing all event objects */
@property (nonatomic, strong, readonly) NSString *eventsViewName;
/** View containing all BRCDataObjects (art, camps, events) */
@property (nonatomic, strong, readonly) NSString *dataObjectsViewName;



+ (YapDatabaseViewFiltering*) favoritesOnlyFiltering;
+ (YapDatabaseViewFiltering*) eventsFiltering;
+ (YapDatabaseViewFiltering*) allItemsFiltering;

+ (YapDatabaseViewFiltering*) eventsSelectedDayOnlyFiltering;

+ (YapDatabaseViewSorting*)sortingForClass:(Class)viewClass;
+ (YapDatabaseViewGrouping*)groupingForClass:(Class)viewClass;

/**
 *  Creates a new databaseView extension that should be registered with the name
 *  extensionNameForClass:extensionType:
 */
+ (YapDatabaseView*) databaseViewForClass:(Class)viewClass;
+ (NSString*) databaseViewNameForClass:(Class)viewClass;

/**
 *  Creates a new filteredView extension that should be registered with the name
 *  filteredExtensionNameForType:parentViewName:
 */
+ (YapDatabaseFilteredView*) filteredViewForType:(BRCDatabaseFilteredViewType)filterType
                                  parentViewName:(NSString*)parentViewName
                              allowedCollections:(YapWhitelistBlacklist*)allowedCollections;
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
