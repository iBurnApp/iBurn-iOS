//
//  BRCMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCMapViewController.h"
#import <Mapbox-iOS-SDK/Mapbox.h>

NSString *const bundledTileSourceName = @"iburn";

@interface BRCMapViewController ()

@property (nonatomic, strong) RMMapView *mapView;

@end

@implementation BRCMapViewController

- (instancetype) init {
    if (self = [super init]) {
        self.title = @"Map";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView = [[RMMapView alloc] initWithFrame:self.view.bounds andTilesource:[self bundledTileSource]];
    self.mapView.adjustTilesForRetinaDisplay = YES;
    self.mapView.hideAttribution = YES;
    self.mapView.showLogoBug = NO;
    self.mapView.showsUserLocation = YES;
    
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.mapView];
    
    RMUserTrackingBarButtonItem *userTrackingBarButtonItem = [[RMUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    self.navigationItem.rightBarButtonItem = userTrackingBarButtonItem;
    
}


- (RMMBTilesSource *)bundledTileSource
{
    return [[RMMBTilesSource alloc] initWithTileSetResource:bundledTileSourceName ofType:@"mbtiles"];
}

@end
