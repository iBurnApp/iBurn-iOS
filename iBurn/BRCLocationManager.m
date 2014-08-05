//
//  BRCLocationManager.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCLocationManager.h"
#import "BRCDatabaseManager.h"
#import "BRCDataObject.h"
#import "YapDatabaseViewTransaction.h"
#import "NSUserDefaults+iBurn.h"

static const CLLocationDistance kBRCMinimumAccuracy = 50.0f;

@interface BRCLocationManager()
@property (nonatomic, strong, readwrite) CLLocationManager *locationManager;
@property (nonatomic, strong, readwrite) CLLocation *recentLocation;
@end

@implementation BRCLocationManager

- (instancetype) init {
    if (self = [super init]) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.recentLocation = [NSUserDefaults standardUserDefaults].recentLocation;
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

- (void) updateRecentLocation {
    [self.locationManager startUpdatingLocation];
}

- (void) setRecentLocation:(CLLocation *)recentLocation {
    NSString *key = NSStringFromSelector(@selector(recentLocation));
    [self willChangeValueForKey:key];
    _recentLocation = recentLocation;
    [self didChangeValueForKey:key];
    [NSUserDefaults standardUserDefaults].recentLocation = recentLocation;
}

- (void)locationManager:(CLLocationManager *)manager
	 didUpdateLocations:(NSArray *)locations {
    CLLocation *mostRecent = [locations lastObject];
    if (mostRecent.horizontalAccuracy > 0 && mostRecent.horizontalAccuracy < kBRCMinimumAccuracy) {
        self.recentLocation = mostRecent;
    }
    [self.locationManager stopUpdatingLocation];
}


@end
