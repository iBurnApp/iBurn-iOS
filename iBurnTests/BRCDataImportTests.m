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
    // TODO
    // 1. set up test database
    // 2. populate db with test data
    // 3. mock HTTP requests
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
    [[NSFileManager defaultManager] removeItemAtPath:self.database.databasePath error:nil];
    [super tearDown];
}

#pragma mark Tests

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
        
        NSDate *lastUpdated = [NSDate date];
        [self.importer loadUpdatesFromURL:updatedURL  completionBlock:^(UIBackgroundFetchResult fetchResult, NSError *error) {
            XCTAssertNil(error);
            XCTAssert(fetchResult == UIBackgroundFetchResultNewData);
            [self.expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Error: %@", error);
        }
    }];
}


@end
