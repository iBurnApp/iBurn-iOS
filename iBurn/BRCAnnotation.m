//
//  BRCAnnotation.m
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAnnotation.h"
#import "BRCDataObject.h"
#import "BRCArtObject.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"
#import "RMMarker.h"

@implementation BRCAnnotation

+ (instancetype)annotationWithMapView:(RMMapView *)aMapView dataObject:(BRCDataObject *)dataObject
{
    BRCAnnotation *annotation = nil;
    if (dataObject.location) {
        annotation = [self annotationWithMapView:aMapView coordinate:dataObject.location.coordinate andTitle:dataObject.title];
        annotation.userInfo = dataObject.uniqueID;
        annotation.annotationType = [[dataObject class] collection];
        annotation.layer = [self layerForClass:[dataObject class]];
    }
    
    return annotation;
}

+ (RMMapLayer *)layerForClass:(Class)class
{
    UIColor *tintColor = nil;
    if (class == [BRCArtObject class]) {
        tintColor = [UIColor blueColor];
    }
    else if (class == [BRCEventObject class]) {
        tintColor = [UIColor redColor];
    }
    else if (class == [BRCCampObject class]) {
        tintColor = [UIColor purpleColor];
    }
    
    if (tintColor) {
        return [[RMMarker alloc] initWithMapboxMarkerImage:nil tintColor:tintColor];
    }
    return nil;
}

@end
