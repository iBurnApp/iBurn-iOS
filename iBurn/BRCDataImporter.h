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

- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection NS_DESIGNATED_INITIALIZER;

/**
 *  Loads Data 
 *
 *  @param dataURL         local or remote URL to json
 *  @param dataClass       subclass of BRCDataObject
 *  @param completionBlock always called on main thread
 */
- (void) loadDataFromURL:(NSURL*)dataURL
               dataClass:(Class)dataClass
         completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

@end
