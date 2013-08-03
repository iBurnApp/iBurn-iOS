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

@interface MapViewController : UIViewController <RMMapViewDelegate, MyCLControllerDelegate> {
	RMMapView * mapView;
	BOOL tap;
	BOOL isCurrentlyUpdating;
	BOOL firstUpdate;		
	UISegmentedControl *locationButton;
	//RMMarkerManager *markerManager;
	RMMarker *currentLocationMarker;
  InfoViewController *detailView;
  float lastFetchedZoom;
  CLLocationCoordinate2D lastFetchedCenter;
  int _markersNeedDisplay, _needFetchQuadrant;
  UIProgressView *progressView;

}

@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) InfoViewController *detailView;
@property (nonatomic, strong) RMMapView *mapView;


- (void) loadCamps;
- (void) showMapForObject:(id)obj;


@end

