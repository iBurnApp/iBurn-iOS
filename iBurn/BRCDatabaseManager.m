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
#import "YapDatabaseSearchResultsView.h"
#import "NSDate+iBurn.h"

NSString * const kBRCDatabaseName = @"iBurn-2015.sqlite";

typedef NS_ENUM(NSUInteger, BRCDatabaseFilteredViewType) {
    BRCDatabaseFilteredViewTypeUnknown,
    BRCDatabaseFilteredViewTypeEverything,
    BRCDatabaseFilteredViewTypeFavoritesOnly,
    BRCDatabaseFilteredViewTypeEventExpirationAndType,
    BRCDatabaseFilteredViewTypeEventSelectedDayOnly,
    BRCDatabaseFilteredViewTypeFullTextSearch
};

@interface BRCDatabaseManager()
@property (nonatomic, strong) YapDatabase *database;
@property (nonatomic, strong) YapDatabaseConnection *readWriteConnection;
@end

@implementation BRCDatabaseManager

- (instancetype) init {
    if (self = [self initWithDatabaseName:kBRCDatabaseName]) {
    }
    return self;
}

+ (NSString *)yapDatabaseDirectory {
    NSString *applicationSupportDirectory = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *directory = [applicationSupportDirectory stringByAppendingPathComponent:applicationName];
    return directory;
}

+ (NSString *)yapDatabasePathWithName:(NSString *)name
{
    
    return [[self yapDatabaseDirectory] stringByAppendingPathComponent:name];
}

- (instancetype) initWithDatabaseName:(NSString *)databaseName
{
    self = [super init];
    if (!self) {
        return nil;
    }
    if (![[self class] existsDatabaseWithName:databaseName]) {
        BOOL copySuccessful = [[self class] copyDatabaseFromBundle];
        if (!copySuccessful) {
            NSLog(@"DB copy from bundle unsuccessful!");
        }
    }
    
    YapDatabaseOptions *options = [[YapDatabaseOptions alloc] init];
    options.corruptAction = YapDatabaseCorruptAction_Fail;
    
    NSString *databaseDirectory = [[self class] yapDatabaseDirectory];
    if (![[NSFileManager defaultManager] fileExistsAtPath:databaseDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:databaseDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *databasePath = [[self class] yapDatabasePathWithName:databaseName];
    
    self.database = [[YapDatabase alloc] initWithPath:databasePath
                                           serializer:nil
                                         deserializer:nil
                                         preSanitizer:nil
                                        postSanitizer:nil
                                              options:options];
    
    NSURL *dbURL = [NSURL fileURLWithPath:databasePath];
    NSError *error = nil;
    BOOL success = [dbURL setResourceValue:@YES forKey: NSURLIsExcludedFromBackupKey error:&error];
    if (!success) {
        NSLog(@"Error excluding %@ from backup %@", dbURL, error);
    }
    
    self.database.defaultObjectPolicy = YapDatabasePolicyShare;
    self.database.defaultObjectCacheEnabled = YES;
    self.database.defaultObjectCacheLimit = 10000;
    self.database.defaultMetadataCacheEnabled = NO;
    self.readWriteConnection = [self.database newConnection];
    self.readWriteConnection.objectPolicy = YapDatabasePolicyShare;
    self.readWriteConnection.name = @"readWriteConnection";
    _readConnection = [self.database newConnection];

    [self setupViewNames];
    [self registerExtensions];
    
    if (self.database) {
        return self;
    } else {
        return nil;
    }
}

+ (BOOL)copyDatabaseFromBundle
{
    NSString *folderName = @"iBurn-database";
    NSString *bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folderName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
        return NO;
    }
    NSString *databaseDirectory = [[self class]yapDatabaseDirectory];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:databaseDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:databaseDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            return NO;
        }
    }
    NSString *databasePath = [[self class] yapDatabasePathWithName:folderName];
    
    [[NSFileManager defaultManager] copyItemAtPath:bundlePath toPath:databasePath error:&error];
    if (error) {
        return NO;
    }
    return YES;
}

 + (BOOL)existsDatabaseWithName:(NSString *)databaseName
{
    NSString *databsePath = [[self class] yapDatabasePathWithName:databaseName];
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

// Call this before registerExtensions
- (void) setupViewNames {
    _artViewName = [[self class] databaseViewNameForClass:[BRCArtObject class]];
    _campsViewName = [[self class] databaseViewNameForClass:[BRCCampObject class]];
    _eventsViewName = [[self class] databaseViewNameForClass:[BRCEventObject class]];
    _dataObjectsViewName = [[self class] databaseViewNameForClass:[BRCDataObject class]];
    
    _ftsArtName = [[self class] fullTextSearchNameForClass:[BRCArtObject class] withIndexedProperties:[[self class] fullTextSearchIndexProperties]];
    _ftsCampsName = [[self class] fullTextSearchNameForClass:[BRCCampObject class] withIndexedProperties:[[self class] fullTextSearchIndexProperties]];
    _ftsEventsName = [[self class] fullTextSearchNameForClass:[BRCEventObject class] withIndexedProperties:[[self class] fullTextSearchIndexProperties]];
    _ftsDataObjectName = [[self class] fullTextSearchNameForClass:[BRCDataObject class] withIndexedProperties:[[self class] fullTextSearchIndexProperties]];
    
    _eventsFilteredByDayViewName = [[self class] filteredViewNameForType:BRCDatabaseFilteredViewTypeEventSelectedDayOnly parentViewName:self.eventsViewName];
    _eventsFilteredByDayExpirationAndTypeViewName = [[self class] filteredViewNameForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.eventsFilteredByDayViewName];
    _everythingFilteredByFavorite = [self.dataObjectsViewName stringByAppendingString:@"-FavoritesFilter"];
    
    NSString *searchSuffix = @"-SearchView";
    _searchArtView = [self.ftsArtName stringByAppendingString:searchSuffix];
    _searchCampsView = [self.ftsCampsName stringByAppendingString:searchSuffix];
    _searchEventsView = [self.ftsEventsName stringByAppendingString:searchSuffix];
    _searchFavoritesView = [self.everythingFilteredByFavorite stringByAppendingString:searchSuffix];
}

#pragma mark Registration

- (void) registerExtensions {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self registerRegularViews];
        [self registerFullTextSearch];
        [self registerFilteredViews];
        [self registerSearchViews];
    });
}

- (void) registerRegularViews {
    // Register regular views
    NSArray *viewsInfo = @[@[self.artViewName, [BRCArtObject class]],
                           @[self.campsViewName, [BRCCampObject class]],
                           @[self.eventsViewName, [BRCEventObject class]]];
    [viewsInfo enumerateObjectsUsingBlock:^(NSArray *viewInfo, NSUInteger idx, BOOL *stop) {
        NSString *viewName = [viewInfo firstObject];
        Class viewClass = [viewInfo lastObject];
        YapWhitelistBlacklist *allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:[viewClass collection]]];
        YapDatabaseView *view = [BRCDatabaseManager databaseViewForClass:viewClass allowedCollections:allowedCollections];
        BOOL success = [[BRCDatabaseManager sharedInstance].database registerExtension:view withName:viewName];
        NSLog(@"Registered %@ %d", viewName, success);
    }];
    YapDatabaseView *dataObjectsView = [BRCDatabaseManager databaseViewForClass:[BRCDataObject class] allowedCollections:nil];
    BOOL success = [[BRCDatabaseManager sharedInstance].database registerExtension:dataObjectsView withName:self.dataObjectsViewName];
    NSLog(@"Registered %@ %d", self.dataObjectsViewName, success);
}

- (void) registerFullTextSearch {
    NSArray *indexedProperties = [[self class] fullTextSearchIndexProperties];
    NSArray *ftsInfoArray = @[@[self.ftsArtName, [BRCArtObject class], indexedProperties],
                              @[self.ftsCampsName, [BRCCampObject class], indexedProperties],
                              @[self.ftsEventsName, [BRCEventObject class], indexedProperties],
                              @[self.ftsDataObjectName, [BRCDataObject class], indexedProperties]];
    [ftsInfoArray enumerateObjectsUsingBlock:^(NSArray *ftsInfo, NSUInteger idx, BOOL *stop) {
        NSString *ftsName = ftsInfo[0];
        Class viewClass = ftsInfo[1];
        NSArray *indexedProperties = ftsInfo[2];
        YapDatabaseFullTextSearch *fullTextSearch = [BRCDatabaseManager fullTextSearchForClass:viewClass withIndexedProperties:indexedProperties];
        BOOL success = [[BRCDatabaseManager sharedInstance].database registerExtension:fullTextSearch withName:ftsName];
        NSLog(@"%@ ready %d", ftsName, success);
    }];
}

- (void) registerFilteredViews {
    // Register filtered views
    BOOL success = NO;
    NSSet *allowedCollections = [NSSet setWithArray:@[[[BRCEventObject class] collection]]];
    YapWhitelistBlacklist *whitelist = [[YapWhitelistBlacklist alloc] initWithWhitelist:allowedCollections];
    YapDatabaseFilteredView *filteredByDayView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventSelectedDayOnly parentViewName:self.eventsViewName allowedCollections:whitelist];
    success = [[BRCDatabaseManager sharedInstance].database registerExtension:filteredByDayView withName:self.eventsFilteredByDayViewName];
    NSLog(@"%@ %d", self.eventsFilteredByDayViewName, success);
    
    YapDatabaseFilteredView *filteredByExpiryAndTypeView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.eventsFilteredByDayViewName allowedCollections:whitelist];
    success = [[BRCDatabaseManager sharedInstance].database registerExtension:filteredByExpiryAndTypeView withName:self.eventsFilteredByDayExpirationAndTypeViewName];
    NSLog(@"%@ %d", self.eventsFilteredByDayExpirationAndTypeViewName, success);
    
    YapDatabaseFilteredView *favoritesFiltering = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeFavoritesOnly parentViewName:self.dataObjectsViewName allowedCollections:nil];
    success = [[BRCDatabaseManager sharedInstance].database registerExtension:favoritesFiltering withName:self.everythingFilteredByFavorite];
    NSLog(@"%@ %d", self.everythingFilteredByFavorite, success);
}

- (void) registerSearchViews {
    // search view name, parent view name, fts name
    NSArray *searchInfoArrays = @[@[self.searchArtView, self.artViewName, self.ftsArtName],
                                  @[self.searchCampsView, self.campsViewName, self.ftsCampsName],
                                  @[self.searchEventsView, self.eventsViewName, self.ftsEventsName],
                                  @[self.searchFavoritesView, self.everythingFilteredByFavorite, self.ftsDataObjectName]];
    
    [searchInfoArrays enumerateObjectsUsingBlock:^(NSArray *searchInfoArray, NSUInteger idx, BOOL *stop) {
        NSString *searchViewName = searchInfoArray[0];
        NSString *parentViewName = searchInfoArray[1];
        NSString *ftsName = searchInfoArray[2];
        
        YapDatabaseSearchResultsViewOptions *searchViewOptions = [[YapDatabaseSearchResultsViewOptions alloc] init];
        
        YapDatabaseSearchResultsView *searchResultsView = [[YapDatabaseSearchResultsView alloc] initWithFullTextSearchName:ftsName
                                                                                                            parentViewName:parentViewName
                                                                                                                versionTag:@"2"
                                                                                                                   options:searchViewOptions];
        
        BOOL success = [self.database registerExtension:searchResultsView withName:searchViewName];
        NSLog(@"%@ %d", searchViewName, success);
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
    } else if (viewClass == [BRCDataObject class]) {
        grouping = [YapDatabaseViewGrouping withKeyBlock:^NSString *(NSString *collection, NSString *key){
            return collection;
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
                dateComparison = [event1.startDate compare:event2.startDate];
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
+ (YapDatabaseView*) databaseViewForClass:(Class)viewClass allowedCollections:(YapWhitelistBlacklist*)allowedCollections
{
    YapDatabaseViewGrouping *grouping = [[self class] groupingForClass:viewClass];
    YapDatabaseViewSorting *sorting = [[self class] sortingForClass:viewClass];
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    NSString *versionTag = @"2";
    if (options.allowedCollections) {
        options.allowedCollections = allowedCollections;
    }
    YapDatabaseView *databaseView =
    [[YapDatabaseView alloc] initWithGrouping:grouping
                                      sorting:sorting
                                   versionTag:versionTag
                                      options:options];
    return databaseView;
}

+ (NSArray*) fullTextSearchIndexProperties {
    return @[NSStringFromSelector(@selector(title)),
             NSStringFromSelector(@selector(artistName)),
             NSStringFromSelector(@selector(detailDescription)),
             NSStringFromSelector(@selector(campName)),
             NSStringFromSelector(@selector(artName))];
}

+ (NSString*) fullTextSearchNameForClass:(Class)viewClass
                   withIndexedProperties:(NSArray *)properties {
    NSMutableString *viewName = [NSMutableString stringWithString:NSStringFromClass(viewClass)];
    [viewName appendString:@"-SearchFilter("];
    [properties enumerateObjectsUsingBlock:^(NSString *property, NSUInteger idx, BOOL *stop) {
        [viewName appendFormat:@"%@,", property];
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
        filtering = [[self class] eventsFilteredByExpirationAndType];
    } else if (filterType == BRCDatabaseFilteredViewTypeEventSelectedDayOnly) {
        filtering = [[self class] eventsFilteredByToday];
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

+ (YapDatabaseViewFiltering*) eventsFilteredByToday {
    NSDate *validDate = [[NSDate date] brc_dateWithinStartDate:[BRCEventObject festivalStartDate] endDate:[BRCEventObject festivalEndDate]];
    return [self eventsFilteredByDay:validDate];
}

+ (YapDatabaseViewFiltering*) eventsFilteredByDay:(NSDate*)day
{
    NSString *selectedDayGroup = [[NSDateFormatter brc_eventGroupDateFormatter] stringFromDate:day];
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withKeyBlock:^BOOL (NSString *group, NSString *collection, NSString *key)
    {
        return [group isEqualToString:selectedDayGroup];
    }];
    return filtering;
}

+ (YapDatabaseViewFiltering*) eventsFilteredByExpirationAndType {
    BOOL showExpiredEvents = [[NSUserDefaults standardUserDefaults] showExpiredEvents];
    NSSet *filteredSet = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] selectedEventTypes]];
    return [[self class] eventsFilteredByExpiration:showExpiredEvents eventTypes:filteredSet];
}

+ (YapDatabaseViewFiltering*) eventsFilteredByExpiration:(BOOL)showExpired eventTypes:(NSSet*)eventTypes {
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(NSString *group, NSString *collection, NSString *key, id object) {
        if ([object isKindOfClass:[BRCEventObject class]]) {
            BRCEventObject *eventObject = (BRCEventObject*)object;
            BOOL eventHasEnded = eventObject.hasEnded || eventObject.isEndingSoon;
            BOOL eventMatchesTypeFilter = [eventTypes containsObject:@(eventObject.eventType)];
            
            if ((eventMatchesTypeFilter || [eventTypes count] == 0)) {
                if (showExpired) {
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

/** Updates event filtered views based on newly selected preferences */
- (void) refreshEventFilteredViewsWithSelectedDay:(NSDate*)selectedDay completionBlock:(dispatch_block_t)completionBlock {
    [self.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        YapDatabaseViewFiltering *selectedDayFiltering = [BRCDatabaseManager eventsFilteredByDay:selectedDay];
        YapDatabaseFilteredViewTransaction *filteredDayTransaction = [transaction ext:self.eventsFilteredByDayViewName];
        [filteredDayTransaction setFiltering:selectedDayFiltering versionTag:[[NSUUID UUID] UUIDString]];
        
        YapDatabaseViewFiltering *eventsAndTypesFiltering = [BRCDatabaseManager eventsFilteredByExpirationAndType];
        YapDatabaseFilteredViewTransaction *filteredExpirationAndTypeTransaction = [transaction ext:self.eventsFilteredByDayExpirationAndTypeViewName];
        [filteredExpirationAndTypeTransaction setFiltering:eventsAndTypesFiltering versionTag:[[NSUUID UUID] UUIDString]];
    } completionBlock:completionBlock];
}

/** Refresh events sorting if selected by expiration/start time */
- (void) refreshEventsSortingWithCompletionBlock:(dispatch_block_t)completionBlock {
    [self.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction ext:self.eventsViewName];
        if (!viewTransaction) {
            return;
        }
        Class viewClass = [BRCEventObject class];
        YapDatabaseViewGrouping *grouping = [BRCDatabaseManager groupingForClass:viewClass];
        YapDatabaseViewSorting *sorting = [BRCDatabaseManager sortingForClass:viewClass];
        [viewTransaction setGrouping:grouping sorting:sorting versionTag:[[NSUUID UUID] UUIDString]];
    } completionBlock:completionBlock];
}

@end
