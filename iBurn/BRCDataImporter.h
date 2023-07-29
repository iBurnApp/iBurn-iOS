//
//  BRCDataImporter.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <YapDatabase/YapDatabase.h>
@import UIKit;

@class BRCUpdateInfo;

NS_ASSUME_NONNULL_BEGIN
/** this is posted when new map tiles come in. */
extern NSString * const BRCDataImporterMapTilesUpdatedNotification;

@interface BRCDataImporter : NSObject

@property (nonatomic, strong, readonly) YapDatabaseConnection *readWriteConnection;
@property (nonatomic, strong, readonly) NSURLSessionConfiguration *sessionConfiguration;
/** Defaults to main queue */
@property (nonatomic) dispatch_queue_t callbackQueue;

- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection;
- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection sessionConfiguration:(nullable NSURLSessionConfiguration*)sessionConfiguration NS_DESIGNATED_INITIALIZER;
- (instancetype) init NS_UNAVAILABLE;

/**
 *  Load updates from remote events.json file.
 * 
 *  @param updateURL url to updates.json file
 *  @param completionBlock fetch result status or error
 */
- (void) loadUpdatesFromURL:(NSURL*)updateURL
           fetchResultBlock:(void (^)(UIBackgroundFetchResult result))fetchResultBlock;

/** Set this when app is launched from background via application:handleEventsForBackgroundURLSession:completionHandler: */
- (void) addBackgroundURLSessionCompletionHandler:(void (^)(void))completionHandler;

/** Double-checks that the map tiles exist on each launch */
- (void) doubleCheckMapTiles:(nullable BRCUpdateInfo*)updateInfo;

- (void) resetUpdates;

@end
NS_ASSUME_NONNULL_END
