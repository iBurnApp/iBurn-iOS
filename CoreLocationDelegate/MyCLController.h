// This protocol is used to send the text for location updates back to another view controller
@protocol MyCLControllerDelegate <NSObject>
@required
- (void) newLocationUpdate:(CLLocation *)newLocation;
- (void) newError:(NSString *)text;
@end


// Class definition
@interface MyCLController : NSObject <CLLocationManagerDelegate> {
	CLLocationManager *locationManager;
	id __unsafe_unretained delegate;
  double iOSVersion;
  CLLocationCoordinate2D lastReading;
}

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CLLocationCoordinate2D lastReading;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, unsafe_unretained) id <MyCLControllerDelegate> delegate;


- (void)locationManager:(CLLocationManager *)manager
	didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation;

- (void)locationManager:(CLLocationManager *)manager
	   didFailWithError:(NSError *)error;

- (double) currentDistanceToLocation:(CLLocation*)location;

+ (MyCLController *)sharedInstance;

@end

