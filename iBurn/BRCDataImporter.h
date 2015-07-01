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
            completionBlock:(void (^)(UIBackgroundFetchResult fetchResult, NSError *error))completionBlock;
/**
 *  Loads new data. Use loadUpdatesFromURL: instead.
 *
 *  @param dataURL         local or remote URL to json
 *  @param dataClass       subclass of BRCDataObject
 *  @param completionBlock always called on main thread
 */
- (void) loadDataFromURL:(NSURL*)dataURL
               dataClass:(Class)dataClass
         completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

@end
