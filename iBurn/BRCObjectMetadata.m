//
//  BRCObjectMetadata.m
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

#import "BRCObjectMetadata.h"

@implementation BRCObjectMetadata
- (instancetype) metadataCopy {
    return [self copy];
}
@end

@implementation BRCEventMetadata
@end

@implementation BRCArtMetadata
@synthesize thumbnailImageColors;
@end

@implementation BRCCampMetadata
@synthesize thumbnailImageColors;
@end
