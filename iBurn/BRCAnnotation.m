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
        annotation.layer = [self layerForDataObject:dataObject];
    }
    
    return annotation;
}

+ (RMMapLayer *)layerForDataObject:(BRCDataObject*)dataObject
{
    UIColor *tintColor = nil;
    Class dataObjectClass = [dataObject class];
    if (dataObjectClass == [BRCArtObject class]) {
        tintColor = [UIColor blueColor];
    }
    else if (dataObjectClass == [BRCEventObject class]) {
        BRCEventObject *eventObject = (BRCEventObject*)dataObject;
        if ([eventObject isEndingSoon]) { // event ending soon
            tintColor = [UIColor orangeColor];
        } else if (![eventObject isOngoing]) { // event has ended
            tintColor = [UIColor redColor];
        } else {
            tintColor = [UIColor greenColor]; // event is still happening for a while
        }
    }
    else if (dataObjectClass == [BRCCampObject class]) {
        tintColor = [UIColor purpleColor];
    }
    
    if (tintColor) {
        RMMarker *marker = [[RMMarker alloc] initWithMapboxMarkerImage:nil tintColor:tintColor];
        marker.canShowCallout = YES;
        marker.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        return marker;
    }
    return nil;
}

@end
