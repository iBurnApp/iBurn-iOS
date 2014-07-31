//
//  BRCMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCMapViewController.h"
#import "BRCDatabaseManager.h"
#import "BRCArtObject.h"
#import "BRCMapView.h"
#import "BRCAnnotation.h"
#import "BRCEventObject.h"
#import "BRCDetailViewController.h"

static double const kBRCEventTimeWindow = 60; //minutes

@interface BRCMapViewController ()

@property (nonatomic, strong) YapDatabaseConnection *databaseConnection;

@end

@implementation BRCMapViewController

- (instancetype) init {
    if (self = [super init]) {
        self.title = @"Map";
        self.databaseConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadAnnotations];
}

- (void)reloadAnnotations
{
    [self.mapView removeAllAnnotations];
    //NSMutableArray *artArray = [NSMutableArray new];
    [self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        [transaction enumerateKeysInCollection:[BRCArtObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            __block BRCArtObject *artObject = [transaction objectForKey:key inCollection:[BRCArtObject collection]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.mapView addAnnotation:[BRCAnnotation annotationWithMapView:self.mapView dataObject:artObject]];
            });
        }];
        
        [transaction enumerateKeysInCollection:[BRCEventObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            __block BRCEventObject *eventObject = [transaction objectForKey:key inCollection:[BRCEventObject collection]];
            
            //Check if event is currently happening or that the start time is in the next time window
            if([eventObject isOngoing] || ([eventObject timeIntervalUntilStartDate] < 0 && fabs([eventObject timeIntervalUntilStartDate]) < 60*kBRCEventTimeWindow)) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.mapView addAnnotation:[BRCAnnotation annotationWithMapView:self.mapView dataObject:eventObject]];
                });
            }
        }];
        
        
    }];
}

- (void)tapOnCalloutAccessoryControl:(UIControl *)control forAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    __block BRCDataObject *dataObject = nil;
    [self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        if (annotation.userInfo && annotation.annotationType) {
            dataObject = [transaction objectForKey:annotation.userInfo inCollection:annotation.annotationType];
        }
    } completionBlock:^{
        BRCDetailViewController *detailViewController = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
        [self.navigationController pushViewController:detailViewController animated:YES];
    }];
}

@end
