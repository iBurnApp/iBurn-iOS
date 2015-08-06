//
//  BRCGeocoderTest.m
//  iBurn
//
//  Created by David Chiles on 8/5/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "BRCGeocoder.h"

@interface BRCGeocoderTest : XCTestCase

@end

@implementation BRCGeocoderTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testReverseGeocoder {
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(40.7901, -119.2199);
    BRCGeocoder *geocoder = [[BRCGeocoder alloc] init];
    XCTAssertNotNil(geocoder);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"reverseGeocoder"];
    
    [geocoder reverseLookup:coordinate completionQueue:nil completion:^(NSString *locationString) {
        XCTAssert([locationString length] > 0, @"No location");
        [expectation fulfill];
    }];
    
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        
    }];
}

- (void)testReverseLookup {
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(40.7901, -119.2199);
    BRCGeocoder *geocoder = [[BRCGeocoder alloc] init];
    
    [self measureBlock:^{
        XCTestExpectation *expectation = [self expectationWithDescription:@"reverseGeocoder"];
        
        [geocoder reverseLookup:coordinate completionQueue:nil completion:^(NSString *locationString) {
            XCTAssert([locationString length] > 0, @"No location");
            [expectation fulfill];
        }];
        
        [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
            
        }];
    }];
}

@end
