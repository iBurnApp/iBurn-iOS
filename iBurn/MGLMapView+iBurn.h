//
//  MGLMapView+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import Mapbox;

@class BRCDataObject, BRCObjectMetadata;

NS_ASSUME_NONNULL_BEGIN
@interface MGLMapView (iBurn)

- (void)brc_showDestinationForDataObject:(BRCDataObject*)dataObject metadata:(BRCObjectMetadata*)metadata animated:(BOOL)animated padding:(UIEdgeInsets)padding;

- (void)brc_showDestination:(id<MGLAnnotation>)destination animated:(BOOL)animated padding:(UIEdgeInsets)padding;

- (void)brc_zoomToFullTileSourceAnimated:(BOOL)animated;
- (void)brc_moveToBlackRockCityCenterAnimated:(BOOL)animated;

/** The bounding box of the black rock desert */
@property (nonatomic, class, readonly) MGLCoordinateBounds brc_bounds;

@end
NS_ASSUME_NONNULL_END
