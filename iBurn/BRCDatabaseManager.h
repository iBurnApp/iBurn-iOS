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

/** Camps YapDatabaseFullTextSearch */
@property (nonatomic, strong, readonly) NSString *ftsCampsName;
/** Art YapDatabaseFullTextSearch */
@property (nonatomic, strong, readonly) NSString *ftsArtName;
/** Events YapDatabaseFullTextSearch */
@property (nonatomic, strong, readonly) NSString *ftsEventsName;
/** BRCDataObject (art, camps, events) YapDatabaseFullTextSearch */
@property (nonatomic, strong, readonly) NSString *ftsDataObjectName;

/** Events filtered by day */
@property (nonatomic, strong, readonly) NSString *eventsFilteredByDayViewName;
/** Events filtered by date, expiration, and type */
@property (nonatomic, strong, readonly) NSString *eventsFilteredByDayExpirationAndTypeViewName;


+ (YapDatabaseViewFiltering*) eventsFiltering;
+ (YapDatabaseViewFiltering*) eventsSelectedDayOnlyFiltering;

+ (YapDatabaseViewSorting*)sortingForClass:(Class)viewClass;
+ (YapDatabaseViewGrouping*)groupingForClass:(Class)viewClass;


@end
