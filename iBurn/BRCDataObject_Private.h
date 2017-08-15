//
//  BRCDataObject_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"

@interface BRCDataObject ()
@property (nonatomic, strong, readwrite) NSString *uniqueID;
+ (NSArray<NSString*>*) excludedPropertyKeysArray;
@end
