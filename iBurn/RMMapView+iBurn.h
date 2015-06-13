//
//  RMMapView+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Mapbox_iOS_SDK/Mapbox.h>

@class RMMBTilesSource;

@interface RMMapView (iBurn)

- (void)brc_zoomToFullTileSourceAnimated:(BOOL)animated;
- (void)brc_moveToBlackRockCityCenterAnimated:(BOOL)animated;
- (void)brc_zoomToIncludeCoordinate:(CLLocationCoordinate2D)coordinate1 andCoordinate:(CLLocationCoordinate2D)coordinate2 inVisibleRect:(CGRect)visibleRect animated:(BOOL)animated;

+ (instancetype)brc_defaultMapViewWithFrame:(CGRect)frame;
+ (RMMBTilesSource *)brc_defaultTileSource;

@end
