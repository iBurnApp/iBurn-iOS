//
//  Networking.h
//  TrailBehind
//

#import <Foundation/Foundation.h>
#import "Reachability.h"

@interface Networking : NSObject {
  int processCount;
  Reachability* reachability;
  BOOL offlineMode;
}

@property (nonatomic, assign) int processCount;
@property (nonatomic, strong) NSDate *lastWarning;


+ (Networking*)sharedInstance;
- (BOOL) canConnectToInternet;
- (BOOL) canConnectToInternetWithWarning:(NSString*)message;
- (void) emailSuccess;
- (void) printStatus;
- (void) foreground;
- (void) background;
- (BOOL) connectionIs3g;

@end

