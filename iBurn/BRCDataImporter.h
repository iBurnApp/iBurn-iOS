//
//  BRCDataImporter.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <YapDatabase/YapDatabase.h>

@interface BRCDataImporter : NSObject

@property (nonatomic, strong, readonly) YapDatabaseConnection *readWriteConnection;
@property (nonatomic, strong, readonly) NSURLSessionConfiguration *sessionConfiguration;
/** Defaults to main queue */
@property (nonatomic) dispatch_queue_t callbackQueue;

- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection;
- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection sessionConfiguration:(NSURLSessionConfiguration*)sessionConfiguration NS_DESIGNATED_INITIALIZER;

/**
 *  Load updates from remote events.json file.
 * 
 *  @param updateURL url to updates.json file
 *  @param completionBlock fetch result status or error
 */
- (void) loadUpdatesFromURL:(NSURL*)updateURL
           fetchResultBlock:(void (^)(UIBackgroundFetchResult result))fetchResultBlock;

/** Set this when app is launched from background via application:handleEventsForBackgroundURLSession:completionHandler: */
- (void) addBackgroundURLSessionCompletionHandler:(void (^)())completionHandler;

@end
