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
#import "BRCDataObject+Relationships.h"

@interface BRCDataImportTests()
@property (nonatomic, strong, readonly) NSString *relationshipsName;
@end


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
    
    BOOL success = [self registerRelationships];
    
    XCTAssertTrue(success);
    
    [self setupDataImporterWithConnection:self.connection sessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:self.database];
}

- (BOOL) registerRelationships {
    _relationshipsName = @"relationships";
    BOOL success = [self.database registerExtension:[YapDatabaseRelationship new] withName:self.relationshipsName];
    NSLog(@"Registered %@ %d", _relationshipsName, success);
    return success;
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
        [transaction enumerateKeysAndObjectsInCollection:[dataClass yapCollection] usingBlock:^(NSString * __nonnull key, BRCEventObject *event, BOOL * __nonnull stop) {
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
        NSUInteger numObjects = [transaction numberOfKeysInCollection:[dataClass yapCollection]];
        XCTAssert(numObjects > 0);
        [transaction enumerateKeysAndObjectsInCollection:[dataClass yapCollection] usingBlock:^(NSString *key, BRCMapPoint *mapPoint, BOOL *stop) {
            XCTAssert(mapPoint.location != nil);
        }];
    }];
}

/** Tests whether or not the new data is loaded correctly */
- (void) testUpdateData {
    _expectation = [self expectationWithDescription:@"update data"];
    NSURL *initialUpdateURL = [[self class] testDataURLForDirectory:@"initial_data"];
    XCTAssertNotNil(initialUpdateURL);
    
    NSURL *updatedURL = [[self class] testDataURLForDirectory:@"updated_data"];
    XCTAssertNotNil(updatedURL);
    
    [self.importer loadUpdatesFromURL:initialUpdateURL fetchResultBlock:^(UIBackgroundFetchResult fetchResult) {
        NSLog(@"**** First update...");
        [self.importer waitForDataUpdatesToFinish];
        
        // find something
        
        __block BRCArtObject *art1 = nil;
        __block BRCArtMetadata *artMetadata1 = nil;
        __block BRCCampObject *camp1 = nil;
        __block BRCCampMetadata *campMetadata1 = nil;
        __block NSArray<BRCEventObject*> *events1 = nil;
        
        [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
            art1 = [transaction objectForKey:@"a2I0V000001RLHeUAO" inCollection:[BRCArtObject yapCollection]];
            camp1 = [transaction objectForKey:@"a1X0V000003WK4xUAG" inCollection:[BRCCampObject yapCollection]];
            
            artMetadata1.isFavorite = YES;
            campMetadata1.isFavorite = YES;
            
            events1 = [camp1 eventsWithTransaction:transaction];
            
            [events1 enumerateObjectsUsingBlock:^(BRCEventObject *event, NSUInteger idx, BOOL *stop) {
                BRCEventMetadata *metadata = [event eventMetadataWithTransaction:transaction];
                metadata.isFavorite = YES;
                [event saveWithTransaction:transaction metadata:metadata];
            }];
            
            [art1 saveWithTransaction:transaction metadata:artMetadata1];
            [camp1 saveWithTransaction:transaction metadata:campMetadata1];
        }];
        
        XCTAssertNotNil(art1);
        XCTAssertNotNil(camp1);
        
        XCTAssertNil(art1.location);
        XCTAssertNil(camp1.location);
        
        XCTAssertTrue(artMetadata1.isFavorite);
        XCTAssertTrue(campMetadata1.isFavorite);
        
        XCTAssert(events1.count > 0, "No events!");
        
        [events1 enumerateObjectsUsingBlock:^(BRCEventObject *event, NSUInteger idx, BOOL *stop) {
            // XCTAssertTrue(event.isFavorite);
            XCTAssertNil(event.location);
        }];
        
        NSLog(@"initial objects: %@\n%@\n%@", art1, camp1, [events1 firstObject]);
        
        [self.importer loadUpdatesFromURL:updatedURL  fetchResultBlock:^(UIBackgroundFetchResult fetchResult) {
            NSLog(@"**** Second update...");
            [self.importer waitForDataUpdatesToFinish];
            
            // see if it was updated
            
            __block BRCArtObject *art2 = nil;
            __block BRCArtMetadata *artMetadata2 = nil;
            __block BRCCampObject *camp2 = nil;
            __block BRCCampMetadata *campMetadata2 = nil;
            __block NSArray<BRCEventObject*> *events2 = nil;
            
            [self.connection readWithBlock:^(YapDatabaseReadTransaction * transaction) {
                art2 = [transaction objectForKey:@"a2I0V000001RLHeUAO" inCollection:[BRCArtObject yapCollection]];
                artMetadata2 = [art2 artMetadataWithTransaction:transaction];
                camp2 = [transaction objectForKey:@"a1X0V000003WK4xUAG" inCollection:[BRCCampObject yapCollection]];
                campMetadata2 = [camp2 campMetadataWithTransaction:transaction];
                events2 = [camp2 eventsWithTransaction:transaction];
            }];
            
            XCTAssertNotNil(art2);
            XCTAssertNotNil(camp2);
            
            XCTAssertNotNil(art2.location);
            XCTAssertNotNil(camp2.location);
            
            XCTAssertTrue(artMetadata2.isFavorite);
            XCTAssertTrue(campMetadata2.isFavorite);
            
            XCTAssert(events2.count > 0, "No events!");
            
            [events2 enumerateObjectsUsingBlock:^(BRCEventObject *event, NSUInteger idx, BOOL *stop) {
                //XCTAssertTrue(event.isFavorite);
                XCTAssertNotNil(event.location);
            }];

            
            NSLog(@"updated objects: %@\n%@\n%@", art2, camp2, [events2 firstObject]);
            
            [self.expectation fulfill];
        }];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Error: %@", error);
        }
    }];
}

#pragma mark Utility

- (void) loadDataFromFile:(NSString*)file dataClass:(Class)dataClass {
    BRCUpdateInfo *updateInfo = [[BRCUpdateInfo alloc] init];
    updateInfo.dataType = [BRCUpdateInfo dataTypeForClass:dataClass];
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
        [transaction setObject:updateInfo forKey:updateInfo.yapKey inCollection:[BRCUpdateInfo yapCollection]];
    }];
    NSString *folderName = @"2019";
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
        NSUInteger count = [transaction numberOfKeysInCollection:[dataClass yapCollection]];
        XCTAssert(count > 0, @"Count shouldnt be empty!");
        NSLog(@"Loaded %d %@", (int)count, NSStringFromClass(dataClass));
    }];
}


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
