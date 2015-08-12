//
//  BRCDataImportTests.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/11/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

@import UIKit;
@import XCTest;

@interface BRCDataImportTests : XCTestCase
@property (nonatomic, strong, readonly) BRCDataImporter *importer;
@property (nonatomic, strong, readonly) YapDatabase *database;
@property (nonatomic, strong, readonly) YapDatabaseConnection *connection;
@property (nonatomic, strong, readwrite) XCTestExpectation *expectation;

/** update.json URL for updated_data */
+ (NSURL*) testDataURL;
/** update.json URL within initial_data or updated_data */
+ (NSURL*) testDataURLForDirectory:(NSString*)directory;

@end