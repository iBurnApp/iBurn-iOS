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
    NSURLSession *tempSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *dataTask = [tempSession dataTaskWithRequest:[NSURLRequest requestWithURL:updateURL] completionHandler:^(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error) {
        if (error) {
            NSLog(@"Error fetching updates: %@", error);
            if (fetchResultBlock) {
                fetchResultBlock(UIBackgroundFetchResultFailed);
            }
            return;
        }
        NSURL *folderURL = [response.URL URLByDeletingLastPathComponent];
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
        NSString *key = @(updateInfo.dataType).description;
        __block BRCUpdateInfo *oldUpdateInfo = nil;
        [self.readWriteConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
            oldUpdateInfo = [transaction objectForKey:key inCollection:[BRCUpdateInfo yapCollection]];
        }];
        
        if (oldUpdateInfo) {
            NSTimeInterval intervalSinceLastUpdated = [updateInfo.lastUpdated timeIntervalSinceDate:oldUpdateInfo.lastUpdated];
            if (intervalSinceLastUpdated <= 0) {
                // already updated, skip update
                return;
            }
        }
        // We've got some new data!
        fetchResult = UIBackgroundFetchResultNewData;
        NSURL *dataURL = [folderURL URLByAppendingPathComponent:updateInfo.fileName];
        NSURLSessionDownloadTask *downloadTask = [self.urlSession downloadTaskWithURL:dataURL];
        [downloadTask resume];
        
        [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
            [transaction setObject:updateInfo forKey:key inCollection:[BRCUpdateInfo yapCollection]];
        }];
    }];
    if (fetchResultBlock) {
        fetchResultBlock(fetchResult);
    }
}

- (BOOL) loadDataFromJSONData:(NSData*)jsonData
                    dataClass:(Class)dataClass
                        error:(NSError**)error {
    NSAssert([NSThread currentThread] != [NSThread mainThread], @"Do not call from main thread!");
    NSParameterAssert(jsonData != nil);
    NSArray *jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    if (*error) {
        return NO;
    }
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:jsonObjects.count];
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
    [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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
    }];
    return YES;
}

/** Set this when app is launched from background via application:handleEventsForBackgroundURLSession:completionHandler: */
- (void) addBackgroundURLSessionCompletionHandler:(void (^)())completionHandler {
    self.urlSessionCompletionHandler = completionHandler;
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
    NSString *fileName = [downloadTask.response.URL lastPathComponent];
    // We should have a better way of detecting the data type
    Class dataClass = nil;
    if ([fileName containsString:@"art"]) {
        dataClass = [BRCArtObject class];
    } else if ([fileName containsString:@"camps"]) {
        dataClass = [BRCCampObject class];
    } else if ([fileName containsString:@"events"]) {
        dataClass = [BRCEventObject class];
    } else if ([fileName containsString:@"mbtiles"]) {
#warning update tiles
        // TODO update tiles
    }
    
    if (dataClass) {
        NSData *jsonData = [[NSData alloc] initWithContentsOfURL:location];
        [self.updateQueue addOperationWithBlock:^{
            NSError *error = nil;
            BOOL success = [self loadDataFromJSONData:jsonData dataClass:dataClass error:&error];
            if (!success) {
                NSLog(@"Error loading JSON for %@: %@", NSStringFromClass(dataClass), error);
            }
        }];
    }
    
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
