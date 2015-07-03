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
#import "BRCUpdateInfo.h"
#import "BRCArtObject.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"

@interface BRCDataImporter()
@property (nonatomic, strong, readonly) NSURLSession *urlSession;
@end

@implementation BRCDataImporter

- (void) dealloc {
    [self.urlSession invalidateAndCancel];
}

- (instancetype) init {
    if (self = [self initWithReadWriteConnection:nil sessionConfiguration:nil]) {
    }
    return self;
}

- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection {
    if (self = [self initWithReadWriteConnection:readWriteConection sessionConfiguration:nil]) {
    }
    return self;
}

- (instancetype) initWithReadWriteConnection:(YapDatabaseConnection*)readWriteConection sessionConfiguration:(NSURLSessionConfiguration*)sessionConfiguration {
    if (self = [super init]) {
        _readWriteConnection = readWriteConection;
        _callbackQueue = dispatch_get_main_queue();
        if (sessionConfiguration) {
            _sessionConfiguration = sessionConfiguration;
        } else {
            _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        _urlSession = [NSURLSession sessionWithConfiguration:self.sessionConfiguration];
    }
    return self;
}

- (void) loadUpdatesFromURL:(NSURL*)updateURL
            completionBlock:(void (^)(UIBackgroundFetchResult fetchResult, NSError *error))completionBlock {
    NSParameterAssert(updateURL);
    NSURL *updateFolderURL = [updateURL URLByDeletingLastPathComponent];
    NSURLSessionDataTask *dataTask = [self.urlSession dataTaskWithURL:updateURL completionHandler:^(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error) {
        if (error) {
            [self handleFetchError:error completionBlock:completionBlock];
            return;
        }
        // parse update JSON
        NSData *jsonData = data;
        NSDictionary *updateJSON = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (error) {
            [self handleFetchError:error completionBlock:completionBlock];
            return;
        }
        NSMutableArray *newUpdateInfo = [NSMutableArray arrayWithCapacity:4];
        __block NSError *parseError = nil;
        [updateJSON enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
            BRCUpdateInfo *updateInfo = [MTLJSONAdapter modelOfClass:[BRCUpdateInfo class]  fromJSONDictionary:obj error:&parseError];
            if (parseError) {
                *stop = YES;
            }
            updateInfo.dataType = [BRCUpdateInfo dataTypeFromString:key];
            [newUpdateInfo addObject:updateInfo];
        }];
        if (parseError) {
            [self handleFetchError:parseError completionBlock:completionBlock];
            return;
        }
        // fetch updates if needed
        // group task completion together
        __block UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;
        __block NSError *fetchError = nil;
        dispatch_group_t fetchGroup = dispatch_group_create();
        dispatch_group_enter(fetchGroup);
        [newUpdateInfo enumerateObjectsUsingBlock:^(BRCUpdateInfo *updateInfo, NSUInteger idx, BOOL *stop) {
            dispatch_group_enter(fetchGroup);
            NSString *key = @(updateInfo.dataType).description;
            __block BRCUpdateInfo *oldUpdateInfo = nil;
            [self.readWriteConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
                oldUpdateInfo = [transaction objectForKey:key inCollection:[BRCUpdateInfo yapCollection]];
            }];
            
            if (oldUpdateInfo) {
                NSTimeInterval intervalSinceLastUpdated = [updateInfo.lastUpdated timeIntervalSinceDate:oldUpdateInfo.lastUpdated];
                if (intervalSinceLastUpdated <= 0) {
                    // already updated, skip update
                    dispatch_group_leave(fetchGroup);
                    return;
                }
            }
            NSURL *dataURL = [updateFolderURL URLByAppendingPathComponent:updateInfo.fileName];
            Class objClass = [updateInfo dataObjectClass];
            // BRC Data object subclass
            if (objClass && [objClass isSubclassOfClass:[BRCDataObject class]]) {
                [self loadDataFromURL:dataURL dataClass:objClass completionBlock:^(BOOL success, NSError *error) {
                    dispatch_group_leave(fetchGroup);
                    if (success) {
                        fetchResult = UIBackgroundFetchResultNewData;
                        [self.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
                            [transaction setObject:updateInfo forKey:key inCollection:[BRCUpdateInfo yapCollection]];
                        }];
                    } else {
                        fetchResult = UIBackgroundFetchResultFailed;
                        fetchError = error;
                    }
                }];
            } else if (updateInfo.dataType == BRCUpdateDataTypeTiles) {
                // TODO: update tiles
                dispatch_group_leave(fetchGroup);
#warning TODO update tiles
            }
        }];
        dispatch_group_leave(fetchGroup);
        dispatch_group_notify(fetchGroup, self.callbackQueue, ^{
            if (fetchError) {
                completionBlock(UIBackgroundFetchResultFailed, fetchError);
            } else {
                completionBlock(fetchResult, nil);
            }
        });
    }];
    [dataTask resume];
}

- (void) handleError:(NSError*)error completionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    if (completionBlock) {
        dispatch_async(self.callbackQueue, ^{
            completionBlock(NO, error);
        });
    }
};

- (void) handleFetchError:(NSError*)error completionBlock:(void (^)(UIBackgroundFetchResult fetchResult, NSError *error))completionBlock {
    if (completionBlock) {
        dispatch_async(self.callbackQueue, ^{
            completionBlock(UIBackgroundFetchResultFailed, error);
        });
    }
};

- (void) loadDataFromURL:(NSURL*)dataURL dataClass:(Class)dataClass completionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    if ([dataURL isFileURL]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *jsonData = [NSData dataWithContentsOfURL:dataURL];
            [self loadDataFromJSONData:jsonData dataClass:dataClass completionBlock:completionBlock];
        });
        return;
    }
    NSURLSessionDownloadTask *downloadTask = [self.urlSession downloadTaskWithURL:dataURL completionHandler:^(NSURL * __nullable location, NSURLResponse * __nullable response, NSError * __nullable error) {
        if (error) {
            [self handleError:error completionBlock:completionBlock];
            return;
        }
        [self loadDataFromURL:location dataClass:dataClass completionBlock:completionBlock];
    }];
    [downloadTask resume];
}

- (void) loadDataFromJSONData:(NSData*)jsonData
               dataClass:(Class)dataClass
         completionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    NSParameterAssert(jsonData != nil);
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
            dispatch_async(self.callbackQueue, ^{
                completionBlock(YES, nil);
            });
        }
    }];
}

@end
