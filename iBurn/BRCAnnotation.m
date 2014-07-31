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
#import "BRCEventObject.h"

@interface BRCAnnotation()
@property (nonatomic, strong, readwrite) BRCDataObject *dataObject;
@end

@implementation BRCAnnotation

+ (instancetype)annotationWithMapView:(RMMapView *)aMapView dataObject:(BRCDataObject *)dataObject
{
    BRCAnnotation *annotation = nil;
    if (dataObject.location) {
        annotation = [super annotationWithMapView:aMapView coordinate:dataObject.location.coordinate andTitle:dataObject.title];
        annotation.dataObject = dataObject;
    }
    
    return annotation;
}
@end
