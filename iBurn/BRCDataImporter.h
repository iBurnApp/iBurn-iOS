//
//  BRCDataImporter.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRCDataImporter : NSObject

- (void) loadArtDataFromURL:(NSURL*)artURL completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;
- (void) loadCampDataFromURL:(NSURL*)campsURL completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;
- (void) loadEventsDataFromURL:(NSURL*)eventsURL completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

@end
