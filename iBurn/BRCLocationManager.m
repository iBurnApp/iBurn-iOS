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

- (NSArray *) subarrayRangesForArrayCount:(NSUInteger)count splitCount:(NSUInteger)splitCount {
    NSMutableArray *arrayOfRanges = [NSMutableArray array];
    NSUInteger itemsRemaining = count;
    NSUInteger maxItemsPerArray = count / splitCount;
    
    NSRange range;
    for (int i = 0; i < count; i += range.length) {
        range = NSMakeRange(i, MIN(maxItemsPerArray, itemsRemaining));
        NSValue *value = [NSValue valueWithRange:range];
        [arrayOfRanges addObject:value];
        itemsRemaining -= range.length;
    }
    return arrayOfRanges;
}

- (void) updateDistanceForAllObjectsOfClass:(Class)objectClass
                                      group:(NSString*)group
                               fromLocation:(CLLocation*)location
                            completionBlock:(dispatch_block_t)completionBlock {
    NSParameterAssert(location != nil);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDate *startDate = [NSDate date];
        __block NSUInteger allKeysInGroup = 0;
        NSUInteger arraySplitCount = 10;
        NSString *viewName = [BRCDatabaseManager extensionNameForClass:objectClass extensionType:BRCDatabaseViewExtensionTypeDistance];
        YapDatabaseConnection *readOnlyConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        [readOnlyConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            YapDatabaseViewTransaction *viewTransaction = [transaction ext:viewName];
            allKeysInGroup = [viewTransaction numberOfKeysInGroup:group];
        }];
        NSLog(@"Updating distances for %d items %@ (group: %@)...", (int)allKeysInGroup, NSStringFromClass(objectClass), group);
        
        NSArray *subarrayRanges = [self subarrayRangesForArrayCount:allKeysInGroup splitCount:arraySplitCount];
        
        [subarrayRanges enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger idx, BOOL *stop) {
            NSRange range = [value rangeValue];
            [[[BRCDatabaseManager sharedInstance].database newConnection] readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                YapDatabaseViewTransaction *viewTransaction = [transaction ext:viewName];
                NSMutableArray *objectsToBeUpdated = [NSMutableArray arrayWithCapacity:range.length];
                [viewTransaction enumerateKeysAndObjectsInGroup:group withOptions:0 range:range usingBlock:^(NSString *collection, NSString *key, BRCDataObject *object, NSUInteger index, BOOL *stop) {
                    object = [object copy];
                    CLLocation *objectLocation = object.location;
                    CLLocationDistance distance = CLLocationDistanceMax;
                    if (objectLocation) {
                        distance = [objectLocation distanceFromLocation:location];
                    }
                    if (distance == 0 || distance == CLLocationDistanceMax) {
                        NSLog(@"No distance for %@", object);
                    }
                    object.distanceFromUser = distance;
                    object.lastDistanceUpdateLocation = location;
                    [objectsToBeUpdated addObject:object];
                }];
                [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *readWriteTransaction) {
                    [objectsToBeUpdated enumerateObjectsUsingBlock:^(BRCDataObject *object, NSUInteger idx, BOOL *stop) {
                        [readWriteTransaction setObject:object forKey:object.uniqueID inCollection:group];
                    }];
                    NSLog(@"Updating %d items %@ (group: %@) for range %@", (int)objectsToBeUpdated.count, NSStringFromClass(objectClass), group, value);
                }];
            }];
        }];
        NSDate *endDate = [NSDate date];
        NSTimeInterval timeTaken = [endDate timeIntervalSinceDate:startDate];
        NSLog(@"Finished updating distances for %d items %@ (group: %@) in %f seconds", (int)allKeysInGroup, NSStringFromClass(objectClass), group, timeTaken);
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}



@end
