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
