//
//  MapViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2008-12-25.
//  Copyright Burning Man Earth 2008. All rights reserved.
//

#import "ArtInfoViewController.h"
#import "ArtInstall.h"
#import "BurnRMAnnotation.h"
#import "CampInfoViewController.h"
#import "Event.h"
#import "EventInfoViewController.h"
#import "iBurnAppDelegate.h"
#import "MapViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <RMCompositeSource.h>
#import <RMMapBoxSource.h>
#import <RMMarker.h>
#import <RMMBTilesSource.h>
#import <RMMapView.h>
#import "RMPolylineAnnotation.h"
#import "RMUserLocation.h"
#import "S3BigFileDownloader.h"
#import "ThemeCamp.h"
#import "util.h"

#define SET_HOME_STRING @"Set Home"
#define NAVIGATE_STRING @"Navigate Home"
#define STOP_NAVIGATION_STRING @"Stop Navigation"
#define CANCEL_STRING @"Cancel"


@implementation MapViewController
@synthesize mapView, detailView, progressView, bigFileDownloader;

- (void) showLocationErrorAlertView {
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Location Unknown" message:@"Either we can't find you or you're not at Burning Man.  Make sure you are at Burning Man with a clear view of the sky and try again." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
}


- (RMMapLayer *)mapView:(RMMapView *)mv layerForAnnotation:(RMAnnotation *)annotation {
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  if ((mv.zoom < 17 || t.embargoed)
      && [annotation.annotationType isEqualToString:@"ThemeCamp"]) {
    return nil;
  }
  if (mv.zoom < 16
      && [annotation.annotationType isEqualToString:@"ArtInstall"]) {
    return nil;
  }
  RMMarker *newMarker = [[RMMarker alloc] initWithUIImage:annotation.annotationIcon];
  newMarker.anchorPoint = CGPointMake(.5, .8);
  return newMarker;
}


- (void) beforeMapZoom:(RMMapView *)map byUser:(BOOL)wasUserAction {
  previousZoom = mapView.zoom;
  
}

- (void) removeAndLoad {
  [self loadMarkers];
}


- (void) afterMapZoom:(RMMapView *)map byUser:(BOOL)wasUserAction {
  if (mapView.zoom < previousZoom
      && mapView.zoom >= 15) {
    [self.mapView removeAllAnnotations];
    [NSThread detachNewThreadSelector:@selector(removeAndLoad) toTarget:self withObject:nil];
  }
}


- (void) showMapForObject:(id)obj {
  CLLocationCoordinate2D point;
  point.latitude = [[obj latitude] floatValue];
  point.longitude = [[obj longitude] floatValue];
  RMAnnotation *annotation = [[RMAnnotation alloc]initWithMapView:mapView
                                                       coordinate:point
                                                         andTitle:[obj name]];
  [mapView addAnnotation:annotation];
  [mapView setZoom:17 atCoordinate:point animated:YES];
}


- (NSArray*) getAllObjects:(NSString*) objType {
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:objType inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  return objects;
}


- (void) loadDataType:(NSString*)dataType iconName:(NSString*)iconName {
  NSArray * themeCamps = [self getAllObjects:dataType];
  dispatch_async(dispatch_get_main_queue(), ^{

    for (ThemeCamp* camp in themeCamps) {
      CLLocationCoordinate2D coord;
      coord.latitude = [camp.latitude floatValue];
      if (coord.latitude < 1) continue;
      coord.longitude = [camp.longitude floatValue];
      BurnRMAnnotation *annotation = [[BurnRMAnnotation alloc]initWithMapView:mapView
                                                                   coordinate:coord
                                                                     andTitle:[camp name]];
      annotation.annotationIcon = [UIImage imageNamed:iconName];
      annotation.annotationType = dataType;
      // if it's a camp
      if ([camp respondsToSelector:@selector(bm_id)]) {
        annotation.burningManID = camp.bm_id;
      }
      [mapView addAnnotation:annotation];
    }
  });
}


- (void) loadCamps {
  [self loadDataType:@"ThemeCamp" iconName:@"red-pin-down.png"];
  // zoom 18 or 19
}


- (void) loadArt {
  [self loadDataType:@"ArtInstall" iconName:@"blue-pin-down.png"];
  // zoom 17
}


- (void) loadEvents {
  NSArray * events = [Event getTodaysEvents];
  dispatch_async(dispatch_get_main_queue(), ^{

    for (Event* event in events ) {
      CLLocationCoordinate2D coord;
      coord.latitude = [event.latitude floatValue];
      if (coord.latitude < 1) continue;
      coord.longitude = [event.longitude floatValue];
      RMAnnotation *annotation = [[RMAnnotation alloc]initWithMapView:mapView
                                                           coordinate:coord
                                                             andTitle:[event name]];
      annotation.annotationIcon = [UIImage imageNamed:@"green-pin-down.png"];
      annotation.annotationType = @"Event";
      // annotation.simpleName = event.sim
      [mapView addAnnotation:annotation];
    }
  });
}


- (void) loadMarkers {
  [self loadArt];
  [self loadCamps];
  [self loadEvents];
}


- (void)tapOnAnnotation:(BurnRMAnnotation *)annotation onMap:(RMMapView *)map {
  if (!annotation.annotationType) return;
  NSString *markerString = annotation.annotationType;
  
  if ([markerString isEqualToString:@"ThemeCamp"]) {
    ThemeCamp * camp = [ThemeCamp campForID:[[annotation burningManID] intValue]];
    self.detailView = [[CampInfoViewController alloc] initWithCamp:camp];
    
  }
  if ([markerString isEqualToString:@"ArtInstall"]) {
    ArtInstall * art = [ArtInstall artForName:[annotation title]];
    self.detailView = [[ArtInfoViewController alloc] initWithArt:art];
    
  }
  if ([markerString isEqualToString:@"Event"]) {
    Event * event = [Event eventForID:[annotation burningManID]];
    self.detailView = [[EventInfoViewController alloc] initWithEvent:event];
    
  }
  [self.navigationController pushViewController:detailView animated:YES];
}


- (MapViewController *)initWithTitle: (NSString *) aTitle {
	self = [super init];
  if (!self) return nil;
	self.title = aTitle;
  UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"map.png"] tag:0];
  self.tabBarItem = tabBarItem;
	
  UISegmentedControl *homeButton = [[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObject:[UIImage imageNamed:@"home_nav_button.png"]]];
  homeButton.frame = CGRectMake(0,0,35,35);
  homeButton.momentary = YES;
  homeButton.tintColor = [UIColor darkGrayColor];
  homeButton.segmentedControlStyle = UISegmentedControlStyleBar;
  [homeButton addTarget:self
                 action:@selector(home:)
       forControlEvents:UIControlEventValueChanged];
  
  locationButton = [[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObject:[UIImage imageNamed:@"locate-icon.png"]]];
  locationButton.frame = CGRectMake(45,0,35,35);
  locationButton.tintColor = [UIColor darkGrayColor];
  locationButton.momentary = YES;
  locationButton.segmentedControlStyle = UISegmentedControlStyleBar;
  [locationButton addTarget:self
                     action:@selector(startLocation:)
           forControlEvents:UIControlEventValueChanged];
  
	UIView *buttonView = [[UIView alloc]initWithFrame:CGRectMake(0,0,80,35)];
  [buttonView addSubview: locationButton];
  UIBarButtonItem *item = [[UIBarButtonItem alloc]initWithCustomView:buttonView];
  [self.navigationItem setTitle:@"Black Rock City"];
	self.navigationItem.rightBarButtonItem = item;
  
	UIView *buttonView2 = [[UIView alloc]initWithFrame:CGRectMake(0,0,80,35)];
  [buttonView2 addSubview: homeButton];
  UIBarButtonItem *item2 = [[UIBarButtonItem alloc]initWithCustomView:buttonView2];
	self.navigationItem.leftBarButtonItem = item2;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(liftEmbargo) name:@"LIFT_EMBARGO" object:nil];
  return self;
}


- (BOOL)sphericalTrapezium:(RMSphericalTrapezium)rect containsPoint:(CLLocationCoordinate2D)point {
  return (rect.northEast.latitude > point.latitude &&
          rect.southWest.latitude < point.latitude &&
          rect.northEast.longitude > point.longitude &&
          rect.southWest.longitude < point.longitude);
}


- (BOOL) locateMeWorks {
	CLLocationManager *lm = [MyCLController sharedInstance].locationManager;
	if(!lm.locationServicesEnabled) return NO;
	if(lm.location == nil) return NO;
  return YES;
}


- (void) startLocation:(id)sender {
	if (![self locateMeWorks]) {
    [self showLocationErrorAlertView];
		return;
  }
  if (mapView.userTrackingMode == RMUserTrackingModeNone) {
    mapView.userTrackingMode = RMUserTrackingModeFollow;
    locationButton.tintColor = [UIColor blueColor];
  } else if (mapView.userTrackingMode == RMUserTrackingModeFollow) {
    mapView.userTrackingMode = RMUserTrackingModeFollowWithHeading;
    locationButton.tintColor = [UIColor redColor];
  } else if (mapView.userTrackingMode == RMUserTrackingModeFollowWithHeading) {
    mapView.userTrackingMode = RMUserTrackingModeNone;
    locationButton.tintColor = [UIColor darkGrayColor];
  }
}


- (RMSphericalTrapezium) brcBounds {
  RMMBTilesSource *offlineSource = [[RMMBTilesSource alloc] initWithTileSetResource:@"iburn" ofType:@"mbtiles"];
  return [offlineSource latitudeLongitudeBoundingBox];
}


- (void) home: (id) sender {
  //RMSphericalTrapezium bounds = [self brcBounds];
  //[mapView zoomWithLatitudeLongitudeBoundsSouthWest:bounds.southWest northEast:bounds.northEast animated:YES];
  
  // [mapView zoomByFactor:1.3 near:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2) animated:YES];
  //CLLocationCoordinate2D center = [MapViewController burningManCoordinate];
  // [mapView moveToLatLong:center];
  /*CLLocation * fakeHome = [[CLLocation alloc] initWithLatitude:40.786025 longitude:-119.205798];
   [util setHomeLocation:fakeHome];
   */
  NSArray * otherTitles = nil;
  if(navigationLineAnnotation)
  {
    otherTitles = @[STOP_NAVIGATION_STRING,CANCEL_STRING];
  }
  else if(![util homeLocation])
  {
    otherTitles = @[SET_HOME_STRING,CANCEL_STRING];
  }
  else
  {
    otherTitles = @[SET_HOME_STRING,NAVIGATE_STRING,CANCEL_STRING];
  }
  
  UIActionSheet * actionSheet = [[UIActionSheet alloc] init];
  actionSheet.delegate =self;
  actionSheet.title = @"Home";
  [otherTitles enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    [actionSheet addButtonWithTitle:obj];
  }];
  actionSheet.cancelButtonIndex = [otherTitles count]-1;
  [actionSheet showInView:self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if (actionSheet.cancelButtonIndex == buttonIndex) {
    return;
  }
  else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:STOP_NAVIGATION_STRING])
  {
    [self stopNavigation];
  }
  else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NAVIGATE_STRING])
  {
    [self navigateToLocation:[util homeLocation]];
  }
  else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:SET_HOME_STRING])
  {
    [util setHomeLocation:[MyCLController sharedInstance].location];
  }
}

- (void)navigateToLocation:(CLLocation *)location {
  toLocation = location;
  CLLocation * currentLocation = [[MyCLController sharedInstance] location];
  if (navigationLineAnnotation) {
    [self.mapView removeAnnotation:navigationLineAnnotation];
  }
  if(currentLocation) {
    navigationLineAnnotation = [[RMPolylineAnnotation alloc] initWithMapView:self.mapView points:@[location,currentLocation]];
    [self.mapView addAnnotation:navigationLineAnnotation];
  }
}


- (void)stopNavigation {
  [self.mapView removeAnnotation:navigationLineAnnotation];
  navigationLineAnnotation = nil;
  toLocation = nil;
}


- (S3BigFileDownloader*) bigFileDownloader {
  if (!bigFileDownloader) {
    bigFileDownloader = [[S3BigFileDownloader alloc]init];
  }
  return bigFileDownloader;
}


- (int) fileSizeForPath:(NSString*)path {
  NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
  return [fileAttribs fileSize];
}


#define kNormalMapID @"iburn.map-0ytz4sz2"
#define kRetinaMapID @"iburn.map-0ytz4sz2"
- (void) setMapSources {
  // RMMapBoxSource *onlineSource = [[RMMapBoxSource alloc] initWithMapID:(([[UIScreen mainScreen] scale] > 1.0) ? kRetinaMapID : kNormalMapID)];
  RMMBTilesSource *offlineSource = [[RMMBTilesSource alloc] initWithTileSetURL:[NSURL fileURLWithPath:[self.bigFileDownloader mbTilesPath]]];
  [mapView setTileSource:offlineSource];
  //[mapView addTileSource:offlineSource];
  // [mapView setTileSources:@[onlineSource, offlineSource]];
  NSLog(@"The center is %f, %f", mapView.centerCoordinate.latitude, mapView.centerCoordinate.longitude);
}


- (void)loadView {
  [super loadView];
  mapView = [[RMMapView alloc] initWithFrame:self.view.bounds];
  mapView.adjustTilesForRetinaDisplay = YES;
  mapView.hideAttribution = YES;
  mapView.showLogoBug = NO;
  [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(setMapSources) name:@"BIG_FILE_DOWNLOAD_DONE" object:nil];
  [self.bigFileDownloader copyMBTileFileFromBundle];
  [self setMapSources];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.bigFileDownloader loadMBTilesFile];
  });
  mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:mapView];
  RMSphericalTrapezium bounds = [self brcBounds];
  [mapView zoomWithLatitudeLongitudeBoundsSouthWest:bounds.southWest northEast:bounds.northEast animated:NO];
  self.progressView = [[UIProgressView alloc]
                       initWithProgressViewStyle:UIProgressViewStyleBar];
  progressView.frame = CGRectMake(5.0, 5, 268, 9.0);
  progressView.alpha = 0;
  [self.view addSubview:self.progressView];
  
  [self loadMarkers];
#warning this freezes it
  /*
   iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
   if (t.embargoed) {
   [mapView setMaxZoom:14];
   } else {
   [mapView setMaxZoom:18];
   }
   */
}


- (void)viewDidLoad {
  [super viewDidLoad];
	[mapView setDelegate:self];
	if (![MyCLController sharedInstance].locationManager.locationServicesEnabled ) {
    locationButton.enabled = NO;
  } else {
    [[MyCLController sharedInstance].locationManager startUpdatingLocation];
    [[MyCLController sharedInstance]setDelegate:self];
  }
	
	[mapView setBackgroundColor:[UIColor blackColor]];
	//[mapView moveToLatLong:point];
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  /*  if (t.embargoed) {
   int width = self.view.frame.size.width-20;
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
   width -= 200;
   }
   UILabel *lbl = [[UILabel alloc]initWithFrame:CGRectMake(self.view.frame.size.width/2 - width/2, self.view.frame.size.height/2, width, 42)];
   
   lbl.text = @"Enter Burning Man or enter the password to unlock the map.";
   lbl.tag = 999;
   lbl.textAlignment = UITextAlignmentCenter;
   lbl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
   lbl.numberOfLines = 0;
   lbl.layer.cornerRadius = 8;
   lbl.layer.borderWidth = 1;
   lbl.backgroundColor = [UIColor colorWithWhite:1 alpha:.5];
   [self.view addSubview:lbl];
   }*/
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


- (BOOL)shouldAutorotate {
  return [self shouldAutorotateToInterfaceOrientation:UIDeviceOrientationPortrait];
}


- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) liftEmbargo {
#warning mapbox
  /*  [mapView.contents setMaxZoom:18];*/
  //[self loadMarkers];
  [[self.view viewWithTag:999]removeFromSuperview];
}

- (void) newLocationUpdate:(CLLocation *)newLocation {
  if (currentLocationAnnotation) {
    [mapView removeAnnotations:@[currentLocationAnnotation]];
  }
  
  if (mapView.userTrackingMode == RMUserTrackingModeFollow) {
    currentLocationAnnotation = [[RMAnnotation alloc]initWithMapView:mapView
                                                          coordinate:newLocation.coordinate
                                                            andTitle:nil];
    currentLocationAnnotation.annotationIcon = [UIImage imageNamed:@"blue-arrow.png"];
    [mapView addAnnotation:currentLocationAnnotation];
  }
  
  if (mapView.userTrackingMode == RMUserTrackingModeFollowWithHeading) {
    currentLocationAnnotation = [[RMAnnotation alloc]initWithMapView:mapView
                                                          coordinate:newLocation.coordinate
                                                            andTitle:nil];
    currentLocationAnnotation.annotationIcon = [UIImage imageNamed:@"course-up-arrow.png"];
    [mapView addAnnotation:currentLocationAnnotation];
  }
  
  if(navigationLineAnnotation)
  {
    [self navigateToLocation:toLocation];
  }
  
  
}



@end
