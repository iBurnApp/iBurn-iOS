//
//  BRCDataObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "MTLModel.h"
#import <CoreLocation/CoreLocation.h>

@interface BRCDataObject : MTLModel

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSString *uniqueID;
@property (nonatomic, strong, readonly) NSString *year;
@property (nonatomic, strong, readonly) NSString *title;

@end
