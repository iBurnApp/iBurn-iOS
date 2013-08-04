//
//  MapViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2008-12-25.
//  Copyright Burning Man Earth 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <RMMapView.h>
#import "MyCLController.h"
#import "InfoViewController.h"

@class RMAnnotation;

@interface MapViewController : UIViewController <RMMapViewDelegate, MyCLControllerDelegate> {
	RMMapView * mapView;
	UISegmentedControl *locationButton;
	RMMarker *currentLocationMarker;
	RMAnnotation *currentLocationAnnotation;
  InfoViewController *detailView;
  UIProgressView *progressView;
  RMAnnotation * navigationLineAnnotation;
  CLLocation * toLocation;

}

@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) InfoViewController *detailView;
@property (nonatomic, strong) RMMapView *mapView;


- (void) loadCamps;
- (void) showMapForObject:(id)obj;


@end

