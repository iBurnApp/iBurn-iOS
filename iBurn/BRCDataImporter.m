//
//  BRCDataImporter.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataImporter.h"
#import "BRCDatabaseManager.h"
#import "MTLJSONAdapter.h"
#import "BRCDataObject.h"
#import "BRCRecurringEventObject.h"

@implementation BRCDataImporter

- (void) handleError:(NSError*)error completionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    if (completionBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(NO, error);
        });
    }
};

- (void) loadDataFromURL:(NSURL*)dataURL dataClass:(Class)dataClass completionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *jsonData = [NSData dataWithContentsOfURL:dataURL];
        NSError *error = nil;
        NSArray *jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (error) {
            [self handleError:error completionBlock:completionBlock];
            return;
        }
        NSArray *objects = [MTLJSONAdapter modelsOfClass:dataClass fromJSONArray:jsonObjects error:&error];
        if (error) {
            [self handleError:error completionBlock:completionBlock];
            return;
        }
        [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [objects enumerateObjectsUsingBlock:^(BRCDataObject *object, NSUInteger idx, BOOL *stop) {
                @autoreleasepool {
                    // We need to duplicate the recurring events to make our lives easier later
                    if ([object isKindOfClass:[BRCRecurringEventObject class]]) {
                        BRCRecurringEventObject *recurringEvent = (BRCRecurringEventObject*)object;
                        NSArray *events = [recurringEvent eventObjects];
                        [events enumerateObjectsUsingBlock:^(BRCEventObject *event, NSUInteger idx, BOOL *stop) {
                            [transaction setObject:event forKey:event.uniqueID inCollection:[[event class] collection]];
                        }];
                    } else { // Art and Camps
                        BRCDataObject *existingObject = [transaction objectForKey:object.uniqueID inCollection:[dataClass collection]];
                        if (existingObject) {
                            existingObject = [existingObject copy];
                            [existingObject mergeValuesForKeysFromModel:object];
                            object = existingObject;
                        }
                        [transaction setObject:object forKey:object.uniqueID inCollection:[dataClass collection]];
                    }
                }
            }];
        } completionBlock:^{
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock(YES, nil);
                });
            }
        }];
    });
}

@end
