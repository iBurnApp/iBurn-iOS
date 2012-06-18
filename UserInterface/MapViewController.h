//
//  MapViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2008-12-25.
//  Copyright Burning Man Earth 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RMMapView.h"
#import "MyCLController.h"
#import "InfoViewController.h"

@interface MapViewController : UIViewController <RMMapViewDelegate, MyCLControllerDelegate> {
	IBOutlet RMMapView * mapView;
	BOOL tap;
	NSInteger tapCount;
	BOOL isCurrentlyUpdating;
	BOOL firstUpdate;		
	UISegmentedControl *locationButton;
	RMMarkerManager *markerManager;
	RMMarker *currentLocationMarker;
  InfoViewController *detailView;
  float lastFetchedZoom;
  CLLocationCoordinate2D lastFetchedCenter;
  int _markersNeedDisplay, _needFetchQuadrant;
  UIProgressView *progressView;

}

@property (nonatomic, retain) UIProgressView *progressView;
@property (nonatomic, retain) InfoViewController *detailView;
@property (nonatomic, retain) RMMapView *mapView;


- (void) loadCamps;
- (void) showMapForObject:(id)obj;


@end

