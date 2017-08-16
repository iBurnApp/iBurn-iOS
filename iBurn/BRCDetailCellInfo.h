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
    BRCDetailCellInfoTypePlayaAddress,
    BRCDetailCellInfoTypeSchedule,
    BRCDetailCellInfoTypeDate,
    BRCDetailCellInfoTypeEventRelationship, // for getting events hosted at art/camp
    BRCDetailCellInfoTypeImage,
    BRCDetailCellInfoTypeAudio
};

@class BRCDataObject;

NS_ASSUME_NONNULL_BEGIN
@interface BRCDetailCellInfo : NSObject

@property (nonatomic, strong, readonly) NSString *displayName;
@property (nonatomic, strong, readonly) id value;
@property (nonatomic, readonly) BRCDetailCellInfoType cellType;
/** The keyPath for BRCDataObject for obtaining `value` */
@property (nonatomic, strong, readonly) NSString *key;


+ (NSArray<BRCDetailCellInfo*> *)infoArrayForObject:(BRCDataObject *)object;

@end
NS_ASSUME_NONNULL_END
