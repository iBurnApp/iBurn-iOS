//
//  MapViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2008-12-25.
//  Copyright Burning Man Earth 2008. All rights reserved.
//

#import <RMMapView.h>
#import "MyCLController.h"

@class RMAnnotation, InfoViewController, S3BigFileDownloader;

@interface MapViewController : UIViewController <RMMapViewDelegate, MyCLControllerDelegate,UIActionSheetDelegate> {
	RMMapView * mapView;
	UISegmentedControl *locationButton;
	RMMarker *currentLocationMarker;
	RMAnnotation *currentLocationAnnotation;
  InfoViewController *detailView;
  UIProgressView *progressView;
  RMAnnotation * navigationLineAnnotation;
  CLLocation * toLocation;
  float previousZoom;
}

@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) InfoViewController *detailView;
@property (nonatomic, strong) RMMapView *mapView;
@property (nonatomic, strong) S3BigFileDownloader *bigFileDownloader;

- (void) loadCamps;
- (void) showMapForObject:(id)obj;


@end

