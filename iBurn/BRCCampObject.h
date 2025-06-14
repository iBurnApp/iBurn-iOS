//
//  BRCCampObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
#import "BRCCampImage.h"

NS_ASSUME_NONNULL_BEGIN
@interface BRCCampObject : BRCDataObject

@property (nonatomic, copy, readonly, nullable) NSString *hometown;
@property (nonatomic, copy, readonly, nullable) NSString *landmark;
@property (nonatomic, copy, readonly, nullable) NSString *frontage;
@property (nonatomic, copy, readonly, nullable) NSString *intersection;
@property (nonatomic, copy, readonly, nullable) NSString *intersectionType;
@property (nonatomic, copy, readonly, nullable) NSString *dimensions;
@property (nonatomic, copy, readonly, nullable) NSString *exactLocation;
@property (nonatomic, copy, readonly, nullable) NSArray<BRCCampImage*> *images;

- (nullable BRCCampMetadata*) campMetadataWithTransaction:(YapDatabaseReadTransaction*)transaction;

@end
NS_ASSUME_NONNULL_END
