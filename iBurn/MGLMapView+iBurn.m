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
#import "BRCDataObject.h"
#import "BRCEmbargo.h"

@implementation MGLMapView (iBurn)

- (void)brc_showDestination:(id<MGLAnnotation>)destination animated:(BOOL) animated {
    NSParameterAssert(destination);
    if (!destination) { return; }
    CLLocation *userLocation = self.userLocation.location;
    CLLocationCoordinate2D destinationCoord = destination.coordinate;
    if ([destination isKindOfClass:[BRCDataObject class]]) {
        BRCDataObject *dataObject = (BRCDataObject*)destination;
        if (![BRCEmbargo canShowLocationForObject:dataObject] ||
            !dataObject.location) {
            destinationCoord = kCLLocationCoordinate2DInvalid;
        }
    }
    if (CLLocationCoordinate2DIsValid(destinationCoord)) {
        CLLocationCoordinate2D *coordinates = malloc(sizeof(CLLocationCoordinate2D) * 2);
        coordinates[0] = destinationCoord;
        NSUInteger coordinatesCount = 1;
        if (userLocation) {
            coordinates[1] = userLocation.coordinate;
            coordinatesCount++;
            [self setCenterCoordinate:userLocation.coordinate animated:animated];
        } else {
            [self setCenterCoordinate:destinationCoord animated:animated];
        }
        [self setTargetCoordinate:destinationCoord animated:animated];
        [self setVisibleCoordinates:coordinates count:coordinatesCount edgePadding:UIEdgeInsetsMake(45, 45, 45, 45) animated:animated];
        free(coordinates);
    } else {
        [self setCenterCoordinate:[BRCLocations blackRockCityCenter] zoomLevel:14.0 animated:animated];
    }
}

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
