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

static const CLLocationDistance kBRCMinimumAccuracy = 50.0f;

@interface BRCLocationManager()
@property (nonatomic, strong, readwrite) CLLocationManager *locationManager;
@property (nonatomic, strong, readwrite) YapDatabaseConnection *databaseConnection;
@property (nonatomic, strong, readwrite) CLLocation *recentLocation;
@end

@implementation BRCLocationManager

- (instancetype) init {
    if (self = [super init]) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.databaseConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
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

- (void)locationManager:(CLLocationManager *)manager
	 didUpdateLocations:(NSArray *)locations {
    CLLocation *mostRecent = [locations lastObject];
    if (mostRecent.horizontalAccuracy > 0 && mostRecent.horizontalAccuracy < kBRCMinimumAccuracy) {
        self.recentLocation = mostRecent;
    }
    [self.locationManager stopUpdatingLocation];
}

- (void) updateDistanceForAllObjectsOfClass:(Class)objectClass
                               fromLocation:(CLLocation*)location
                            completionBlock:(dispatch_block_t)completionBlock {
    NSParameterAssert(location != nil);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Updating distances for %@...", NSStringFromClass(objectClass));
        NSString *collection = [objectClass collection];
        [self.databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            NSArray *allKeys = [transaction allKeysInCollection:collection];
            [allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
                BRCDataObject *object = [[transaction objectForKey:key inCollection:collection] copy];
                CLLocation *objectLocation = object.location;
                CLLocationDistance distance = CLLocationDistanceMax;
                if (objectLocation) {
                    distance = [objectLocation distanceFromLocation:location];
                }
                object.distanceFromUser = distance;
                [transaction setObject:object forKey:object.uniqueID inCollection:collection];
            }];
        } completionBlock:completionBlock];
    });
}

@end
