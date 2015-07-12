//
//  BRCDetailCellInfo.h
//  iBurn
//
//  Created by David Chiles on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BRCDetailCellInfoType) {
    BRCDetailCellInfoTypeText,
    BRCDetailCellInfoTypeEmail,
    BRCDetailCellInfoTypeURL,
    BRCDetailCellInfoTypeCoordinates,
    BRCDetailCellInfoTypeRelationship,
    BRCDetailCellInfoTypeDistanceFromCurrentLocation,
    BRCDetailCellInfoTypeDistanceFromHomeCamp,
    BRCDetailCellInfoTypeSchedule,
    BRCDetailCellInfoTypeDate
};

@class BRCDataObject;

@interface BRCDetailCellInfo : NSObject

@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) id value;

@property (nonatomic) BRCDetailCellInfoType cellType;


+ (instancetype)detailCellInfoWitDisplayName:(NSString *)displayName value:(NSString *)value;

+ (NSArray *)infoArrayForObject:(BRCDataObject *)object;

@end
