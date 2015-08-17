//
//  BRCDataImportTests.m
//  iBurn
//
//  Created by Christopher Ballinger on 6/27/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "BRCDataImporter.h"
#import "BRCCampObject.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCRecurringEventObject.h"
#import "BRCDataImporter_Private.h"
#import "BRCUpdateInfo.h"
#import "BRCDataImportTests.h"
#import "BRCMapPoint.h"

@implementation BRCDataImportTests

#pragma mark Setup / Teardown

- (void)setUp {
    [super setUp];
    NSString *dbName = [[[NSUUID UUID] UUIDString] stringByAppendingString:@".sqlite"];
    NSString *tmpDbPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dbName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpDbPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpDbPath error:nil];
    }
    _database = [[YapDatabase alloc] initWithPath:tmpDbPath];
    XCTAssertNotNil(self.database);
    _connection = [self.database newConnection];
    XCTAssertNotNil(self.connection);
    [self setupDataImporterWithConnection:self.connection sessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:self.database];
}

- (void) setupDataImporterWithConnection:(YapDatabaseConnection*)connection
                    sessionConfiguration:(NSURLSessionConfiguration*)sessionConfiguration {
    _importer = [[BRCDataImporter alloc] initWithReadWriteConnection:connection sessionConfiguration:sessionConfiguration];
    XCTAssertNotNil(self.importer);
    self.importer.callbackQueue = dispatch_queue_create("data import test queue", 0);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    NSString *dbPath = [self.database.databasePath copy];
    _connection = nil;
    _importer = nil;
    _database = nil;
    [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super tearDown];
}

#pragma mark Tests

// We don't want to overwrite favorites on data update
- (void)testOverwriteFavorites {
    BRCCampObject *camp1 = [[BRCCampObject alloc] init];
    camp1.isFavorite = YES;
    BRCCampObject *camp2 = [camp1 copy];
    camp2.isFavorite = NO;
    [camp1 mergeValuesForKeysFromModel:camp2];
    XCTAssertTrue(camp1.isFavorite);
}

/** update.json URL for updated_data */
+ (NSURL*) testDataURL {
    NSURL *updatedURL = [[self class] testDataURLForDirectory:@"updated_data"];
    return updatedURL;
}

/** update.json URL within initial_data or updated_data */
+ (NSURL*) testDataURLForDirectory:(NSString*)directory {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *initialDataPath = [bundle pathForResource:@"update.json" ofType:@"js" inDirectory:directory];
    NSURL *initialUpdateURL = [NSURL fileURLWithPath:initialDataPath];
    return initialUpdateURL;
}


- (void)testLoadUpdates {
    _expectation = [self expectationWithDescription:@"load updates"];
    NSURL *initialUpdateURL = [[self class] testDataURLForDirectory:@"initial_data"];
    XCTAssertNotNil(initialUpdateURL);
    
    NSURL *updatedURL = [[self class] testDataURLForDirectory:@"updated_data"];
    XCTAssertNotNil(updatedURL);
    
    [self.importer loadUpdatesFromURL:initialUpdateURL fetchResultBlock:^(UIBackgroundFetchResult fetchResult) {
        XCTAssert(fetchResult == UIBackgroundFetchResultNewData);
        NSLog(@"**** First update...");
        [self.importer waitForDataUpdatesToFinish];
        [self.importer loadUpdatesFromURL:initialUpdateURL  fetchResultBlock:^(UIBackgroundFetchResult fetchResult) {
            XCTAssert(fetchResult == UIBackgroundFetchResultNoData);
            NSLog(@"**** Second update (dupe)...");
            [self.importer waitForDataUpdatesToFinish];
            [self.importer loadUpdatesFromURL:updatedURL  fetchResultBlock:^(UIBackgroundFetchResult fetchResult) {
                XCTAssert(fetchResult == UIBackgroundFetchResultNewData);
                NSLog(@"**** Third update...");
                [self.importer waitForDataUpdatesToFinish];
                [self.importer loadUpdatesFromURL:initialUpdateURL  fetchResultBlock:^(UIBackgroundFetchResult fetchResult) {
                    [self.importer waitForDataUpdatesToFinish];
                    XCTAssert(fetchResult == UIBackgroundFetchResultNoData);
                    NSLog(@"**** Fourth update...");
                    [self.expectation fulfill];
                }];
            }];
        }];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Error: %@", error);
        }
    }];
}

- (void) testLoadCamps {
    Class dataClass = [BRCCampObject class];
    [self loadDataFromFile:@"camps.json" dataClass:dataClass];
}

- (void) testLoadEvents {
    Class dataClass = [BRCRecurringEventObject class];
    [self loadDataFromFile:@"events.json" dataClass:dataClass];
    [self.connection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        [transaction enumerateKeysAndObjectsInCollection:[dataClass collection] usingBlock:^(NSString * __nonnull key, BRCEventObject *event, BOOL * __nonnull stop) {
            XCTAssertNotNil(event.startDate);
            XCTAssertNotNil(event.endDate);
        }];
    }];
}

- (void) testLoadArt {
    Class dataClass = [BRCArtObject class];
    [self loadDataFromFile:@"art.json" dataClass:dataClass];
}

- (void) testLoadPoints {
    Class dataClass = [BRCMapPoint class];
    [self loadDataFromFile:@"points.json" dataClass:dataClass];
    [self.connection readWithBlock:^(YapDatabaseReadTransaction * transaction) {
        NSUInteger numObjects = [transaction numberOfKeysInCollection:[dataClass collection]];
        XCTAssert(numObjects == 58);
        [transaction enumerateKeysAndObjectsInCollection:[dataClass collection] usingBlock:^(NSString *key, BRCMapPoint *mapPoint, BOOL *stop) {
            XCTAssert(mapPoint.location != nil);
        }];
    }];
}

- (void) loadDataFromFile:(NSString*)file dataClass:(Class)dataClass {
    BRCUpdateInfo *updateInfo = [[BRCUpdateInfo alloc] init];
    updateInfo.dataType = [BRCUpdateInfo dataTypeForClass:dataClass];
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
        [transaction setObject:updateInfo forKey:updateInfo.yapKey inCollection:[BRCUpdateInfo yapCollection]];
    }];
    NSString *folderName = @"2015";
    NSString *bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folderName];
    NSBundle *dataBundle = [NSBundle bundleWithPath:bundlePath];
    
    NSURL *dataURL = [dataBundle URLForResource:file withExtension:@"js"];
    NSData *jsonData = [[NSData alloc] initWithContentsOfURL:dataURL];
    NSError *error = nil;
    [self.importer loadDataFromJSONData:jsonData dataClass:dataClass updateInfo:updateInfo error:&error];
    XCTAssertNil(error);
    if (dataClass == [BRCRecurringEventObject class]) {
        dataClass = [BRCEventObject class];
    }
    [self.connection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        NSUInteger count = [transaction numberOfKeysInCollection:[dataClass collection]];
        XCTAssert(count > 0, @"Count shouldnt be empty!");
        NSLog(@"Loaded %d %@", (int)count, NSStringFromClass(dataClass));
    }];
}

#pragma mark Utility

- (void) printCollectionInfo {
    [self.connection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        NSUInteger collections = [transaction numberOfCollections];
        XCTAssert(collections > 0, @"Too few collections");
        [transaction enumerateCollectionsUsingBlock:^(NSString * __nonnull collection, BOOL * __nonnull stop) {
            NSUInteger keyCount = [transaction numberOfKeysInCollection:collection];
            NSLog(@"%@: %d", collection, (int)keyCount);
        }];
    }];
}

- (void)yapDatabaseModified:(NSNotification *)notification
{
    //[self printCollectionInfo];
}

@end
