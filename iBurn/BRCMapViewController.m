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

@interface BRCMapViewController ()
@property (nonatomic, strong) YapDatabaseConnection *artConnection;
@property (nonatomic, strong) YapDatabaseConnection *eventsConnection;
@property (nonatomic) BOOL currentlyAddingArtAnnotations;
@property (nonatomic) BOOL currentlyAddingEventAnnotations;
@property (nonatomic, strong) NSArray *artAnnotations;
@property (nonatomic, strong) NSArray *eventAnnotations;
@property (nonatomic, strong) NSDate *lastEventAnnotationUpdate;
@end

@implementation BRCMapViewController

- (instancetype) init {
    if (self = [super init]) {
        self.title = @"Map";
        self.artConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        self.eventsConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        [self reloadArtAnnotationsIfNeeded];
        [self reloadEventAnnotationsIfNeeded];
    }
    return self;
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.mapView removeAllAnnotations];
    self.artAnnotations = nil;
    self.eventAnnotations = nil;
    self.lastEventAnnotationUpdate = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadArtAnnotationsIfNeeded];
    [self reloadEventAnnotationsIfNeeded];
}

- (void) reloadArtAnnotationsIfNeeded {
    if (self.artAnnotations || self.currentlyAddingArtAnnotations) {
        return;
    }
    self.currentlyAddingArtAnnotations = YES;
    [self.artConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *artAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:[BRCArtObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCArtObject *artObject = [transaction objectForKey:key inCollection:[BRCArtObject collection]];
            BRCAnnotation *artAnnotation = [BRCAnnotation annotationWithMapView:self.mapView dataObject:artObject];
            // if artObject doesn't have a valid location, annotationWithMapView will
            // return nil for the artAnnotation
            if (artAnnotation) {
                [artAnnotationsToAdd addObject:artAnnotation];
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentlyAddingArtAnnotations = NO;
            self.artAnnotations = artAnnotationsToAdd;
            [self.mapView addAnnotations:artAnnotationsToAdd];
        });
    }];
}

- (void)reloadEventAnnotationsIfNeeded
{
    NSTimeInterval minTimeIntervalForRefresh = 5 * 60; // 5 minutes
    
    if ([[NSDate date] timeIntervalSinceDate:self.lastEventAnnotationUpdate] < minTimeIntervalForRefresh || self.currentlyAddingEventAnnotations) {
        return;
    }
    self.currentlyAddingEventAnnotations = YES;
    [self.mapView removeAnnotations:self.eventAnnotations];
    
    [self.eventsConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *eventAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:[BRCEventObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCEventObject *eventObject = [transaction objectForKey:key inCollection:[BRCEventObject collection]];
            
            //Check if event is currently happening or that the start time is in the next time window
            if([eventObject isOngoing] || [eventObject isStartingSoon]) {
                BRCAnnotation *eventAnnotation = [BRCAnnotation annotationWithMapView:self.mapView dataObject:eventObject];
                
                // if eventObject doesn't have a valid location, annotationWithMapView will
                // return nil for the eventAnnotation
                if (eventAnnotation) {
                    [eventAnnotationsToAdd addObject:eventAnnotation];
                }
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentlyAddingEventAnnotations = NO;
            self.eventAnnotations = eventAnnotationsToAdd;
            [self.mapView addAnnotations:eventAnnotationsToAdd];
        });
    }];
}

- (void)tapOnCalloutAccessoryControl:(UIControl *)control forAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    if ([annotation isKindOfClass:[BRCAnnotation class]]) {
        BRCAnnotation *brcAnnotation = (BRCAnnotation*)annotation;
        BRCDataObject *dataObject = brcAnnotation.dataObject;
        BRCDetailViewController *detailViewController = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
        [self.navigationController pushViewController:detailViewController animated:YES];
    }
}

@end
