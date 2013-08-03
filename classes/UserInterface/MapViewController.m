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
#import "CampInfoViewController.h"
#import "Event.h"
#import "EventInfoViewController.h"
#import "iBurnAppDelegate.h"
#import "MapViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <RMAnnotation.h>
#import <RMMapBoxSource.h>
#import <RMMarker.h>
#import <RMMBTilesSource.h>
#import <RMMapView.h>
#import "ThemeCamp.h"
#import "util.h"


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
    
    RMAnnotation *annotation = [[RMAnnotation alloc]initWithMapView:mapView
                                                         coordinate:coord
                                                           andTitle:[camp name]];
    annotation.annotationIcon = [UIImage imageNamed:iconName];
    annotation.annotationType = dataType;
    [mapView addAnnotation:annotation];
    // newMarker.waypointID = camp.simpleName;
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


#warning mapbox
/*- (void) tapOnMarker: (GaiaMarker*) marker onMap: (RMMapView*) map {
 if (![marker.data isKindOfClass:[NSString class]]) return;
 NSString *markerString = (NSString*)marker.data;
 if ([markerString isEqualToString:@"ThemeCamp"]) {
 ThemeCamp * camp = [ThemeCamp campForSimpleName:[marker waypointID]];
 self.detailView = [[CampInfoViewController alloc] initWithCamp:camp];
 
 }
 if ([markerString isEqualToString:@"ArtInstall"]) {
 ArtInstall * art = [ArtInstall artForName:[marker waypointID]];
 self.detailView = [[ArtInfoViewController alloc] initWithArt:art];
 
 }
 if ([markerString isEqualToString:@"Event"]) {
 Event * event = [Event eventForName:[marker waypointID]];
 self.detailView = [[EventInfoViewController alloc] initWithEvent:event];
 
 }
 [self.navigationController pushViewController:detailView animated:YES];
 }
 
 
 - (void) afterMapTouch: (RMMapView*) map{
 if ([RMMapContents performExpensiveOperations]) {
 [self showMarkersOnScreen];
 }
 
 if (isCurrentlyUpdating) {
 [self startLocation:nil];
 }
 }
 
 
 */


- (MapViewController *)initWithTitle: (NSString *) aTitle {
	self = [super init];
  if (!self) return nil;
  lastFetchedZoom = 0.0;
  _needFetchQuadrant = 0;
  _markersNeedDisplay = 0;
	self.title = aTitle;
  UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"map.png"] tag:0];
  self.tabBarItem = tabBarItem;
	
  UISegmentedControl *downloadButton = [[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObject:[UIImage imageNamed:@"home_nav_button.png"]]];
  downloadButton.frame = CGRectMake(0,0,35,35);
  downloadButton.momentary = YES;
  downloadButton.tintColor = [UIColor darkGrayColor];
  downloadButton.segmentedControlStyle = UISegmentedControlStyleBar;
  [downloadButton addTarget:self
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
  [buttonView2 addSubview: downloadButton];
  UIBarButtonItem *item2 = [[UIBarButtonItem alloc]initWithCustomView:buttonView2];
	self.navigationItem.leftBarButtonItem = item2;
	
	
	/*self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
   initWithImage:[UIImage imageNamed:@"map-download-icon.png"]
   style:UIBarButtonItemStylePlain
   target:self
   action:@selector(redownloadMaps:)] autorelease];*/
  
#warning MapBox
  
  /*
   
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showMarkersOnScreen) name:RMResumeExpensiveOperations object:nil];
   
   */
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(liftEmbargo) name:@"LIFT_EMBARGO" object:nil];
  
  
  
  return self;
}


- (void) alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == 0) return;
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [t downloadMaps:YES];
}

- (void) redownloadMaps:(id)sender {
  UIAlertView *av = [[UIAlertView alloc]initWithTitle:@"Redownload maps?" message:@"Would you like to re-download all the maps, in case there have been updates?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
  [av show];
}

#warning mapbox
/*-(BOOL)sphericalTrapezium:(RMSphericalTrapezium)rect containsPoint:(RMLatLong)point {
 return (rect.northeast.latitude > point.latitude &&
 rect.southwest.latitude < point.latitude &&
 rect.northeast.longitude > point.longitude &&
 rect.southwest.longitude < point.longitude);
 }*/

- (BOOL) locateMeWorks {
	CLLocationManager *lm = [MyCLController sharedInstance].locationManager;
	if(!lm.locationServicesEnabled) return NO;
	if(lm.location == nil) return NO;
	//NSLog(@"%@", lm.location);
#warning use mbtiles instead
  /*	BurnTileSource *tileSource = [[BurnTileSource alloc] init];
   RMSphericalTrapezium bounds = [tileSource latitudeLongitudeBoundingBox];*/
  
#warning mapbox
  /*	if([self sphericalTrapezium:bounds containsPoint:lm.location.coordinate]) {
   return YES;
   }
   else {
   return NO;
   }*/
}

- (void) startLocation:(id)sender {
	if (![self locateMeWorks]) {
    [self showLocationErrorAlertView];
		return;
  }
	if(isCurrentlyUpdating) {
    isCurrentlyUpdating = NO;
    locationButton.tintColor = [UIColor darkGrayColor];
  } else {
    if (currentLocationMarker) {
#warning mapbox
      /*      CLLocationCoordinate2D coord = [[[[MyCLController sharedInstance] locationManager] location] coordinate];
       [self.mapView.contents moveToLatLong:coord];
       */
    }
    isCurrentlyUpdating = YES;
    locationButton.tintColor = [UIColor redColor];
  }
}


- (void) home: (id) sender {
#warning mapbox
  /*
   RMSphericalTrapezium bounds = [mapView.contents.tileSource latitudeLongitudeBoundingBox];
   [mapView.contents zoomWithLatLngBoundsNorthEast:bounds.northeast SouthWest:bounds.southwest];
   [mapView.contents zoomByFactor:1.3 near:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
   
   CLLocationCoordinate2D center = [MapViewController burningManCoordinate];
   
   [mapView.contents moveToLatLong:center];
   */
}

+ (CLLocationCoordinate2D) burningManCoordinate {
  return CLLocationCoordinate2DMake(40.78629, -119.20650);
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
  
  //RMMapBoxSource *onlineSource = [[RMMapBoxSource alloc] initWithMapID:(([[UIScreen mainScreen] scale] > 1.0) ? kRetinaMapID : kNormalMapID)];
  RMMBTilesSource *offlineSource = [[RMMBTilesSource alloc] initWithTileSetResource:@"iburn" ofType:@"mbtiles"];
  [mapView setTileSource:offlineSource];

  mapView = [[RMMapView alloc] initWithFrame:self.view.bounds andTilesource:offlineSource];
  mapView.zoom = 2;
  mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:mapView];
  //[self loadMBTilesFile];
  
#warning mapbox
  /* 
   [mapView setBackgroundColor:[UIColor blackColor]];
   self.progressView = [[UIProgressView alloc]
   initWithProgressViewStyle:UIProgressViewStyleBar];
   progressView.frame = CGRectMake(5.0, 5, 268, 9.0);
   progressView.alpha = 0;
   [self.view addSubview:self.progressView];
   [self loadMarkers];
   iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
   if (t.embargoed) {
   [mapView.contents setMaxZoom:14];
   } else {
   [mapView.contents setMaxZoom:18];
   }
   */
  
}


- (void)viewDidLoad {
  [super viewDidLoad];
	[mapView setDelegate:self];
	[MyCLController sharedInstance].delegate = self;
  if (![MyCLController sharedInstance].locationManager.locationServicesEnabled ) {
    locationButton.enabled = NO;
  } else {
    [[MyCLController sharedInstance].locationManager startUpdatingLocation];
  }
	// Offset slightly south from 2009 city location so that map is center
	//CLLocationCoordinate2D point = {40.78775, -119.200037};
  //[mapView.contents setZoom:15];
  
	
#warning mapbox
  /*markerManager = [mapView markerManager];
   */
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


- (void)newLocationUpdate:(CLLocation *)newLocation {
#warning mapbox
  /*	if (signbit(newLocation.horizontalAccuracy)) {
   } else {
   CLLocationCoordinate2D coord = newLocation.coordinate;
   if (!currentLocationMarker) {
   currentLocationMarker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"blue_dot.gif"]];
   [currentLocationMarker setProjectedLocation:[[mapView.contents projection] latLongToPoint:coord]];
   [[mapView.contents overlay] addSublayer:currentLocationMarker];
   } else {
   [mapView.contents.markerManager moveMarker:currentLocationMarker AtLatLon:coord];
   }
   
   if(isCurrentlyUpdating) {
   [mapView.contents moveToLatLong:coord];
   }
   
   }*/
}


- (void)newError:(NSString *)text {
	//[self addTextToLog:text];
	UIAlertView *errorAlert = [[UIAlertView alloc]
                             initWithTitle:@"Location Delegate Error"
                             message:text
                             delegate:self
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK", nil];
	[errorAlert show];
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
  [self loadMarkers];
  [[self.view viewWithTag:999]removeFromSuperview];
}




@end