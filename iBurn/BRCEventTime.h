//
//  BRCEventTime.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "MTLModel.h"
#import "MTLJSONAdapter.h"

@interface BRCEventTime : MTLModel <MTLJSONSerializing>

@property (nonatomic, strong, readonly) NSDate *startDate;
@property (nonatomic, strong, readonly) NSDate *endDate;

@end
