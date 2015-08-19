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
#import "BRCGeocoder.h"
#import "BRCMapPoint.h"

NSString * const BRCDataImporterMapTilesUpdatedNotification = @"BRCDataImporterMapTilesUpdatedNotification";
static NSString * const kBRCTilesName =  @"iburn.mbtiles";

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
        NSParameterAssert(updateInfo.lastUpdated != nil);
        NSParameterAssert(updateInfo.fileName != nil);
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
            // check tiles for errors
            if (oldUpdateInfo.dataType == BRCUpdateDataTypeTiles) {
                oldUpdateInfo = [oldUpdateInfo copy];
                [self doubleCheckMapTiles:oldUpdateInfo];
            }
            NSTimeInterval intervalSinceLastUpdated = [updateInfo.lastUpdated timeIntervalSinceDate:oldUpdateInfo.lastUpdated];
            if (intervalSinceLastUpdated <= 0 && oldUpdateInfo.fetchStatus != BRCUpdateFetchStatusFailed) {
                // already updated, skip update
                if (oldUpdateInfo.fetchStatus == BRCUpdateFetchStatusComplete) {
                    return;
                } else if (oldUpdateInfo.fetchStatus == BRCUpdateFetchStatusFetching) {
                    NSTimeInterval intervalSinceLastFetched = [[NSDate date] timeIntervalSinceDate:updateInfo.fetchDate];
                    // only re-fetch if fetch takes longer than 5 minutes
                    if (intervalSinceLastFetched <= 5 * 60) {
                        return;
                    }
                }
            }
        }
        // We've got some new data!
        updateInfo.fetchStatus = BRCUpdateFetchStatusFetching;
        updateInfo.fetchDate = [NSDate date];
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
                   updateInfo:(BRCUpdateInfo*)updateInfo
                        error:(NSError**)error {
    NSParameterAssert(jsonData != nil);
    id jsonObjects = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    if (*error) {
        return NO;
    }
    NSMutableArray *objects = [NSMutableArray array];
   
    void (^parseBlock)(id jsonObject) = ^void(id jsonObject){
        if ([jsonObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *jsonDictionary = jsonObject;
            NSError *parseError = nil;
            id object = [MTLJSONAdapter modelOfClass:dataClass fromJSONDictionary:jsonDictionary error:&parseError];
            if (object) {
                [objects addObject:object];
            } else if (parseError) {
#warning There will be missing items due to JSON parsing errors
                NSLog(@"Error parsing JSON: %@ %@", jsonDictionary, parseError);
            }
        }
    };
    
    if ([jsonObjects isKindOfClass:[NSArray class]]) {
        NSArray *jsonArray = jsonObjects;
        // kludge to fix accidental usage of wrong event object type
        if (dataClass == [BRCEventObject class]) {
            dataClass = [BRCRecurringEventObject class];
        }
        
        [jsonArray enumerateObjectsUsingBlock:^(id jsonObject, NSUInteger idx, BOOL *stop) {
            parseBlock(jsonObject);
        }];
    } else if ([jsonObjects isKindOfClass:[NSDictionary class]]) {
        NSDictionary *jsonDictionary = jsonObjects;
        // this is GeoJSON for BRCMapPoints
        NSArray *features = jsonDictionary[@"features"];
        if (features && [features isKindOfClass:[NSArray class]]) {
            [features enumerateObjectsUsingBlock:^(id jsonObject, NSUInteger idx, BOOL *features) {
                parseBlock(jsonObject);
            }];
        }
        [jsonDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            parseBlock(obj);
        }];
    }
    
    NSLog(@"About to load %d %@ objects.", (int)objects.count, NSStringFromClass(dataClass));
    
    // We've got some map points, dump the old map points,
    // deal with them and return
    if ([dataClass isSubclassOfClass:[BRCMapPoint class]]) {
        [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
            [transaction removeAllObjectsInCollection:[BRCMapPoint collection]]; // remove non-user generated map points
            [objects enumerateObjectsUsingBlock:^(BRCMapPoint *mapPoint, NSUInteger idx, BOOL *stop) {
                [transaction setObject:mapPoint forKey:mapPoint.uuid inCollection:[[mapPoint class] collection]];
                updateInfo.fetchStatus = BRCUpdateFetchStatusComplete;
                [transaction setObject:updateInfo forKey:updateInfo.yapKey inCollection:[BRCUpdateInfo yapCollection]];
            }];
        }];
        if (objects.count > 0) {
            return YES;
        } else {
            return NO;
        }
    }
    
    // Remove me!
#warning Remove me when playa location data is fixed
    BRCGeocoder *geocoder = [BRCGeocoder sharedInstance];
    
    [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        // Update Fetch info status
        NSParameterAssert(updateInfo != nil);
        if (!updateInfo) {
            NSLog(@"Couldn't find updateInfo for %@", NSStringFromClass(dataClass));
            return;
        }
        [objects enumerateObjectsUsingBlock:^(BRCDataObject *object, NSUInteger idx, BOOL *stop) {
            @autoreleasepool {
                ////////////////
#warning Remove me when playa location data is fixed
                if (object.location && !object.playaLocation) {
                    NSString *playaLocation = [geocoder reverseLookup:object.location.coordinate];
                    if (playaLocation.length > 0) {
                        object.playaLocation = playaLocation;
                    }
                }
                ///////////////
                
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
                        event.lastUpdated = updateInfo.lastUpdated;
                        [transaction setObject:event forKey:event.uniqueID inCollection:[[event class] collection]];
                    }];
                } else { // Art and Camps
                    BRCDataObject *existingObject = [transaction objectForKey:object.uniqueID inCollection:[dataClass collection]];
                    if (existingObject) {
                        existingObject = [existingObject copy];
                        [existingObject mergeValuesForKeysFromModel:object];
                        object = existingObject;
                    }
                    object.lastUpdated = updateInfo.lastUpdated;
                    [transaction setObject:object forKey:object.uniqueID inCollection:[dataClass collection]];
                }
            }
        }];
        updateInfo.fetchStatus = BRCUpdateFetchStatusComplete;
        [transaction setObject:updateInfo forKey:updateInfo.yapKey inCollection:[BRCUpdateInfo yapCollection]];
    }];
    
#warning Remove me when the source data is fixed?
    ////////////// Data massaging
    NSMutableArray *objectsToUpdate = [NSMutableArray array];
    [self.readWriteConnection readWithBlock:^(YapDatabaseReadTransaction * transaction) {
        [transaction enumerateKeysAndObjectsInCollection:[BRCEventObject collection] usingBlock:^(NSString *key, id object, BOOL *stop) {
            if ([object isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event = [object copy];
                __block BRCCampObject *camp = nil;
                __block BRCArtObject *art = nil;
                camp = [event hostedByCampWithTransaction:transaction];
                art = [event hostedByArtWithTransaction:transaction];
                if (camp) {
                    event.campName = camp.title;
                    event.coordinate = camp.coordinate;
                }
                if (art) {
                    event.artName = art.title;
                    event.coordinate = art.coordinate;
                }
                [objectsToUpdate addObject:event];
            }
        }];
    }];
    [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
        [objectsToUpdate enumerateObjectsUsingBlock:^(BRCDataObject *object, NSUInteger idx, BOOL *stop) {
            [transaction setObject:object forKey:object.uniqueID inCollection:[[object class] collection]];
        }];
    }];
    ///////////////////////////
    return YES;
}

/** Set this when app is launched from background via application:handleEventsForBackgroundURLSession:completionHandler: */
- (void) addBackgroundURLSessionCompletionHandler:(void (^)())completionHandler {
    self.urlSessionCompletionHandler = completionHandler;
}

/** Verify tiles are OK */
- (BOOL) checkTilesAtURL:(NSURL*)tilesURL error:(NSError**)error {
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:tilesURL.path error:error];
    unsigned long long fileSize = [fileAttributes fileSize];
    if (*error) {
        return NO;
    } else if (fileSize < 5) { // test tile is 4 bytes
        if (error) {
            *error = [NSError errorWithDomain:@"tiles fetch error" code:1 userInfo:@{NSLocalizedDescriptionKey: @"tiles fetch error"}];
        }
        return NO;
    }
    return YES;
}

- (void) loadDataFromLocalURL:(NSURL*)localURL updateInfo:(BRCUpdateInfo*)updateInfo {
    
    Class dataClass = updateInfo.dataObjectClass;
    if (dataClass) {
        NSData *jsonData = [[NSData alloc] initWithContentsOfURL:localURL];
        [self.updateQueue addOperationWithBlock:^{
            NSError *error = nil;
            BOOL success = [self loadDataFromJSONData:jsonData
                                            dataClass:dataClass
                                           updateInfo:updateInfo
                                                error:&error];
            if (!success) {
                NSLog(@"Error loading JSON for %@: %@", NSStringFromClass(dataClass), error);
                updateInfo.fetchStatus = BRCUpdateFetchStatusFailed;
                [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
                    [transaction setObject:updateInfo forKey:updateInfo.yapKey inCollection:[BRCUpdateInfo yapCollection]];
                }];
            }
        }];
    } else if (updateInfo.dataType == BRCUpdateDataTypeTiles) {
        NSError *error = nil;
        NSURL *destinationURL = [[self class] mapTilesURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path isDirectory:NULL]) {
            NSLog(@"Existing files found, deleting...");
            [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:&error];
            if (error) {
                NSLog(@"Error removing item at URL: %@ %@", destinationURL, error);
                error = nil;
            }
        }
        BOOL success = [self checkTilesAtURL:localURL error:&error];
        if (success) {
            [[NSFileManager defaultManager] copyItemAtURL:localURL toURL:destinationURL error:&error];
        }
        if (error) {
            NSLog(@"Error updating tiles: %@", error);
            updateInfo.fetchStatus = BRCUpdateFetchStatusFailed;
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:BRCDataImporterMapTilesUpdatedNotification object:self userInfo:@{@"url": destinationURL}];
            });
            NSLog(@"Tiles updated: %@", destinationURL);
            NSError *error = nil;
            BOOL success = [destinationURL setResourceValue:@YES forKey: NSURLIsExcludedFromBackupKey error:&error];
            if (!success) {
                NSLog(@"Error excluding %@ from backup %@", destinationURL, error);
            }
            updateInfo.fetchStatus = BRCUpdateFetchStatusComplete;
        }
        [self.readWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
            [transaction setObject:updateInfo forKey:updateInfo.yapKey inCollection:[BRCUpdateInfo yapCollection]];
        }];
    }
}


/** Returns iburn.mbtiles local file URL within Application Support */
+ (NSURL*) mapTilesURL {
    NSString *fileName = kBRCTilesName;
    NSString *mapTilesDestinationPath = [[self mapTilesDirectory] stringByAppendingPathComponent:fileName];
    NSURL *destinationURL = [NSURL fileURLWithPath:mapTilesDestinationPath];
    return destinationURL;
}

+ (NSString *) mapTilesDirectory {
    NSString *applicationSupportDirectory = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *directory = [applicationSupportDirectory stringByAppendingPathComponent:applicationName];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:directory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Error creating containing directory %@", error);
            error = nil;
        }
    }
    return directory;
}


/** Double-checks that the map tiles exist on each launch */
- (void) doubleCheckMapTiles:(BRCUpdateInfo*)updateInfo {
    NSError *error = nil;
    NSURL *localMapTilesURL = [[self class] mapTilesURL];
    BOOL success = [self checkTilesAtURL:localMapTilesURL error:&error];
    if (!success) {
        NSLog(@"Look like the tiles are fucked: %@", error);
        error = nil;
        // copy bundled tiles to live store on first launch
        NSString *bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"2015"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSURL *bundledTilesURL = [bundle URLForResource:kBRCTilesName withExtension:@"jar"];
        success = [[NSFileManager defaultManager] copyItemAtURL:bundledTilesURL toURL:localMapTilesURL error:&error];
        if (!success) {
            if (updateInfo) {
                updateInfo.fetchStatus = BRCUpdateFetchStatusFailed;
            }
        } else {
            NSLog(@"Copied bundled tiles to live store: %@ -> %@", bundledTilesURL, localMapTilesURL);
            if (updateInfo) {
                updateInfo.fetchStatus = BRCUpdateFetchStatusComplete;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:BRCDataImporterMapTilesUpdatedNotification object:self userInfo:@{@"url": localMapTilesURL}];
            });
            NSError *error = nil;
            BOOL success = [localMapTilesURL setResourceValue:@YES forKey: NSURLIsExcludedFromBackupKey error:&error];
            if (!success) {
                NSLog(@"Error excluding %@ from backup %@", localMapTilesURL, error);
            }
        }
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

#pragma mark Testing

/** Do not call outside of tests */
- (void) waitForDataUpdatesToFinish {
    [self.updateQueue waitUntilAllOperationsAreFinished];
}

@end
