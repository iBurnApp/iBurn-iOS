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
    BRCDatabaseViewExtensionTypeTime,
};

typedef NS_ENUM(NSUInteger, BRCDatabaseFilteredViewType) {
    BRCDatabaseFilteredViewTypeUnknown,
    BRCDatabaseFilteredViewTypeFavorites,
    BRCDatabaseFilteredViewTypeEventExpirationAndType,
    BRCDatabaseFilteredViewTypeFullTextSearch
};

@interface BRCDatabaseManager : NSObject

@property (nonatomic, strong, readonly) YapDatabase *database;
@property (nonatomic, strong, readonly) YapDatabaseConnection *readWriteDatabaseConnection;

- (BOOL)setupDatabaseWithName:(NSString*)databaseName;

+ (instancetype) sharedInstance;

+ (YapDatabaseViewFilteringBlock)everythingFilteringBlock;

/** 
 *  Does not register the view, but checks if it is registered and returns
 *  the registered view if it exists. (Caller should register the view if needed)
 *  @see extensionNameForClass:extensionType:
 */
- (YapDatabaseView*) databaseViewForClass:(Class)viewClass
                            extensionType:(BRCDatabaseViewExtensionType)extensionType
                             fromLocation:(CLLocation*)fromLocation
                            extensionName:(NSString**)extensionName
                     previouslyRegistered:(BOOL*)previouslyRegistered;

/**
 *  Does not register the view, but checks if it is registered and returns
 *  the registered view if it exists. (Caller should register the view if needed)
 */
- (YapDatabaseFilteredView*) filteredDatabaseViewForType:(BRCDatabaseFilteredViewType)filterType
                                              parentViewName:(NSString*)parentViewName
                                           extensionName:(NSString**)extensionName
                                    previouslyRegistered:(BOOL*)previouslyRegistered;

/**
 *  Creates a new FTS extension that should be registered with the name
 *  fullTextSearchExtensionNameForClass:withIndexedProperties:
 */
+ (YapDatabaseFullTextSearch*) fullTextSearchForClass:(Class)viewClass
                                withIndexedProperties:(NSArray *)properties;

/**
 *  Creates a new FTS extension that should be registered with the name
 *  fullTextSearchExtensionNameForClass:withIndexedProperties:
 */
+ (NSString*) fullTextSearchExtensionNameForClass:(Class)viewClass
                            withIndexedProperties:(NSArray *)properties;
@end
