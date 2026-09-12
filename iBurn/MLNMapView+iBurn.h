//
//  MLNMapView+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import MapLibre;

NS_ASSUME_NONNULL_BEGIN
@interface MLNMapView (iBurn)

- (void)brc_showDestination:(id<MLNAnnotation>)destination animated:(BOOL)animated padding:(UIEdgeInsets)padding;

- (void)brc_zoomToFullTileSourceAnimated:(BOOL)animated;
- (void)brc_moveToBlackRockCityCenterAnimated:(BOOL)animated;

/** The bounding box of the black rock desert */
@property (nonatomic, class, readonly) MLNCoordinateBounds brc_bounds;

@end
NS_ASSUME_NONNULL_END
