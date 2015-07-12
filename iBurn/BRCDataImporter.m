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

@interface BRCDataImporter() <NSURLSessionDownloadDelegate>
@property (nonatomic, strong, readonly) NSURLSession *urlSession;

@property (nonatomic, copy) void (^urlSessionCompletionHandler)(void);

/** Handles post-processing of update data */
@property (nonatomic, strong) NSOperationQueue *updateQueue;

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
        _updateQueue = [[NSOperationQueue alloc] init];
        _readWriteConnection = readWriteConection;
        _callbackQueue = dispatch_get_main_queue();
        if (sessionConfiguration) {
            _sessionConfiguration = sessionConfiguration;
        } else {
            _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        _urlSession = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    }
    return self;
}

- (void) loadUpdatesFromURL:(NSURL*)updateURL
           fetchResultBlock:(void (^)(UIBackgroundFetchResult result))fetchResultBlock {
    NSParameterAssert(updateURL != nil);
    NSURL *folderURL = [updateURL URLByDeletingLastPathComponent];
    if ([updateURL isFileURL]) {
        NSData *updateData = [[NSData alloc] initWithContentsOfURL:updateURL];
        [self loadUpdatesFromData:updateData folderURL:folderURL fetchResultBlock:fetchResultBlock];
        return;
    }
    NSURLSession *tempSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *dataTask = [tempSession dataTaskWithRequest:[NSURLRequest requestWithURL:updateURL] completionHandler:^(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error) {
        if (error) {
            NSLog(@"Error fetching updates: %@", error);
            if (fetchResultBlock) {
                fetchResultBlock(UIBackgroundFetchResultFailed);
            }
            return;
        }
        [self loadUpdatesFromData:data folderURL:folderURL fetchResultBlock:fetchResultBlock];
    }];
    [dataTask resume];
}

/** Fetch updates if needed from updates.json. folderURL is the root folder where updates.json is located */
- (void) loadUpdatesFromData:(NSData*)updateData folderURL:(NSURL*)folderURL fetchResultBlock:(void (^)(UIBackgroundFetchResult result))fetchResultBlock {
    // parse update JSON
    NSError *error = nil;
    NSData *jsonData = updateData;
    NSDictionary *updateJSON = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error) {
        NSLog(@"JSON serialization error: %@", error);
        if (fetchResultBlock) {
            fetchResultBlock(UIBackgroundFetchResultFailed);
        }
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
        NSLog(@"Parse error: %@", parseError);
        if (fetchResultBlock) {
            fetchResultBlock(UIBackgroundFetchResultFailed);
        }
        return;
    }
    // fetch updates if needed
    __block UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;
    [newUpdateInfo enumerateObjectsUsingBlock:^(BRCUpdateInfo *updateInfo, NSUInteger idx, BOOL *stop) {
        NSString *key = updateInfo.yapKey;
        __block BRCUpdateInfo *oldUpdateInfo = nil;
        [self.readWriteConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
            oldUpdateInfo = [transaction objectForKey:key inCollection:[BRCUpdateInfo yapCollection]];
        }];
        
        if (oldUpdateInfo) {
            NSTimeInterval intervalSinceLastUpdated = [updateInfo.lastUpdated timeIntervalSinceDate:oldUpdateInfo.lastUpdated];
            if (intervalSinceLastUpdated <= 0 && oldUpdateInfo.fetchStatus == BRCUpdateFetchStatusComplete) {
                // already updated, skip update
                return;
            }
        }
        // We've got some new data!
        updateInfo.fetchStatus = BRCUpdateFetchStatusFetching;
        [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
            [transaction setObject:updateInfo forKey:key inCollection:[BRCUpdateInfo yapCollection]];
        }];
        fetchResult = UIBackgroundFetchResultNewData;
        NSURL *dataURL = [folderURL URLByAppendingPathComponent:updateInfo.fileName];
        if ([dataURL isFileURL]) {
            [self loadDataFromLocalURL:dataURL updateInfo:updateInfo];
        } else {
            NSURLSessionDownloadTask *downloadTask = [self.urlSession downloadTaskWithURL:dataURL];
            downloadTask.taskDescription = updateInfo.yapKey;
            [downloadTask resume];
        }
        
    }];
    if (fetchResultBlock) {
        fetchResultBlock(fetchResult);
    }
}

- (BOOL) loadDataFromJSONData:(NSData*)jsonData
                    dataClass:(Class)dataClass
                        error:(NSError**)error {
    NSParameterAssert(jsonData != nil);
    NSArray *jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    if (*error) {
        return NO;
    }
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:jsonObjects.count];
    if (dataClass == [BRCEventObject class]) {
        dataClass = [BRCRecurringEventObject class];
    }
    [jsonObjects enumerateObjectsUsingBlock:^(NSDictionary *jsonObject, NSUInteger idx, BOOL *stop) {
        NSError *parseError = nil;
        id object = [MTLJSONAdapter modelOfClass:dataClass fromJSONDictionary:jsonObject error:&parseError];
        if (object) {
            [objects addObject:object];
        } else if (parseError) {
#warning There will be missing items to due unicode JSON parsing errors
            NSLog(@"Error parsing JSON: %@ %@", jsonObject, parseError);
        }
    }];
    NSLog(@"About to load %d %@ objects.", (int)objects.count, NSStringFromClass(dataClass));
    [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        // Update Fetch info status
        NSString *yapKey = [BRCUpdateInfo yapKeyForClass:dataClass];
        BRCUpdateInfo *updateInfo = [transaction objectForKey:yapKey inCollection:[BRCUpdateInfo yapCollection]];
        NSParameterAssert(updateInfo != nil);
        if (!updateInfo) {
            NSLog(@"Couldn't find updateInfo for %@", yapKey);
            return;
        }
        [objects enumerateObjectsUsingBlock:^(BRCDataObject *object, NSUInteger idx, BOOL *stop) {
            @autoreleasepool {
                // We need to duplicate the recurring events to make our lives easier later
                if ([object isKindOfClass:[BRCRecurringEventObject class]]) {
                    BRCRecurringEventObject *recurringEvent = (BRCRecurringEventObject*)object;
                    NSArray *events = [recurringEvent eventObjects];
                    [events enumerateObjectsUsingBlock:^(BRCEventObject *event, NSUInteger idx, BOOL *stop) {
                        BRCEventObject *existingEvent = [transaction objectForKey:event.uniqueID inCollection:[[event class] collection]];
                        if (existingEvent) {
                            existingEvent = [existingEvent copy];
                            [existingEvent mergeValuesForKeysFromModel:event];
                            event = existingEvent;
                        }
                        existingEvent.lastUpdated = updateInfo.lastUpdated;
                        [transaction setObject:event forKey:event.uniqueID inCollection:[[event class] collection]];
                    }];
                } else { // Art and Camps
                    BRCDataObject *existingObject = [transaction objectForKey:object.uniqueID inCollection:[dataClass collection]];
                    if (existingObject) {
                        existingObject = [existingObject copy];
                        [existingObject mergeValuesForKeysFromModel:object];
                        object = existingObject;
                    }
                    existingObject.lastUpdated = updateInfo.lastUpdated;
                    [transaction setObject:object forKey:object.uniqueID inCollection:[dataClass collection]];
                }
            }
        }];
        
        updateInfo = [updateInfo copy];
        updateInfo.fetchStatus = BRCUpdateFetchStatusComplete;
        [transaction setObject:updateInfo forKey:yapKey inCollection:[BRCUpdateInfo yapCollection]];
    }];
    return YES;
}

/** Set this when app is launched from background via application:handleEventsForBackgroundURLSession:completionHandler: */
- (void) addBackgroundURLSessionCompletionHandler:(void (^)())completionHandler {
    self.urlSessionCompletionHandler = completionHandler;
}

- (void) loadDataFromLocalURL:(NSURL*)localURL updateInfo:(BRCUpdateInfo*)updateInfo {
    
    Class dataClass = updateInfo.dataObjectClass;
    if (dataClass) {
        NSData *jsonData = [[NSData alloc] initWithContentsOfURL:localURL];
        [self.updateQueue addOperationWithBlock:^{
            NSError *error = nil;
            BOOL success = [self loadDataFromJSONData:jsonData dataClass:dataClass error:&error];
            if (!success) {
                NSLog(@"Error loading JSON for %@: %@", NSStringFromClass(dataClass), error);
            }
        }];
    } else if (updateInfo.dataType == BRCUpdateDataTypeTiles) {
        // TODO update tiles!
#warning TODO update tiles
    }
}

#pragma mark NSURLSessionDelegate

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    [self.updateQueue waitUntilAllOperationsAreFinished];
    if (self.urlSessionCompletionHandler) {
        self.urlSessionCompletionHandler();
        self.urlSessionCompletionHandler = nil;
    }
}

#pragma mark NSURLSessionDownloadDelegate

- (void)         URLSession:(NSURLSession *)session
               downloadTask:(NSURLSessionDownloadTask *)downloadTask
  didFinishDownloadingToURL:(NSURL *)location
{
    NSString *yapKey = downloadTask.taskDescription;
    __block BRCUpdateInfo *updateInfo = nil;
    [self.readWriteConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        updateInfo = [transaction objectForKey:yapKey inCollection:[BRCUpdateInfo yapCollection]];
    }];
    NSParameterAssert(updateInfo != nil);
    if (!updateInfo) {
        NSLog(@"Couldn't fetch updateInfo from taskDescription!");
        return;
    }
    [self loadDataFromLocalURL:location updateInfo:updateInfo];
}

- (void)  URLSession:(NSURLSession *)session
        downloadTask:(NSURLSessionDownloadTask *)downloadTask
   didResumeAtOffset:(int64_t)fileOffset
  expectedTotalBytes:(int64_t)expectedTotalBytes
{
}

- (void)         URLSession:(NSURLSession *)session
               downloadTask:(NSURLSessionDownloadTask *)downloadTask
               didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten
  totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
}

@end
