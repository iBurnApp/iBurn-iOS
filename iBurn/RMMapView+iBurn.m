//
//  RMMapView+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "RMMapView+iBurn.h"
#import "RMMBTilesSource.h"
#import "BRCLocations.h"

static NSString *const kBRCBundledTileSourceName = @"iburn";

@implementation RMMapView (iBurn)

- (void)brc_zoomToFullTileSourceAnimated:(BOOL)animated
{
    RMSphericalTrapezium bounds = [self.tileSource latitudeLongitudeBoundingBox];
    [self zoomWithLatitudeLongitudeBoundsSouthWest:bounds.southWest northEast:bounds.northEast animated:animated];
}

- (void)brc_moveToBlackRockCityCenterAnimated:(BOOL)animated
{
    CLLocationCoordinate2D blackRockCityCenter = [BRCLocations blackRockCityCenter];
    [self setCenterCoordinate:blackRockCityCenter animated:animated];
}

- (void)brc_zoomToIncludeCoordinate:(CLLocationCoordinate2D)coordinate1 andCoordinate:(CLLocationCoordinate2D)coordinate2 inVisibleRect:(CGRect)visibleRect animated:(BOOL)animated
{
    BOOL coordinate1InBounds = [[self class] isCoordinate:coordinate1 inBounds:[self.tileSource latitudeLongitudeBoundingBox]];
    BOOL coordinate2InBounds = [[self class] isCoordinate:coordinate2 inBounds:[self.tileSource latitudeLongitudeBoundingBox]];
    
    if (coordinate1InBounds && coordinate2InBounds) {
        CLLocationDegrees minLatitude = MIN(coordinate1.latitude, coordinate2.latitude);
        CLLocationDegrees maxLatitude = MAX(coordinate1.latitude, coordinate2.longitude);
        CLLocationDegrees minLongitude = MIN(coordinate1.longitude, coordinate2.longitude);
        CLLocationDegrees maxLongitude = MAX(coordinate1.longitude, coordinate2.longitude);
        
        CLLocationCoordinate2D southWest = CLLocationCoordinate2DMake(minLatitude, minLongitude);
        CLLocationCoordinate2D northEast = CLLocationCoordinate2DMake(maxLatitude, maxLongitude);
        
        [self brc_zoomWithLatitudeLongitudeBoundsSouthWest:southWest northEast:northEast inVisibleRect:visibleRect animated:animated];
        [self zoomOutToNextNativeZoomAt:self.center animated:animated];
    }
    else if (coordinate1InBounds)
    {
        [self setCenterCoordinate:coordinate1 animated:animated];
    }
    else if (coordinate2InBounds)
    {
        [self setCenterCoordinate:coordinate2 animated:animated];
    }
    
}

- (void)brc_zoomWithLatitudeLongitudeBoundsSouthWest:(CLLocationCoordinate2D)southWest northEast:(CLLocationCoordinate2D)northEast inVisibleRect:(CGRect)visibleRect animated:(BOOL)animated
{
    if (northEast.latitude == southWest.latitude && northEast.longitude == southWest.longitude) // There are no bounds, probably only one marker.
    {
        RMProjectedRect zoomRect;
        RMProjectedPoint myOrigin = [self.projection coordinateToProjectedPoint:southWest];
        
        // Default is with scale = 2.0 * mercators/pixel
        zoomRect.size.width = visibleRect.size.width * 2.0;
        zoomRect.size.height = visibleRect.size.height * 2.0;
        myOrigin.x = myOrigin.x - (zoomRect.size.width / 2.0);
        myOrigin.y = myOrigin.y - (zoomRect.size.height / 2.0);
        zoomRect.origin = myOrigin;
        
        [self setProjectedBounds:zoomRect animated:animated];
    }
    else
    {
        // Convert northEast/southWest into RMMercatorRect and call zoomWithBounds
        CLLocationCoordinate2D midpoint = {
            .latitude = (northEast.latitude + southWest.latitude) / 2,
            .longitude = (northEast.longitude + southWest.longitude) / 2
        };
        
        RMProjectedPoint myOrigin = [self.projection coordinateToProjectedPoint:midpoint];
        RMProjectedPoint southWestPoint = [self.projection coordinateToProjectedPoint:southWest];
        RMProjectedPoint northEastPoint = [self.projection coordinateToProjectedPoint:northEast];
        RMProjectedPoint myPoint = {
            .x = northEastPoint.x - southWestPoint.x,
            .y = northEastPoint.y - southWestPoint.y
        };
        
		// Create the new zoom layout
        RMProjectedRect zoomRect;
        
        // Default is with scale = 2.0 * mercators/pixel
        zoomRect.size.width = visibleRect.size.width * 2.0;
        zoomRect.size.height = visibleRect.size.height * 2.0;
        
        if ((myPoint.x / visibleRect.size.width) < (myPoint.y / visibleRect.size.height))
        {
            if ((myPoint.y / visibleRect.size.height) > 1)
            {
                zoomRect.size.width = visibleRect.size.width * (myPoint.y / visibleRect.size.height);
                zoomRect.size.height = visibleRect.size.height * (myPoint.y / visibleRect.size.height);
            }
        }
        else
        {
            if ((myPoint.x / visibleRect.size.width) > 1)
            {
                zoomRect.size.width = visibleRect.size.width * (myPoint.x / visibleRect.size.width);
                zoomRect.size.height = visibleRect.size.height * (myPoint.x / visibleRect.size.width);
            }
        }
        
        myOrigin.x = myOrigin.x - (zoomRect.size.width / 2);
        myOrigin.y = myOrigin.y - (zoomRect.size.height / 2);
        zoomRect.origin = myOrigin;
        
        [self setProjectedBounds:zoomRect animated:animated];
        [self moveBy:CGSizeMake(visibleRect.origin.x, visibleRect.origin.y)];
    }
}

+ (BOOL)isCoordinate:(CLLocationCoordinate2D)coordinate inBounds:(RMSphericalTrapezium)bounds
{
    if (coordinate.longitude >= bounds.southWest.longitude && coordinate.longitude <= bounds.northEast.longitude && coordinate.latitude >= bounds.southWest.latitude && coordinate.latitude <= bounds.northEast.latitude) {
        return YES;
    }
    return NO;
}


+ (RMMBTilesSource *)brc_defaultTileSource
{
    return [[RMMBTilesSource alloc] initWithTileSetResource:kBRCBundledTileSourceName ofType:@"mbtiles"];
}

+ (instancetype)brc_defaultMapViewWithFrame:(CGRect)frame
{
    RMMapView *mapView = [[RMMapView alloc] initWithFrame:frame andTilesource:[self brc_defaultTileSource]];
    mapView.hideAttribution = YES;
    mapView.showLogoBug = NO;
    mapView.showsUserLocation = YES;
    mapView.minZoom = 13;
    mapView.backgroundColor = [UIColor colorWithRed:232/255.0f green:224/255.0f blue:216/255.0f alpha:1.0f];
    //mapView.clusteringEnabled = YES;
    
    return mapView;
}

@end
