//
//  BRCMapPoint.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import Foundation;
@import UIKit;
@import CoreLocation;
@import MapLibre;

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

/// A dropped map pin.
///
/// Historically a Mantle/YapDatabase model (`BRCYapDatabaseObject`); user pins now live in
/// PlayaDB's `user_map_pins` table and this is just the MapLibre annotation the map draws.
/// `uniqueID` is the PlayaDB pin id when the pin came from the database, and a fresh UUID
/// for a pin the user has only just dropped.
@interface BRCMapPoint : NSObject <MLNAnnotation>

/** PlayaDB pin id, or a random UUID for a pin not yet persisted. */
@property (nonatomic, copy, readwrite) NSString *uniqueID;

@property (nonatomic, strong, readwrite) NSDate *creationDate;

@property (nonatomic, copy, nullable, readwrite) NSString *title;
@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;
@property (nonatomic, readwrite) BRCMapPointType type;

- (nullable CLLocation*) location;

- (instancetype) initWithTitle:(nullable NSString*)title coordinate:(CLLocationCoordinate2D)coordinate type:(BRCMapPointType)type NS_DESIGNATED_INITIALIZER;

- (instancetype) init NS_UNAVAILABLE;

/** BRCUserMapPoint for editable user points, BRCMapPoint for fixed locations */
+ (Class) classForType:(BRCMapPointType)type;

/** Image for type. */
@property (nonatomic, strong, readonly) UIImage *image;

@end

NS_ASSUME_NONNULL_END
