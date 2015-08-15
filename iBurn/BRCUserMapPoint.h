//
//  BRCUserMapPoint.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/15/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCMapPoint.h"

@interface BRCUserMapPoint : BRCMapPoint

@property (nonatomic, strong, readwrite) NSDate *modifiedDate;

@end
