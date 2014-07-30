//
//  BRCAnnotation.m
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAnnotation.h"
#import "BRCDataObject.h"

@implementation BRCAnnotation

+ (instancetype)annotationWithMapView:(RMMapView *)aMapView dataObject:(BRCDataObject *)dataObject
{
    BRCAnnotation *annotation = nil;
    if (dataObject.location) {
        annotation = [self annotationWithMapView:aMapView coordinate:dataObject.location.coordinate andTitle:dataObject.title];
        annotation.userInfo = dataObject.uniqueID;
        annotation.annotationType = [[dataObject class] collection];
    }
    
    return annotation;
}

@end
