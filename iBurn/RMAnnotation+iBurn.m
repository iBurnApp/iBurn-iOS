//
//  RMAnnotation+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "RMAnnotation+iBurn.h"

@implementation RMAnnotation (iBurn)

+ (instancetype) brc_annotationWithMapView:(RMMapView*)mapView dataObject:(BRCDataObject*)dataObject {
    if (!dataObject.location) {
        return nil;
    }
    RMAnnotation *annotation =  [[RMAnnotation alloc] initWithMapView:mapView coordinate:dataObject.location.coordinate andTitle:dataObject.title];
    annotation.userInfo = dataObject;
    return annotation;
}

+ (instancetype) brc_annotationWithMapView:(RMMapView*)mapView mapPoint:(BRCMapPoint*)mapPoint {
    NSString *title = nil;
    if (mapPoint.title.length) {
        title = mapPoint.title;
    } else {
        title = @"No Title";
    }
    RMAnnotation *annotation = [[RMAnnotation alloc] initWithMapView:mapView coordinate:mapPoint.coordinate andTitle:title];
    annotation.userInfo = mapPoint;
    return annotation;
}

@end
