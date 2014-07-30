//
//  BRCMapView.h
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "RMMapView.h"

@class RMMBTilesSource;

@interface BRCMapView : RMMapView


- (void)zoomToFullTileSourceAnimated:(BOOL)animated;
- (void)zoomToIncludeCoordinate:(CLLocationCoordinate2D)coordinate1 andCoordinate:(CLLocationCoordinate2D)coordinate2 animated:(BOOL)animated;

+ (instancetype)defaultMapViewWithFrame:(CGRect)frame;
+ (RMMBTilesSource *)defaultTileSource;


@end
