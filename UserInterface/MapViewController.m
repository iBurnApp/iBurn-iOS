//
//  MapViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2008-12-25.
//  Copyright Burning Man Earth 2008. All rights reserved.
//

#import "MapViewController.h"
#import "RMMapContents.h"
#import "RMFoundation.h"
#import "RMMarker.h"
#import "RMMarkerManager.h"
#import "RMOpenStreetMapSource.h"
#import "RMTileImageSet.h"
#import "RMCachedTileSource.h"
#import "BurnTileSource.h"
#import "ThemeCamp.h"
#import "ArtInstall.h"
#import "ArtInfoViewController.h"
#import "CampInfoViewController.h"
#import "GaiaMarkerManager.h"
#import "BurnMapView.h"
#import "iBurnAppDelegate.h"
#import "RMProjection.h"
#import "Event.h"
#import "EventInfoViewController.h"
#import "GaiaMarker.h"

@implementation MapViewController
@synthesize mapView, detailView, progressView;

- (void) showLocationErrorAlertView {
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Location Unknown" message:@"Either we can't find you or you're not at Burning Man.  Make sure you are at Burning Man with a clear view of the sky and try again." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
	[av release];
}

- (void) showMapForObject:(id)obj {
  CLLocationCoordinate2D point;
	point.latitude = [[obj latitude] floatValue]; //Center of 2009 City
  point.longitude = [[obj longitude] floatValue];
	GaiaMarker *newMarker = [[[GaiaMarker alloc] initWithUIImage:[UIImage imageNamed:@"red-pin-down.png"]] autorelease];
	[newMarker changeLabelUsingText:[obj name] 
                             font:[UIFont boldSystemFontOfSize:12.0] 
									foregroundColor:[UIColor blueColor] 
									backgroundColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:.5]];
	newMarker.label.frame = CGRectMake(newMarker.label.frame.origin.x, newMarker.label.frame.origin.y-23, 
																		 newMarker.label.frame.size.width, newMarker.label.frame.size.height);
  newMarker.data = obj;
  newMarker.zoom = 1;
	[mapView.contents.markerManager addMarker:newMarker AtLatLong:point];	
  [mapView moveToLatLong:point];                
  [[mapView contents] setZoom:16.0];
	[mapView.contents.markerManager showMarkersOnScreen];	
}  

- (NSArray*) getAllThemeCamps {  
  NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"ThemeCamp" inManagedObjectContext:[t managedObjectContext]];
  [fetchRequest setEntity:entity];
  
  NSError *error;
  NSArray *objects = [[t managedObjectContext] executeFetchRequest:fetchRequest error:&error];
  
  return objects;
}

- (void) loadCamps {
  [mapView.contents.markerManager setShowLabels:YES];
  for (ThemeCamp* camp in [self getAllThemeCamps]) {
  
  	NSString *imageName;
    imageName = @"camps.png";
		CLLocationCoordinate2D coord;
		coord.latitude = [camp.latitude floatValue];
		coord.longitude = [camp.longitude floatValue];
    GaiaMarker *newMarker = [[[GaiaMarker alloc] initWithUIImage:[UIImage imageNamed:@"camps.png"]] autorelease];
    [newMarker changeLabelUsingText:[camp name] 
                               font:[UIFont boldSystemFontOfSize:12.0] 
                    foregroundColor:[UIColor blueColor] 
                    backgroundColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:.5]];
    newMarker.label.frame = CGRectMake(newMarker.label.frame.origin.x, newMarker.label.frame.origin.y-23, 
                                       newMarker.label.frame.size.width, newMarker.label.frame.size.height);
    newMarker.data = @"ThemeCamp";
    newMarker.waypointID = camp.simpleName;
    newMarker.zoom = 16;
    [mapView.contents.markerManager addMarker:newMarker AtLatLong:coord];	

	}
}

 


- (void) showMarkersOnScreen {
  [(GaiaMarkerManager*)self.mapView.contents.markerManager showMarkersOnScreen];
}


- (void) tapOnMarker: (RMMarker*) marker onMap: (RMMapView*) map {
  if ([marker.data isEqualToString:@"ThemeCamp"]) {
    ThemeCamp * camp = [ThemeCamp campForSimpleName:[marker waypointID]];
    self.detailView = [[CampInfoViewController alloc] initWithCamp:camp];

  }
  if ([marker.data isKindOfClass:[ThemeCamp class]]) {
    self.detailView = [[CampInfoViewController alloc] initWithCamp:(ThemeCamp*)marker.data];
  } else if ([marker.data isKindOfClass:[ArtInstall class]]) {  
    self.detailView = [[ArtInfoViewController alloc] initWithArt:(ArtInstall*)marker.data];
  } else if ([marker.data isKindOfClass:[Event class]]) {  
    self.detailView = [[EventInfoViewController alloc] initWithEvent:(Event*)marker.data];
  }
	[self.navigationController pushViewController:detailView animated:YES];	
}


- (void) afterMapTouch: (RMMapView*) map{
    if ([RMMapContents performExpensiveOperations]) {
    [self showMarkersOnScreen];
  }
}





- (MapViewController *)initWithTitle: (NSString *) aTitle {
	self = [super init];
 
  lastFetchedZoom = 0.0;
  _needFetchQuadrant = 0;
  _markersNeedDisplay = 0;
	self.title = aTitle;
	[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"map.png"] tag:0];
	
  UISegmentedControl *downloadButton = [[[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObject:[UIImage imageNamed:@"home_nav_button.png"]]]autorelease];
  downloadButton.frame = CGRectMake(0,0,35,35);
  downloadButton.momentary = YES;
  downloadButton.tintColor = [UIColor blackColor];
  downloadButton.segmentedControlStyle = UISegmentedControlStyleBar;
  [downloadButton addTarget:self
                     action:@selector(home:)
           forControlEvents:UIControlEventValueChanged];
  
  locationButton = [[[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObject:[UIImage imageNamed:@"locate-icon.png"]]]autorelease];
  locationButton.frame = CGRectMake(45,0,35,35);
  locationButton.tintColor = [UIColor blackColor];
  locationButton.momentary = YES;
  locationButton.segmentedControlStyle = UISegmentedControlStyleBar;
  [locationButton addTarget:self
                     action:@selector(startLocation:)
           forControlEvents:UIControlEventValueChanged];
  UIView *buttonView = [[[UIView alloc]initWithFrame:CGRectMake(0,0,80,35)]autorelease];
  [buttonView addSubview: locationButton];
  [buttonView addSubview: downloadButton];
  UIBarButtonItem *item = [[[UIBarButtonItem alloc]initWithCustomView:buttonView]autorelease];
  [self.navigationItem setTitle:@"Black Rock City"];
	self.navigationItem.rightBarButtonItem = item;
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
											   initWithImage:[UIImage imageNamed:@"map-download-icon.png"]
											   style:UIBarButtonItemStylePlain
											   target:self
											   action:@selector(redownloadMaps:)] autorelease];
  
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showMarkersOnScreen) name:RMResumeExpensiveOperations object:nil];

  return self;
}


- (void) alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == 0) return;
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [t downloadMaps:YES];
}

- (void) redownloadMaps:(id)sender {  
  UIAlertView *av = [[[UIAlertView alloc]initWithTitle:@"Redownload maps?" message:@"Would you like to re-download all the maps, in case there have been updates?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil]autorelease];
  [av show];
}
  
-(BOOL)sphericalTrapezium:(RMSphericalTrapezium)rect containsPoint:(RMLatLong)point {
	return (rect.northeast.latitude > point.latitude &&
					rect.southwest.latitude < point.latitude &&
					rect.northeast.longitude > point.longitude &&
					rect.southwest.longitude < point.longitude);
}

- (BOOL) locateMeWorks {
	CLLocationManager *lm = [MyCLController sharedInstance].locationManager;
	if(!lm.locationServicesEnabled) return NO;
	if(lm.location == nil) return NO;
	//NSLog(@"%@", lm.location);
	BurnTileSource *tileSource = [[[BurnTileSource alloc] init] autorelease];
	RMSphericalTrapezium bounds = [tileSource latitudeLongitudeBoundingBox];
	if([self sphericalTrapezium:bounds containsPoint:lm.location.coordinate]) {
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
	if(isCurrentlyUpdating) {
    isCurrentlyUpdating = NO;
    locationButton.tintColor = self.navigationController.navigationBar.tintColor;
  } else {
    isCurrentlyUpdating = YES;
    locationButton.tintColor = [UIColor redColor];      
  }
}	


- (void) home: (id) sender {
  
  RMSphericalTrapezium bounds = [mapView.contents.tileSource latitudeLongitudeBoundingBox];
  [mapView.contents zoomWithLatLngBoundsNorthEast:bounds.northeast SouthWest:bounds.southwest];
  [mapView.contents zoomByFactor:1.55 near:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
  CLLocationCoordinate2D center = {bounds.southwest.latitude/2+bounds.northeast.latitude/2,bounds.southwest.longitude/2+bounds.northeast.longitude/2};
  [mapView.contents moveToLatLong:center];
}	


- (void)loadView {
  [super loadView];
  [self setMapView:[[[BurnMapView alloc]initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height)]autorelease]];
  BurnTileSource* bts = [[BurnTileSource alloc] init];
  NSLog(@"bts zooms %f %f", [bts minZoom], [bts maxZoom]);
  RMCachedTileSource* cts = [RMCachedTileSource cachedTileSourceWithSource:bts];
  [mapView.contents setTileSource:cts];
  [mapView setBackgroundColor:[UIColor blackColor]];
  self.view = mapView;
  self.progressView = [[[UIProgressView alloc] 
                        initWithProgressViewStyle:UIProgressViewStyleBar]autorelease];
  progressView.frame = CGRectMake(5.0, 5, 268, 9.0);
  progressView.alpha = 0;
  [self.view addSubview:self.progressView];
  [self loadCamps];

}


- (void)viewDidLoad {
  [super viewDidLoad];
	tap = YES;
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
	markerManager = [mapView markerManager];	
	[mapView setBackgroundColor:[UIColor blackColor]];
	//[mapView moveToLatLong:point];	
}

- (void) viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (tap) {
   [self home:nil];
  }
  tap = NO;
}


- (void)newLocationUpdate:(CLLocation *)newLocation {
	if (signbit(newLocation.horizontalAccuracy)) {
	} else {
    CLLocationCoordinate2D coord = newLocation.coordinate;
    if (!currentLocationMarker) {	
      currentLocationMarker = [[[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"blue_dot.gif"]] retain];
      [currentLocationMarker setProjectedLocation:[[mapView.contents projection] latLongToPoint:coord]];
      [[mapView.contents overlay] addSublayer:currentLocationMarker];	
    } else {
      [mapView.contents.markerManager moveMarker:currentLocationMarker AtLatLon:coord];
    }
  
    if(isCurrentlyUpdating) {
      [mapView.contents moveToLatLong:coord];
    }  
    
  }
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
	[errorAlert release];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


-(void)zoomMapToLocation:(double)latitude: (double) longitude {
	CLLocationCoordinate2D point;
	point.latitude = latitude;
	point.longitude = longitude;
	[mapView moveToLatLong:point];
	RMMapContents *contents = [mapView contents];
	[contents setZoom:18.0];
	self.tabBarController.selectedIndex = 0;
}

- (void)dealloc {
	[mapView release];
  [detailView release];
  [progressView release];
  [super dealloc];
}


@end