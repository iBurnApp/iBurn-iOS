//
//  BRCCreditsInfo.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/9/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

@import Mantle;

@interface BRCCreditsInfo : MTLModel <MTLJSONSerializing>

/** name */
@property (nonatomic, strong, readonly) NSString *name;
/** homepage */
@property (nonatomic, strong, readonly) NSURL *url;
/** description / blurb */
@property (nonatomic, strong, readonly) NSString *blurb;

@end
