//
//  BRCUserMapPoint.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/15/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCMapPoint.h"

NS_ASSUME_NONNULL_BEGIN
@interface BRCUserMapPoint : BRCMapPoint

@property (nonatomic, strong, readwrite, nonnull) NSDate *modifiedDate;

@end
NS_ASSUME_NONNULL_END
