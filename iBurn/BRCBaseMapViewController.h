//
//  BRCBaseMapViewController.h
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import UIKit;
@import Mapbox_iOS_SDK;

@interface BRCBaseMapViewController : UIViewController <RMMapViewDelegate>

//This viewController is the base for the main map viewController as well as the detail mapViewController

@property (nonatomic, strong) RMMapView *mapView;

- (void) centerMapAtManCoordinatesAnimated:(BOOL)animated;

@end
