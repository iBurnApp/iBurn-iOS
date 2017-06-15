//
//  BRCMapPoint.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import Mantle;
@import CoreLocation;
@import Mapbox;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, BRCMapPointType) {
    BRCMapPointTypeUnknown, // turns into -> BRCMapPointTypeUserStar
    BRCMapPointTypeUserBreadcrumb, // for tracking yourself
    BRCMapPointTypeUserHome,
    BRCMapPointTypeUserCamp, // unused
    BRCMapPointTypeUserBike,
    BRCMapPointTypeUserStar,
    BRCMapPointTypeUserHeart, // unused
    BRCMapPointTypeToilet,
    BRCMapPointTypeMedical,
    BRCMapPointTypeRanger
};

/*
 {
 "type": "Feature",
 "geometry": {
 "type": "Point",
 "coordinates": [
 -119.21001900000002,
 40.779943
 ]
 },
 "properties": {
 "name": "First Aid (Main)",
 "ref": "EmergencyClinic"
 }
 },
 
 ## Types (unsupported):
 * airport
 * services
 * dpw
 * centerCamp
 * 8entrance
 * 12entrance
 * greeters
 * ice
 
 ## Types (supported):
 * EmergencyClinic -> BRCMapPointTypeMedical
 * firstAid -> BRCMapPointTypeMedical
 * ranger -> BRCMapPointTypeRanger
 Note there is both "firstAid" and "EmergencyClinic" for medical
 * toilet -> BRCMapPointTypeToilet
 * center
 
 */

@interface BRCMapPoint : MTLModel <MTLJSONSerializing, MGLAnnotation>

/** yap key */
@property (nonatomic, strong, readonly) NSString *uuid;
@property (nonatomic, strong, readwrite) NSDate *creationDate;

@property (nonatomic, strong, nullable, readwrite) NSString *title;
@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;
@property (nonatomic, readwrite) BRCMapPointType type;

- (nullable CLLocation*) location;

- (instancetype) initWithTitle:(nullable NSString*)title coordinate:(CLLocationCoordinate2D)coordinate type:(BRCMapPointType)type;

/** yap collection */
+ (NSString*) collection;

/** BRCUserMapPoint for editable user points, BRCMapPoint for fixed locations */
+ (Class) classForType:(BRCMapPointType)type;
+ (NSString*) yapCollectionForType:(BRCMapPointType)type;

/** Image for type. */
@property (nonatomic, strong, readonly) UIImage *image;

@end

NS_ASSUME_NONNULL_END
