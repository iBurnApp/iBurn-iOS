//
//  BRCDataImporter.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRCDataImporter : NSObject

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
