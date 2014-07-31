//
//  RMMarker+iBurn.h
//  iBurn
//
//  Created by David Chiles on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "RMMarker.h"

@class BRCDataObject;

@interface RMMarker (iBurn)


+ (instancetype)brc_defaultMarkerForDataObject:(BRCDataObject *)dataObject;

@end
