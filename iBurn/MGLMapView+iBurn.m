//
//  RMMapView+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "MGLMapView+iBurn.h"
#import "BRCLocations.h"
#import "BRCDataImporter.h"
#import "BRCSecrets.h"
#import "UIColor+iBurn.h"

@implementation MGLMapView (iBurn)

+ (MGLCoordinateBounds) brc_bounds {
    CLLocationCoordinate2D sw = CLLocationCoordinate2DMake(40.7413, -119.267);
    CLLocationCoordinate2D ne = CLLocationCoordinate2DMake(40.8365, -119.1465);
    return MGLCoordinateBoundsMake(sw, ne);
}

- (void)brc_zoomToFullTileSourceAnimated:(BOOL)animated
{
    MGLCoordinateBounds bounds = MGLMapView.brc_bounds;
    [self setVisibleCoordinateBounds:bounds animated:animated];
}

- (void)brc_moveToBlackRockCityCenterAnimated:(BOOL)animated
{
    CLLocationCoordinate2D blackRockCityCenter = [BRCLocations blackRockCityCenter];
    [self setCenterCoordinate:blackRockCityCenter animated:animated];
}

+ (instancetype)brc_defaultMapViewWithFrame:(CGRect)frame
{
    MGLMapView *mapView = [[MGLMapView alloc] initWithFrame:frame];
    mapView.styleURL = [NSURL URLWithString:kBRCMapBoxStyleURL];
    mapView.showsUserLocation = YES;
    mapView.minimumZoomLevel = 13;
    mapView.backgroundColor = UIColor.brc_mapBackgroundColor;
    
    return mapView;
}

@end
