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
@import PureLayout;

@interface BRCBaseMapViewController()
@property (nonatomic, strong, readonly) id<MGLMapViewDelegate> annotationDelegate;
@end

@implementation BRCBaseMapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupMapView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapTilesUpdated:) name:BRCDataImporterMapTilesUpdatedNotification object:nil];
}

- (void) setupMapView {
    self.mapView = [[MGLMapView alloc] init];
    [self.mapView brc_setDefaults];
    _annotationDelegate = [[MapViewAdapter alloc] init];
    self.mapView.delegate = self.annotationDelegate;
    [self.view addSubview:self.mapView];
    [self.mapView autoPinEdgesToSuperviewEdges];
    [self.view sendSubviewToBack:self.mapView];
    [self centerMapAtManCoordinatesAnimated:NO];
    BRCUserTrackingBarButtonItem *userTrackingBarButtonItem = [[BRCUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    self.navigationItem.rightBarButtonItem = userTrackingBarButtonItem;
}

- (void) mapTilesUpdated:(NSNotification*)notification {
    NSLog(@"Replacing map tiles via notification...");
    // TODO: figure out how to properly refresh tiles
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
