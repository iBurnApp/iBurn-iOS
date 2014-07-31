//
//  BRCBaseMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCBaseMapViewController.h"
#import "RMMapView+iBurn.h"
#import <Mapbox-iOS-SDK/Mapbox.h>

@implementation BRCBaseMapViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView = [RMMapView brc_defaultMapViewWithFrame:self.view.bounds];
    self.mapView.delegate = self;
    
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.mapView];
    
    RMUserTrackingBarButtonItem *userTrackingBarButtonItem = [[RMUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    self.navigationItem.rightBarButtonItem = userTrackingBarButtonItem;
    
    [self.mapView brc_zoomToFullTileSourceAnimated:NO];
}

@end
