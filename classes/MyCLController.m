#import "MyCLController.h"
#import "iBurnAppDelegate.h"
#import "RMMapView.h"

// This is a singleton class, see below
static MyCLController *sharedCLDelegate = nil;
@implementation MyCLController
@synthesize delegate, locationManager, lastReading, timer;

- (id) init {
	if (self = [super init]) {
		self.locationManager = [[CLLocationManager alloc] init];
		self.locationManager.delegate = self; 
    iOSVersion = [[UIDevice currentDevice].systemVersion doubleValue];

	}
  //[self startTimer];
	return self;
}

#warning mapbox
/*BOOL sphericalTrapeziumContainsPoint(RMSphericalTrapezium rect, RMLatLong point) {
  return (rect.northeast.latitude > point.latitude && rect.southwest.latitude < point.latitude &&
          rect.northeast.longitude > point.longitude && rect.southwest.longitude < point.longitude);
}*/

#warning mapbox
// Called when the location is updated
- (void)locationManager:(CLLocationManager *)manager
	didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation {
	[self.delegate newLocationUpdate:newLocation];
  /*RMSphericalTrapezium bounds = ((RMSphericalTrapezium){.northeast = {.latitude = 40.802822, .longitude = -119.172673},
    .southwest = {.latitude = 40.759210, .longitude = -119.23454}});

  if (sphericalTrapeziumContainsPoint(bounds, newLocation.coordinate)) {
    iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
    [t liftEmbargo];
  }*/
    
}


// Called when there is an error getting the location
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {}


+ (MyCLController *)sharedInstance {
  @synchronized(self) {
    if (sharedCLDelegate == nil) {
      sharedCLDelegate = [[self alloc] init]; // assignment not done here
    }
  }
  return sharedCLDelegate;
}


- (void)dealloc {
  delegate = nil;
  [self.timer invalidate];
}


// FAKE POINT METHODS
#define FAKE_POINTS YES

int fakeTime;

- (void) startTimer {
  lastReading = (CLLocationCoordinate2D){40.78, -119.21};
  //lastReading = (CLLocationCoordinate2D){40.766, -119.12};
  fakeTime = 0;
  self.timer = [NSTimer scheduledTimerWithTimeInterval:(1)
                                            target:self
                                          selector:@selector(updateTime)
                                          userInfo:nil
                                           repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}  



- (void) postFakePoint:(int) cnt {
	//if (fakeTime % 3 != 0) return;
  
  @autoreleasepool {
    CLLocationCoordinate2D reading = lastReading;
    float randomLat = .0004 + (.0002/ (arc4random() % 10 + 1));
    float randomLon = .0004 + (.0002 / (arc4random() % 10 + 1));
    float latitude = reading.latitude + randomLat;
    float longitude = reading.longitude + randomLon;

    
    CLLocationCoordinate2D coord = {latitude, longitude};
    //NSLog(@"%@", [NSDate date]);
    CLLocation * location = [[CLLocation alloc] initWithCoordinate:coord
                                                           altitude:0
                                                 horizontalAccuracy:10
                                                   verticalAccuracy:10 
                                                          timestamp:[NSDate date]];
    lastReading = coord;
    [self locationManager:locationManager didUpdateToLocation:location fromLocation:nil];
  }
}	


- (double) getDistanceFrom:(CLLocation*)lastLocation toLocation:(CLLocation*)loc1 {
  if (iOSVersion < 3.2) {
    return [lastLocation getDistanceFrom:loc1];
  } else {
    return [lastLocation distanceFromLocation: loc1];
  }
}  


- (double) currentDistanceToLocation:(CLLocation*)location {
  return [self getDistanceFrom:location toLocation:locationManager.location];
}


- (double) latitude {
  return self.locationManager.location.coordinate.latitude;
}

-(void) updateTime {
  if (FAKE_POINTS) [self postFakePoint:0];
  fakeTime++;
}



@end