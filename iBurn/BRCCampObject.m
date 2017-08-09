//
//  BRCCampObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCCampObject.h"

@implementation BRCCampObject
- (BRCObjectMetadata*) metadataWithTransaction:(YapDatabaseReadTransaction*)transaction {
    return [self campMetadataWithTransaction:transaction];
}

- (BRCCampMetadata*) campMetadataWithTransaction:(YapDatabaseReadTransaction*)transaction {
    id metadata = [transaction metadataForKey:self.yapKey inCollection:self.yapCollection];
    if ([metadata isKindOfClass:BRCCampMetadata.class]) {
        return metadata;
    }
    return [BRCCampMetadata new];
}
@end
