//
//  BRCDataImporter.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataImporter.h"
#import "MTLJSONAdapter.h"
#import "BRCDataObject.h"
#import "BRCRecurringEventObject.h"

@implementation BRCDataImporter

- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection {
    if (self = [super init]) {
        _readWriteConnection = readWriteConection;
    }
    return self;
}

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
        NSMutableArray *objects = [NSMutableArray arrayWithCapacity:jsonObjects.count];
        [jsonObjects enumerateObjectsUsingBlock:^(NSDictionary *jsonObject, NSUInteger idx, BOOL *stop) {
            NSError *error = nil;
            id object = [MTLJSONAdapter modelOfClass:dataClass fromJSONDictionary:jsonObject error:&error];
            if (object) {
                [objects addObject:object];
            } else if (error) {
#warning There will be missing items to due unicode JSON parsing errors
                NSLog(@"Error parsing JSON: %@ %@", jsonObject, error);
            }
        }];
        [self.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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
