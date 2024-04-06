//
//  RMMapView+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "MLNMapView+iBurn.h"
#import "BRCDataImporter.h"
#import "BRCSecrets.h"
#import "UIColor+iBurn.h"
#import "BRCDataObject.h"
#import "BRCEmbargo.h"
#import "iBurn-Swift.h"

@implementation MLNMapView (iBurn)

- (void)brc_showDestinationForDataObject:(BRCDataObject*)dataObject metadata:(nonnull BRCObjectMetadata *)metadata animated:(BOOL)animated padding:(UIEdgeInsets)padding {
    DataObjectAnnotation *annotation = [[DataObjectAnnotation alloc] initWithObject:dataObject metadata:metadata];
    if (!annotation) { return; }
    [self brc_showDestination:annotation animated:animated padding:padding];
}

- (void)brc_showDestination:(id<MLNAnnotation>)destination animated:(BOOL) animated padding:(UIEdgeInsets)padding {
    NSParameterAssert(destination);
    if (!destination) { return; }
    CLLocationCoordinate2D userCoord = [BRCLocations blackRockCityCenter];
    CLLocation *userLocation = self.userLocation.location;
    if (userLocation && CLLocationCoordinate2DIsValid(userLocation.coordinate)) {
        userCoord = userLocation.coordinate;
    }
    
    // Check if user coord is super far away
    CLCircularRegion *burningManRegion = [BRCLocations burningManRegion];
    if (![burningManRegion containsCoordinate:userCoord]) {
        userCoord = [BRCLocations blackRockCityCenter];
    }
    
    CLLocationCoordinate2D destinationCoord = destination.coordinate;
    if (CLLocationCoordinate2DIsValid(destinationCoord)) {
        CLLocationCoordinate2D *coordinates = malloc(sizeof(CLLocationCoordinate2D) * 2);
        coordinates[0] = destinationCoord;
        NSUInteger coordinatesCount = 1;
        coordinates[1] = userCoord;
        coordinatesCount++;
        [self setTargetCoordinate:destinationCoord animated:animated completionHandler:nil];
        [self setVisibleCoordinates:coordinates count:coordinatesCount edgePadding:padding animated:animated];
        free(coordinates);
    } else {
        [self brc_moveToBlackRockCityCenterAnimated:animated];
    }
}

+ (MLNCoordinateBounds) brc_bounds {
    CLLocationCoordinate2D sw = CLLocationCoordinate2DMake(40.7413, -119.267);
    CLLocationCoordinate2D ne = CLLocationCoordinate2DMake(40.8365, -119.1465);
    return MLNCoordinateBoundsMake(sw, ne);
}

- (void)brc_zoomToFullTileSourceAnimated:(BOOL)animated
{
    MLNCoordinateBounds bounds = MLNMapView.brc_bounds;
    [self setVisibleCoordinateBounds:bounds animated:animated];
}

- (void)brc_moveToBlackRockCityCenterAnimated:(BOOL)animated
{
    CLLocationCoordinate2D blackRockCityCenter = [BRCLocations blackRockCityCenter];
    [self setCenterCoordinate:blackRockCityCenter zoomLevel:13.0 animated:animated];
}

@end
