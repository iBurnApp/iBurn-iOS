
// This protocol is used to send the text for location updates back to another view controller
@protocol MyCLControllerDelegate <NSObject>
@required
- (void) newLocationUpdate:(CLLocation *)newLocation;
@end


// Class definition
@interface MyCLController : NSObject <CLLocationManagerDelegate> {
	CLLocationManager *locationManager;
	id __unsafe_unretained delegate;
  CLLocationCoordinate2D lastReading;
}

@property (nonatomic, assign) CLLocationCoordinate2D lastReading;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, unsafe_unretained) id <MyCLControllerDelegate> delegate;


- (double) currentDistanceToLocation:(CLLocation*)location;
+ (MyCLController *)sharedInstance;

@end

