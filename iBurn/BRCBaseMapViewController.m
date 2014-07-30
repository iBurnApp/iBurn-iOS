//
//  BRCBaseMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCBaseMapViewController.h"
#import "BRCMapView.h"
#import <Mapbox-iOS-SDK/Mapbox.h>

@implementation BRCBaseMapViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView = [BRCMapView defaultMapViewWithFrame:self.view.bounds];
    self.mapView.delegate = self;
    
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.mapView];
    
    RMUserTrackingBarButtonItem *userTrackingBarButtonItem = [[RMUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    self.navigationItem.rightBarButtonItem = userTrackingBarButtonItem;
    
    [self.mapView zoomToFullTileSourceAnimated:NO];
}

@end
