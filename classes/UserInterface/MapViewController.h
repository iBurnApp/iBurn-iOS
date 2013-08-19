//
//  MapViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2008-12-25.
//  Copyright Burning Man Earth 2008. All rights reserved.
//

#import <RMMapView.h>
#import "MyCLController.h"

#define THEME_CAMP_TYPE @"ThemeCamp"
#define ART_INSTALL_TYPE @"ArtInstall"
#define EVENT_TYPE @"Event"

#define THEME_CAMP_PIN_NAME @"blue-pin-down.png"
#define EVENT_PIN_NAME @"green-pin-down.png"
#define ART_INSTALL_PIN_NAME @"red-pin-down.png"

#define FAVORITE_THEME_CAMP_PIN_NAME @"star-pin-down.png"
#define FAVORITE_EVENT_PIN_NAME @"green-star-pin-down.png"
#define FAVORITE_ART_INSTALL_PIN_NAME @"red-star-pin-down.png"


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

