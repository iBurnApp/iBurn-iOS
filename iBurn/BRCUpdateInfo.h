//
//  BRCUpdateInfo.h
//  iBurn
//
//  Created by Christopher Ballinger on 6/28/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import <Mantle/Mantle.h>

/** Metadata parsed from update.json */
@interface BRCUpdateInfo : MTLModel <MTLJSONSerializing>

@property (nonatomic, strong, readonly) NSString *file;
@property (nonatomic, strong, readonly) NSDate *lastUpdated;
@property (nonatomic, strong) NSString *type;

@end
