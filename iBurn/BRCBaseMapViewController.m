//
//  BRCBaseMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCBaseMapViewController.h"
#import "RMMapView+iBurn.h"
#import <Mapbox_iOS_SDK/Mapbox.h>
#import "RMAnnotation+iBurn.h"
#import "BRCDataObject.h"
#import "RMMarker+iBurn.h"
#import "BRCEmbargo.h"
#import "BRCDataImporter.h"

@implementation BRCBaseMapViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupMapView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapTilesUpdated:) name:BRCDataImporterMapTilesUpdatedNotification object:nil];
}

- (void) setupMapView {
    self.mapView = [RMMapView brc_defaultMapViewWithFrame:self.view.bounds];
    self.mapView.delegate = self;
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.mapView];
    [self.view sendSubviewToBack:self.mapView];
    [self centerMapAtManCoordinatesAnimated:NO];
    RMUserTrackingBarButtonItem *userTrackingBarButtonItem = [[RMUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
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

#pragma - mark RMMapViewDelegate Methods

- (RMMapLayer*) mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
    if (annotation.isUserLocationAnnotation) { // show default style
        return nil;
    }
    if ([annotation.userInfo isKindOfClass:[BRCDataObject class]]) {
        BRCDataObject *dataObject = annotation.userInfo;
        
        if ([BRCEmbargo canShowLocationForObject:dataObject]) {
            return [RMMarker brc_defaultMarkerForDataObject:dataObject];
        }
    }
    return nil;
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
