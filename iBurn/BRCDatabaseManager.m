//
//  BRCDatabaseManager.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDatabaseManager.h"
#import "YapDatabaseRelationship.h"
#import "YapDatabaseView.h"
#import "YapDatabaseFullTextSearch.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCCampObject.h"
#import "YapDatabaseFilteredView.h"
#import "NSDateFormatter+iBurn.h"
#import "NSUserDefaults+iBurn.h"
#import "YapDatabaseFilteredViewTypes.h"
#import "BRCAppDelegate.h"
#import "BRCEventsTableViewController.h"
#import "YapDatabase.h"

@interface BRCDatabaseManager()
@property (nonatomic, strong) YapDatabase *database;
@property (nonatomic, strong) YapDatabaseConnection *readWriteDatabaseConnection;
@end

@implementation BRCDatabaseManager

- (NSString *)yapDatabaseDirectory {
    NSString *applicationSupportDirectory = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *directory = [applicationSupportDirectory stringByAppendingPathComponent:applicationName];
    return directory;
}

- (NSString *)yapDatabasePathWithName:(NSString *)name
{
    
    return [[self yapDatabaseDirectory] stringByAppendingPathComponent:name];
}

- (BOOL)setupDatabaseWithName:(NSString *)name
{
    YapDatabaseOptions *options = [[YapDatabaseOptions alloc] init];
    options.corruptAction = YapDatabaseCorruptAction_Fail;
    
    NSString *databaseDirectory = [self yapDatabaseDirectory];
    if (![[NSFileManager defaultManager] fileExistsAtPath:databaseDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:databaseDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *databasePath = [self yapDatabasePathWithName:name];
    
    self.database = [[YapDatabase alloc] initWithPath:databasePath
                                           serializer:nil
                                         deserializer:nil
                                         preSanitizer:nil
                                        postSanitizer:nil
                                              options:options];
    self.database.defaultObjectPolicy = YapDatabasePolicyShare;
    self.database.defaultObjectCacheEnabled = YES;
    self.database.defaultObjectCacheLimit = 10000;
    self.database.defaultMetadataCacheEnabled = NO;
    self.readWriteDatabaseConnection = [self.database newConnection];
    self.readWriteDatabaseConnection.objectPolicy = YapDatabasePolicyShare;
    self.readWriteDatabaseConnection.name = @"readWriteDatabaseConnection";

    [self setupViewNames];
    [self registerExtensions];
    
    if (self.database) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)copyDatabaseFromBundle
{
    NSString *folderName = @"iBurn-database";
    NSString *bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folderName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
        return NO;
    }
    NSString *databaseDirectory = [self yapDatabaseDirectory];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:databaseDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:databaseDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            return NO;
        }
    }
    NSString *databasePath = [self yapDatabasePathWithName:folderName];
    
    [[NSFileManager defaultManager] copyItemAtPath:bundlePath toPath:databasePath error:&error];
    if (error) {
        return NO;
    }
    return YES;
}

- (BOOL)existsDatabaseWithName:(NSString *)databaseName
{
    NSString *databsePath = [self yapDatabasePathWithName:databaseName];
    return [[NSFileManager defaultManager] fileExistsAtPath:databsePath];
}

+ (instancetype)sharedInstance
{
    static id databaseManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        databaseManager = [[[self class] alloc] init];
    });
    
    return databaseManager;
}

- (void) setupViewNames {
    /*
     2015-06-19 10:48:18.046 iBurn[95510:3255746] Registered BRCArtObjectView 1
     2015-06-19 10:48:18.350 iBurn[95510:3255746] Registered BRCCampObjectView 1
     2015-06-19 10:48:20.423 iBurn[95510:3255746] Registered BRCEventObjectView 1
     2015-06-19 10:48:20.450 iBurn[95510:3255901] BRCEventObjectView-SelectedDayOnlyFilter 1
     2015-06-19 10:48:20.454 iBurn[95510:3255901] BRCEventObjectView-SelectedDayOnlyFilter-EventExpirationAndTypeFilter 1
     2015-06-19 10:48:20.466 iBurn[95510:3255746] Attempting to badge the application icon but haven't received permission from the user to badge the application
     2015-06-19 10:48:20.629 iBurn[95510:3255746] BRCDataObject-SearchFilter(title) ready 1
     2015-06-19 10:48:20.631 iBurn[95510:3255746] BRCArtObject-SearchFilter(title) ready 1
     2015-06-19 10:48:20.635 iBurn[95510:3255746] BRCCampObject-SearchFilter(title) ready 1
     2015-06-19 10:48:20.638 iBurn[95510:3255746] BRCEventObject-SearchFilter(title) ready 1
*/
    _artViewName = [[self class] databaseViewNameForClass:[BRCArtObject class]];
    _campsViewName = [[self class] databaseViewNameForClass:[BRCCampObject class]];
    _eventsViewName = [[self class] databaseViewNameForClass:[BRCEventObject class]];
    _dataObjectsViewName = [[self class] databaseViewNameForClass:[BRCDataObject class]];
}

- (void) registerExtensions {
    NSArray *viewsInfo = @[@[self.artViewName, [BRCArtObject class]],
                           @[self.campsViewName, [BRCCampObject class]],
                           @[self.eventsViewName, [BRCEventObject class]],
                           @[self.dataObjectsViewName, [BRCDataObject class]]];
    [viewsInfo enumerateObjectsUsingBlock:^(NSArray *viewInfo, NSUInteger idx, BOOL *stop) {
        NSString *viewName = [viewInfo firstObject];
        Class viewClass = [viewInfo lastObject];
        YapDatabaseView *view = [BRCDatabaseManager databaseViewForClass:viewClass];
        BOOL success = [[BRCDatabaseManager sharedInstance].database registerExtension:view withName:viewName];
        NSLog(@"Registered %@ %d", viewName, success);
    }];
}

+ (YapDatabaseViewGrouping*)groupingForClass:(Class)viewClass {
    YapDatabaseViewGrouping *grouping = nil;
    
    if (viewClass == [BRCEventObject class]) {
        grouping = [YapDatabaseViewGrouping withObjectBlock:^NSString *(NSString *collection, NSString *key, id object){
            if ([object isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *eventObject = (BRCEventObject*)object;
                NSDateFormatter *dateFormatter = [NSDateFormatter brc_eventGroupDateFormatter];
                NSString *groupName = [dateFormatter stringFromDate:eventObject.startDate];
                return groupName;
            }
            return nil;
        }];
    } else {
        grouping = [YapDatabaseViewGrouping withKeyBlock:^NSString *(NSString *collection, NSString *key){
            if ([collection isEqualToString:[viewClass collection]])
            {
                return [viewClass collection];
            }
            return nil;
        }];
    }
    
    return grouping;
}

+ (NSComparisonResult) compareDistanceOfFirstObject:(BRCDataObject*)object1 secondObject:(BRCDataObject*)object2 fromLocation:(CLLocation*)fromLocation {
    CLLocation *currentLocation = fromLocation;
    if (!currentLocation) {
        return NSOrderedSame;
    }
    CLLocation *location1 = [object1 location];
    CLLocationDistance distance1 = [location1 distanceFromLocation:currentLocation];
    CLLocation *location2 = [object2 location];
    CLLocationDistance distance2 = [location2 distanceFromLocation:currentLocation];
    if (location1 && !location2) {
        return NSOrderedAscending;
    } else if (!location1 && location2) {
        return NSOrderedDescending;
    } else if (!location1 && !location2) {
        return NSOrderedSame;
    }
    return [@(distance1) compare:@(distance2)];
}

+ (YapDatabaseViewSorting*)sortingForClass:(Class)viewClass {
    YapDatabaseViewSorting* sorting = nil;
    if (viewClass == [BRCEventObject class]) {
        BOOL shouldSortEventsByStartTime = [[NSUserDefaults standardUserDefaults] shouldSortEventsByStartTime];
        sorting = [YapDatabaseViewSorting withObjectBlock:^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                         NSString *collection2, NSString *key2, id obj2){
            if ([obj1 isKindOfClass:[BRCEventObject class]] && [obj2 isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event1 = (BRCEventObject *)obj1;
                BRCEventObject *event2 = (BRCEventObject *)obj2;
                
                if (event1.isAllDay && !event2.isAllDay) {
                    return NSOrderedDescending;
                }
                else if (!event1.isAllDay && event2.isAllDay) {
                    return NSOrderedAscending;
                }
                NSComparisonResult dateComparison = NSOrderedSame;
                if (shouldSortEventsByStartTime) {
                    dateComparison = [event1.startDate compare:event2.startDate];
                } else {
                    dateComparison = [event1.endDate compare:event2.endDate];
                }
                if (dateComparison == NSOrderedSame) {
                    return [event1.title compare:event2.title];
                }
                return dateComparison;
            }
            return NSOrderedSame;
        }];
    } else {
        sorting = [YapDatabaseViewSorting withObjectBlock:^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                         NSString *collection2, NSString *key2, id obj2){
            if ([obj1 isKindOfClass:viewClass] && [obj2 isKindOfClass:viewClass]) {
                BRCDataObject *data1 = (BRCDataObject *)obj1;
                BRCDataObject *data2 = (BRCDataObject *)obj2;
                return [data1.title compare:data2.title];
            }
            return NSOrderedSame;
        }];
    }
    return sorting;
}

/**
 *  Does not register the view, but checks if it is registered and returns
 *  the registered view if it exists. (Caller should register the view)
 */
+ (YapDatabaseView*) databaseViewForClass:(Class)viewClass
{
    YapDatabaseViewGrouping *grouping = [[self class] groupingForClass:viewClass];
    YapDatabaseViewSorting *sorting = [[self class] sortingForClass:viewClass];
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    NSString *versionTag = @"1";
    options.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:[viewClass collection]]];
    
    YapDatabaseView *databaseView =
    [[YapDatabaseView alloc] initWithGrouping:grouping
                                      sorting:sorting
                                   versionTag:versionTag
                                      options:options];
    return databaseView;
}

+ (NSString*) fullTextSearchNameForClass:(Class)viewClass
                   withIndexedProperties:(NSArray *)properties {
    NSMutableString *viewName = [NSMutableString stringWithString:NSStringFromClass(viewClass)];
    [viewName appendString:@"-SearchFilter("];
    [properties enumerateObjectsUsingBlock:^(NSString *property, NSUInteger idx, BOOL *stop) {
        [viewName appendString:property];
        if (idx - 1 < properties.count) {
            [viewName appendString:@","];
        }
    }];
    [viewName appendString:@")"];
    return viewName;
}

+ (YapDatabaseFullTextSearch*) fullTextSearchForClass:(Class)viewClass
                                withIndexedProperties:(NSArray *)properties
{
    YapDatabaseFullTextSearchHandler *searchHandler = [YapDatabaseFullTextSearchHandler withObjectBlock:^(NSMutableDictionary *dict, NSString *collection, NSString *key, id object) {
        
        [properties enumerateObjectsUsingBlock:^(NSString *property, NSUInteger idx, BOOL *stop) {
            if ([object isKindOfClass:viewClass]) {
                if ([object respondsToSelector:NSSelectorFromString(property)]) {
                    if ([object valueForKey:property] != nil && ![[object valueForKey:property] isEqual:[NSNull null]]) {
                        //may have to check if NSString and NSURL have length?
                        
                        [dict setObject:[object valueForKey:property] forKey:property];
                    }
                }
            }
        }];
    }];
    
    YapDatabaseFullTextSearch *fullTextSearch = [[YapDatabaseFullTextSearch alloc] initWithColumnNames:properties
                                                                                               handler:searchHandler];
    return fullTextSearch;
}

+ (YapDatabaseViewFiltering*) favoritesOnlyFiltering {
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(NSString *group, NSString *collection, NSString *key, id object) {
        if ([object isKindOfClass:[BRCDataObject class]]) {
            BRCDataObject *dataObject = (BRCDataObject*)object;
            return dataObject.isFavorite;
        }
        return NO;
    }];
    return filtering;
}

/**
 *  Does not register the view, but checks if it is registered and returns
 *  the registered view if it exists. (Caller should register the view)
 */
+ (YapDatabaseFilteredView*) filteredViewForType:(BRCDatabaseFilteredViewType)filterType
                                  parentViewName:(NSString*)parentViewName
                              allowedCollections:(YapWhitelistBlacklist*)allowedCollections
{

    YapDatabaseViewFiltering *filtering = nil;
    if (filterType == BRCDatabaseFilteredViewTypeEverything) {
        filtering = [[self class] allItemsFiltering];
    } else if (filterType == BRCDatabaseFilteredViewTypeFavoritesOnly) {
        filtering = [[self class] favoritesOnlyFiltering];
    } else if (filterType == BRCDatabaseFilteredViewTypeEventExpirationAndType) {
        filtering = [[self class] eventsFiltering];
    } else if (filterType == BRCDatabaseFilteredViewTypeEventSelectedDayOnly) {
        filtering = [[self class] eventsSelectedDayOnlyFiltering];
    }
    
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    if (allowedCollections) {
        options.allowedCollections = allowedCollections;
    }
    YapDatabaseFilteredView *filteredView =
    [[YapDatabaseFilteredView alloc] initWithParentViewName:parentViewName
                                                  filtering:filtering
                                                 versionTag:[[NSUUID UUID] UUIDString]
                                                    options:options];
    return filteredView;
}

+ (NSString*) stringForFilteredExtensionType:(BRCDatabaseFilteredViewType)extensionType {
    switch (extensionType) {
        case BRCDatabaseFilteredViewTypeEventSelectedDayOnly:
            return @"SelectedDayOnly";
            break;
        case BRCDatabaseFilteredViewTypeEventExpirationAndType:
            return @"EventExpirationAndType";
            break;
        case BRCDatabaseFilteredViewTypeFavoritesOnly:
            return @"FavoritesOnly";
            break;
        case BRCDatabaseFilteredViewTypeFullTextSearch:
            return @"Search";
            break;
        case BRCDatabaseFilteredViewTypeEverything:
            return @"Everything";
            break;
        default:
            return nil;
            break;
    }
}

+ (NSString*) filteredViewNameForType:(BRCDatabaseFilteredViewType)filterType
                       parentViewName:(NSString*)parentViewName {
    NSString *extensionString = [self stringForFilteredExtensionType:filterType];
    NSParameterAssert(parentViewName != nil);
    NSParameterAssert(extensionString != nil);
    return [NSString stringWithFormat:@"%@-%@Filter", parentViewName, extensionString];
}

+ (NSString*) databaseViewNameForClass:(Class)viewClass {
    NSString *classString = NSStringFromClass(viewClass);
    return [NSString stringWithFormat:@"%@View", classString];
}

+ (YapDatabaseViewFiltering*) allItemsFiltering {
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withKeyBlock:^BOOL(NSString *group, NSString *collection, NSString *key) {
        return YES;
    }];
    return filtering;
}


+ (YapDatabaseViewFiltering*) eventsSelectedDayOnlyFiltering
{
    BRCEventsTableViewController *eventsVC = [BRCAppDelegate appDelegate].eventsViewController;
    NSString *selectedDayGroup = [[NSDateFormatter brc_eventGroupDateFormatter] stringFromDate:eventsVC.selectedDay];
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withKeyBlock:^BOOL (NSString *group, NSString *collection, NSString *key)
    {
        return [group isEqualToString:selectedDayGroup];
    }];
    return filtering;
}

+ (YapDatabaseViewFiltering*) eventsFiltering {
    BOOL showExpiredEvents = [[NSUserDefaults standardUserDefaults] showExpiredEvents];
    
    NSSet *filteredSet = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] selectedEventTypes]];
    
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(NSString *group, NSString *collection, NSString *key, id object) {
        if ([object isKindOfClass:[BRCEventObject class]]) {
            BRCEventObject *eventObject = (BRCEventObject*)object;
            BOOL eventHasEnded = eventObject.hasEnded || eventObject.isEndingSoon;
            BOOL eventMatchesTypeFilter = [filteredSet containsObject:@(eventObject.eventType)];
            
            if ((eventMatchesTypeFilter || [filteredSet count] == 0)) {
                if (showExpiredEvents) {
                    return YES;
                } else {
                    return !eventHasEnded;
                }
            }
            
        }
        return NO;
    }];
    
    return filtering;
}

@end
