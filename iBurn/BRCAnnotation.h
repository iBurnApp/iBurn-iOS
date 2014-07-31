//
//  BRCAnnotation.h
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "RMPointAnnotation.h"

@class BRCDataObject;

@interface BRCAnnotation : RMAnnotation


+ (instancetype)annotationWithMapView:(RMMapView *)aMapView dataObject:(BRCDataObject *)dataObject;

@end
