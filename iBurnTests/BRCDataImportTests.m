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

@interface BRCDataImportTests : XCTestCase
@property (nonatomic, strong, readonly) BRCDataImporter *importer;
@property (nonatomic, strong, readonly) YapDatabase *database;
@property (nonatomic, strong, readonly) YapDatabaseConnection *connection;
@property (nonatomic, strong, readonly) XCTestExpectation *expectation;
@end

@implementation BRCDataImportTests

#pragma mark Setup / Teardown

- (void)setUp {
    [super setUp];
    NSString *tmpDbPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"db.sqlite"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpDbPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpDbPath error:nil];
    }
    _database = [[YapDatabase alloc] initWithPath:tmpDbPath];
    XCTAssertNotNil(self.database);
    _connection = [self.database newConnection];
    XCTAssertNotNil(self.connection);
    [self setupDataImporterWithConnection:self.connection sessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
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
    _database = nil;
    _importer = nil;
    [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];
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

- (void)testLoadUpdates {
    _expectation = [self expectationWithDescription:@"load updates"];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *initialDataPath = [bundle pathForResource:@"update.json" ofType:@"js" inDirectory:@"initial_data"];
    NSURL *initialUpdateURL = [NSURL fileURLWithPath:initialDataPath];
    XCTAssertNotNil(initialUpdateURL);
    
    NSString *updatedDataPath = [bundle pathForResource:@"update.json" ofType:@"js" inDirectory:@"updated_data"];
    NSURL *updatedURL = [NSURL fileURLWithPath:updatedDataPath];
    XCTAssertNotNil(updatedURL);
    
    [self.importer loadUpdatesFromURL:initialUpdateURL  completionBlock:^(UIBackgroundFetchResult fetchResult, NSError *error) {
        XCTAssert(fetchResult == UIBackgroundFetchResultNewData);
        XCTAssertNil(error);
        NSLog(@"**** First update...");
        [self printCollectionInfo];
        [self.importer loadUpdatesFromURL:initialUpdateURL  completionBlock:^(UIBackgroundFetchResult fetchResult, NSError *error) {
            XCTAssert(fetchResult == UIBackgroundFetchResultNoData);
            XCTAssertNil(error);
            NSLog(@"**** Second update (dupe)...");
            [self printCollectionInfo];
            [self.importer loadUpdatesFromURL:updatedURL  completionBlock:^(UIBackgroundFetchResult fetchResult, NSError *error) {
                XCTAssertNil(error);
                XCTAssert(fetchResult == UIBackgroundFetchResultNewData);
                NSLog(@"**** Third update...");
                [self printCollectionInfo];
                [self.expectation fulfill];
            }];
        }];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Error: %@", error);
        }
    }];
}

#pragma mark Utility

- (void) printCollectionInfo {
    [self.connection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        [transaction enumerateCollectionsUsingBlock:^(NSString * __nonnull collection, BOOL * __nonnull stop) {
            NSUInteger keyCount = [transaction numberOfKeysInCollection:collection];
            NSLog(@"%@: %d", collection, (int)keyCount);
        }];
    }];
}

@end
