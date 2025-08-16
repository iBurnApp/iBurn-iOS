//
//  BRCDatabaseManager.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import Foundation;
@import CoreLocation;
@import YapDatabase;
@import MapKit;
@class LongLivedConnectionManager;
@class BRCDataObject;

NS_ASSUME_NONNULL_BEGIN

/** iBurn.sqlite */
extern NSString * const kBRCDatabaseName;
extern NSString * const kBRCDatabaseFolderName;

/** this is posted when an extension is ready. The userInfo contains
 the extension name under the "extensionName" key */
extern NSString * const BRCDatabaseExtensionRegisteredNotification;

@interface BRCDatabaseManager : NSObject

@property (nonatomic, strong, readonly) YapDatabase *database;
@property (nonatomic, strong, readonly) YapDatabaseConnection *readWriteConnection;
@property (nonatomic, strong, readonly) YapDatabaseConnection *backgroundReadConnection;
@property (nonatomic, strong, readonly) YapDatabaseConnection *uiConnection;
@property (nonatomic, strong, readonly) LongLivedConnectionManager *longLived;


/** Check to see if a file exists at the correct path */
+ (BOOL)existsDatabaseWithName:(NSString *)databaseName;

- (instancetype) initWithDatabaseName:(NSString*)databaseName;

/** Default database */
@property (nonatomic, class, readonly) BRCDatabaseManager *shared;

/** View containing all camp objects */
@property (nonatomic, strong, readonly) NSString *campsViewName;
/** View containing all art objects */
@property (nonatomic, strong, readonly) NSString *artViewName;
/** View containing all event objects */
@property (nonatomic, strong, readonly) NSString *eventsViewName;
/** View containing all BRCDataObjects (art, camps, events), grouped by collection */
@property (nonatomic, strong, readonly) NSString *dataObjectsViewName;
/** View containing all BRCDataObjects (art, camps, events), grouped by event time, then name */
@property (nonatomic, strong, readonly) NSString *searchObjectsViewName;

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
/** Art, camps and events filtered by favorite */
@property (nonatomic, strong, readonly) NSString *everythingFilteredByFavorite;
/** Art, camps and events filtered by favorite and expiration */
@property (nonatomic, strong, readonly) NSString *everythingFilteredByFavoriteAndExpiration;
/** Art filtered by having events */
@property (nonatomic, strong, readonly) NSString *artFilteredByEvents;
/** Art, camps and events filtered by visited status */
@property (nonatomic, strong, readonly) NSString *visitedObjectsViewName;
/** Art, camps and events filtered by want to visit status */
@property (nonatomic, strong, readonly) NSString *wantToVisitObjectsViewName;
/** Art, camps and events filtered by unvisited status */
@property (nonatomic, strong, readonly) NSString *unvisitedObjectsViewName;

/** Audio Tour */
@property (nonatomic, strong, readonly) NSString *audioTourViewName;
/** Art and camps that have images */
@property (nonatomic, strong, readonly) NSString *artImagesViewName;


/** Search view containing all camp objects */
@property (nonatomic, strong, readonly) NSString *searchCampsView;
/** Search view containing all art objects */
@property (nonatomic, strong, readonly) NSString *searchArtView;
/** Search view containing all event objects */
@property (nonatomic, strong, readonly) NSString *searchEventsView;
/** Search view containing all API objects */
@property (nonatomic, strong, readonly) NSString *searchEverythingView;
/** Search view containing all favorited objects */
@property (nonatomic, strong, readonly) NSString *searchFavoritesView;

/** Updates event filtered views based on newly selected preferences */
- (void) refreshEventFilteredViewsWithSelectedDay:(NSDate*)selectedDay completionBlock:(dispatch_block_t)completionBlock;
/** Refresh events sorting if selected by expiration/start time */
- (void) refreshEventsSortingWithCompletionBlock:(dispatch_block_t)completionBlock;
/** Refresh favorites filtered view based on expiration setting */
- (void) refreshFavoritesFilteredViewWithCompletionBlock:(dispatch_block_t)completionBlock;

/** R-Tree Index Extension Name */
@property (nonatomic, strong, readonly) NSString *rTreeIndex;

/** YapDatabaseRelationship to link events to their host camps/art */
@property (nonatomic, strong, readonly) NSString *relationships;

@property (nonatomic, strong, class, readonly) NSString *yapDatabaseDirectory;
/** 
 * Query for objects in bounded region.
 * @see MKCoordinateRegionMakeWithDistance
 */
- (void) queryObjectsInRegion:(MKCoordinateRegion)region
              completionQueue:(dispatch_queue_t)completionQueue
                 resultsBlock:(void (^)(NSArray<BRCDataObject*> *results))resultsBlock;

- (void) queryObjectsInMinCoord:(CLLocationCoordinate2D)minCoord
                       maxCoord:(CLLocationCoordinate2D)maxCoord
                completionQueue:(dispatch_queue_t)completionQueue
                   resultsBlock:(void (^)(NSArray<BRCDataObject*> *results))resultsBlock;

- (void) refreshArtFilteredView:(void (^_Nullable)(void))completionBlock;

@end

NS_ASSUME_NONNULL_END
