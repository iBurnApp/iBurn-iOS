//
//  BRCArtObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"

@interface BRCArtObject : BRCDataObject

@property (nonatomic, strong, readonly) NSString *artistName;
@property (nonatomic, strong, readonly) NSString *artistLocation;
@property (nonatomic, strong, readonly) NSURL *imageURL;

@end
