//
//  MapViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2008-12-25.
//  Copyright Burning Man Earth 2008. All rights reserved.
//

#import "ArtInfoViewController.h"
#import "ArtInstall.h"
#import <ASIFormDataRequest.h>
#import "BurnRMAnnotation.h"
#import "CampInfoViewController.h"
#import "Event.h"
#import "EventInfoViewController.h"
#import "iBurnAppDelegate.h"
#import "MapViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <RMMapBoxSource.h>
#import <RMMarker.h>
#import <RMMBTilesSource.h>
#import <RMMapView.h>
#import "ThemeCamp.h"
#import "util.h"
#import "RMPolylineAnnotation.h"
#import "RMUserLocation.h"


@implementation MapViewController
@synthesize mapView, detailView, progressView;

- (void) showLocationErrorAlertView {
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Location Unknown" message:@"Either we can't find you or you're not at Burning Man.  Make sure you are at Burning Man with a clear view of the sky and try again." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
}


- (RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
  RMMarker *newMarker = [[RMMarker alloc] initWithUIImage:annotation.annotationIcon];
  newMarker.anchorPoint = CGPointMake(.5,.8);
  return newMarker;
}


- (void) showMapForObject:(id)obj {
  CLLocationCoordinate2D point;
  point.latitude = [[obj latitude] floatValue];
  point.longitude = [[obj longitude] floatValue];
  RMAnnotation *annotation = [[RMAnnotation alloc]initWithMapView:mapView
                                                       coordinate:point
                                                         andTitle:[obj name]];
  [mapView addAnnotation:annotation];
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
  for (ThemeCamp* camp in [self getAllObjects:dataType]) {
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
    if ([camp respondsToSelector:@selector(simpleName)]) {
      annotation.simpleName = camp.simpleName;
    }
    [mapView addAnnotation:annotation];
	}
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
  for (Event* event in [Event getTodaysEvents]) {
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
}


- (void) loadMarkers {
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  if (t.embargoed) return;
  [self loadArt];
  [self loadCamps];
  [self loadEvents];
}


- (void)tapOnAnnotation:(BurnRMAnnotation *)annotation onMap:(RMMapView *)map {
  if (!annotation.annotationType) return;
  NSString *markerString = annotation.annotationType;
  
  if ([markerString isEqualToString:@"ThemeCamp"]) {
    ThemeCamp * camp = [ThemeCamp campForSimpleName:[annotation simpleName]];
    self.detailView = [[CampInfoViewController alloc] initWithCamp:camp];
    
  }
  if ([markerString isEqualToString:@"ArtInstall"]) {
    ArtInstall * art = [ArtInstall artForName:[annotation simpleName]];
    self.detailView = [[ArtInfoViewController alloc] initWithArt:art];
    
  }
  if ([markerString isEqualToString:@"Event"]) {
    Event * event = [Event eventForName:[annotation simpleName]];
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


- (RMSphericalTrapezium) brcBounds {
  return [mapView.tileSource latitudeLongitudeBoundingBox];
}


- (BOOL) locateMeWorks {
	CLLocationManager *lm = [MyCLController sharedInstance].locationManager;
	if(!lm.locationServicesEnabled) return NO;
	if(lm.location == nil) return NO;
	//NSLog(@"%@", lm.location);
  	if([self sphericalTrapezium:[self brcBounds] containsPoint:lm.location.coordinate]) {
   return YES;
   }
   else {
   return NO;
   }
}


- (void) startLocation:(id)sender {
	if (![self locateMeWorks]) {
    [self showLocationErrorAlertView];
		return;
  }
  if (mapView.userTrackingMode == RMUserTrackingModeNone) {
    mapView.userTrackingMode = RMUserTrackingModeFollow;
    locationButton.tintColor = [UIColor blueColor];
  } else if (mapView.userTrackingMode == RMUserTrackingModeNone) {
    mapView.userTrackingMode = RMUserTrackingModeFollowWithHeading;
    locationButton.tintColor = [UIColor redColor];
  } else if (mapView.userTrackingMode == RMUserTrackingModeNone) {
    mapView.userTrackingMode = RMUserTrackingModeNone;
    locationButton.tintColor = [UIColor darkGrayColor];
  }
}


- (void) home: (id) sender {
  //RMSphericalTrapezium bounds = [self brcBounds];
  //[mapView zoomWithLatitudeLongitudeBoundsSouthWest:bounds.southWest northEast:bounds.northEast animated:YES];
  
  // [mapView zoomByFactor:1.3 near:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2) animated:YES];
  //CLLocationCoordinate2D center = [MapViewController burningManCoordinate];
  // [mapView moveToLatLong:center];
  CLLocation * fakeHome = [[CLLocation alloc] initWithLatitude:40.786025 longitude:-119.205798];
  [util setHomeLocation:fakeHome];
  if(![util homeLocation])
  {
    //ask to set home location
  }
  else{
    [self navigateToLocation:[util homeLocation]];
    
    
  }
}

-(void)navigateToLocation:(CLLocation *)location
{
  toLocation = location;
  CLLocation * currentLocation = [[MyCLController sharedInstance] location];
  if(currentLocation)
  {
    navigationLineAnnotation = [[RMPolylineAnnotation alloc] initWithMapView:self.mapView points:@[location,currentLocation]];
    [self.mapView addAnnotation:navigationLineAnnotation];
  }
}

-(void)stopNavigation
{
  [self.mapView removeAnnotation:navigationLineAnnotation];
  navigationLineAnnotation = nil;
  toLocation = nil;
}


- (NSURL*) mbTilesURL {
  return [NSURL URLWithString:@"http://com.gaiagps.iburn.s3-website-us-east-1.amazonaws.com/iburn.mbtiles"];
}


- (NSString*) mbTilesPath {
  return [privateDocumentsDirectory() stringByAppendingPathComponent:@"iburn.mbtiles"];;
}


- (void) loadMBTilesFile {
#warning set this up to only fetch a new file if needed
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:[self mbTilesURL]];
    [request setTimeOutSeconds:240];
    [request setDownloadDestinationPath:[self mbTilesPath]];
    [request startSynchronous];
    dispatch_async(dispatch_get_main_queue(), ^{
      RMMBTilesSource *offlineSource = [[RMMBTilesSource alloc] initWithTileSetURL:[NSURL fileURLWithPath:[self mbTilesPath]]];
      [mapView setTileSource:offlineSource];
    });
  });
  
}


#define kNormalMapID @"examples.map-z2effxa8"
#define kRetinaMapID @"examples.map-zswgei2n"
- (void)loadView {
  [super loadView];
  RMMapBoxSource *onlineSource = [[RMMapBoxSource alloc] initWithMapID:(([[UIScreen mainScreen] scale] > 1.0) ? kRetinaMapID : kNormalMapID)];
  RMMBTilesSource *offlineSource = [[RMMBTilesSource alloc] initWithTileSetResource:@"iburn" ofType:@"mbtiles"];
  
  mapView = [[RMMapView alloc] initWithFrame:self.view.bounds andTilesource:offlineSource];
  mapView.zoom = 2;
  mapView.adjustTilesForRetinaDisplay = YES;
  mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:mapView];
  //[self loadMBTilesFile];
  [mapView setBackgroundColor:[UIColor blackColor]];
  self.progressView = [[UIProgressView alloc]
                       initWithProgressViewStyle:UIProgressViewStyleBar];
  progressView.frame = CGRectMake(5.0, 5, 268, 9.0);
  progressView.alpha = 0;
  [self.view addSubview:self.progressView];
  
  //[self loadMarkers];
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
  if (t.embargoed) {
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
  }
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