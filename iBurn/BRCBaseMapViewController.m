//
//  BRCBaseMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCBaseMapViewController.h"
#import "MGLMapView+iBurn.h"
@import Mapbox;
#import "BRCDataObject.h"
#import "BRCEmbargo.h"
#import "BRCDataImporter.h"
#import "iBurn-Swift.h"
#import "BRCUserTrackingBarButtonItem.h"

@interface BRCBaseMapViewController()
@property (nonatomic, strong, readonly) ImageAnnotationDelegate *annotationDelegate;
@end

@implementation BRCBaseMapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupMapView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapTilesUpdated:) name:BRCDataImporterMapTilesUpdatedNotification object:nil];
}

- (void) setupMapView {
    self.mapView = [MGLMapView brc_defaultMapViewWithFrame:self.view.bounds];
    _annotationDelegate = [[ImageAnnotationDelegate alloc] init];
    self.mapView.delegate = self.annotationDelegate;
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.mapView];
    [self.view sendSubviewToBack:self.mapView];
    [self centerMapAtManCoordinatesAnimated:NO];
    BRCUserTrackingBarButtonItem *userTrackingBarButtonItem = [[BRCUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    self.navigationItem.rightBarButtonItem = userTrackingBarButtonItem;
}

- (void) mapTilesUpdated:(NSNotification*)notification {
    NSLog(@"Replacing map tiles via notification...");
    if (self.mapView) {
        [self.mapView removeFromSuperview];
        self.mapView = nil;
    }
    [self setupMapView];
}

- (void) centerMapAtManCoordinatesAnimated:(BOOL)animated {
    NSParameterAssert(self.mapView != nil);
    if (!self.mapView) {
        return;
    }
    [self.mapView brc_zoomToFullTileSourceAnimated:animated];
    [self.mapView brc_moveToBlackRockCityCenterAnimated:animated];
}

@end
