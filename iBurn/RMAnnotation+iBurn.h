//
//  RMAnnotation+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
#import "BRCMapPoint.h"
@import Mapbox_iOS_SDK;

@interface RMAnnotation (iBurn)

/** will return nil if dataObject has no location */
+ (instancetype) brc_annotationWithMapView:(RMMapView*)mapView dataObject:(BRCDataObject*)dataObject;

+ (instancetype) brc_annotationWithMapView:(RMMapView*)mapView mapPoint:(BRCMapPoint*)mapPoint;


@end
