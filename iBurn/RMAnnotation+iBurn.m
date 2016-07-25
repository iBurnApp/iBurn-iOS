//
//  RMAnnotation+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "RMAnnotation+iBurn.h"
#import "BRCUserMapPoint.h"
#import <Mapbox_iOS_SDK/Mapbox.h>

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
    NSParameterAssert(mapPoint != nil);
    if (!mapPoint) {
        return nil;
    }
    NSString *title = nil;
    if (mapPoint.title.length) {
        title = mapPoint.title;
    } else {
        title = @"Saved Pin";
    }
    RMAnnotation *annotation = [[RMAnnotation alloc] initWithMapView:mapView coordinate:mapPoint.coordinate andTitle:title];
    annotation.userInfo = mapPoint;
    
    UIImage *customImage = nil;
    if ([mapPoint isKindOfClass:[BRCUserMapPoint class]]) {
        BRCUserMapPoint *userPoint = (BRCUserMapPoint*)mapPoint;
        if (userPoint.type == BRCMapPointTypeUserBike) {
            customImage = [UIImage imageNamed:@"BRCUserPinBike"];
        } else if (userPoint.type == BRCMapPointTypeUserHome) {
            customImage = [UIImage imageNamed:@"BRCUserPinHome"];
        } else if (userPoint.type == BRCMapPointTypeUserStar) {
            customImage = [UIImage imageNamed:@"BRCUserPinStar"];
        } else { // default to star
            customImage = [UIImage imageNamed:@"BRCUserPinStar"];
        }
    }
    if (customImage) {
        annotation.annotationIcon = customImage;
    }
    
    return annotation;
}

@end
