//
//  BRCDatabaseManager.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDatabaseManager.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCCampObject.h"
#import "NSDateFormatter+iBurn.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCAppDelegate.h"
#import "NSDate+iBurn.h"
#import "BRCUpdateInfo.h"
#import "iBurn-Swift.h"
@import YapDatabase;

/** this is posted when an extension is ready. The userInfo contains
 the extension name under the "extensionName" key */
NSString * const BRCDatabaseExtensionRegisteredNotification = @"BRCDatabaseExtensionRegisteredNotification";

static NSString * const RTreeMinLat = @"RTreeMinLat";
static NSString * const RTreeMaxLat = @"RTreeMaxLat";
static NSString * const RTreeMinLon = @"RTreeMinLon";
static NSString * const RTreeMaxLon = @"RTreeMaxLon";

NSString * const kBRCDatabaseName = @"iBurn-2025.sqlite";
NSString * const kBRCDatabaseFolderName = @"iBurn-2025";

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
    directory = [directory stringByAppendingPathComponent:kBRCDatabaseFolderName];
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
        BOOL copySuccessful = [BRCDataImporter copyDatabaseFromBundle];
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
    
    NSURL *dbURL = [NSURL fileURLWithPath:databasePath];
    
    self.database = [[YapDatabase alloc] initWithURL:dbURL options:options];
    
#if DEBUG
    NSLog(@"Using database at path: %@", dbURL);
#endif
    
    NSError *error = nil;
    BOOL success = [dbURL setResourceValue:@YES forKey: NSURLIsExcludedFromBackupKey error:&error];
    if (!success) {
        NSLog(@"Error excluding %@ from backup %@", dbURL, error);
    }
    
    YapDatabaseConnectionConfig *config = self.database.connectionDefaults;
    config.objectCacheEnabled = YES;
    config.objectCacheLimit = 10000;
    config.metadataCacheEnabled = YES;
    self.readWriteConnection = [self.database newConnection];
    self.readWriteConnection.name = @"readWriteConnection";
    _backgroundReadConnection = [self.database newConnection];
    
    _longLived = [[LongLivedConnectionManager alloc] initWithDatabase:self.database];
//#if DEBUG
//    self.readConnection.permittedTransactions = YDB_AnyReadTransaction;
//    self.readWriteConnection.permittedTransactions = YDB_AnyReadWriteTransaction;
//#endif
    
    [self setupViewNames];
    [self registerExtensions];
    
    if (self.database) {
        return self;
    } else {
        return nil;
    }
}

 + (BOOL)existsDatabaseWithName:(NSString *)databaseName
{
    NSString *databsePath = [[self class] yapDatabasePathWithName:databaseName];
    return [[NSFileManager defaultManager] fileExistsAtPath:databsePath];
}

+ (BRCDatabaseManager*) shared {
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
    _searchObjectsViewName = [[[self class] databaseViewNameForClass:[BRCDataObject class]] stringByAppendingString:@"SearchObjects"];
    _audioTourViewName = @"AudioTour";
    _artImagesViewName = @"ObjectsWithImages";
    
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
    _searchEverythingView = [self.ftsDataObjectName stringByAppendingString:searchSuffix];
    _searchFavoritesView = [self.everythingFilteredByFavorite stringByAppendingString:searchSuffix];

    _rTreeIndex = @"RTreeIndex";
    _relationships = @"relationships";
}

- (YapDatabaseConnection*) uiConnection {
    return self.longLived.connection;
}

#pragma mark Registration

- (void) postExtensionRegisteredNotification:(NSString*)extensionName {
    NSParameterAssert(extensionName != nil);
    if (!extensionName) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BRCDatabaseExtensionRegisteredNotification object:self userInfo:@{@"extensionName":extensionName}];
    });
}

- (void) registerExtensions {
    dispatch_block_t registerExtensions = ^{
        [self registerRegularViews];
        [self registerFullTextSearch];
        [self registerFilteredViews];
        [self registerSearchViews];
        [self registerRTreeIndex];
        [self registerRelationships];
    };
#if DEBUG
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    // This can make it easier when writing tests
    if (environment[@"SYNC_DB_STARTUP"]) {
        registerExtensions();
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), registerExtensions);
    }
#else
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), registerExtensions);
#endif
}

- (void) registerRelationships {
    NSString *viewName = self.relationships;
    YapDatabaseRelationshipOptions *options = [[YapDatabaseRelationshipOptions alloc] init];
    NSSet *allowedCollections = [NSSet setWithArray:@[BRCEventObject. yapCollection]];
    options.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:allowedCollections];
    YapDatabaseRelationship *relationship = [[YapDatabaseRelationship alloc] initWithVersionTag:@"2" options:options];
    BOOL success = [self.database registerExtension:relationship withName:viewName];
    if (success) {
        [self postExtensionRegisteredNotification:viewName];
    }
    NSLog(@"Registered %@ %d", viewName, success);
}

- (void) registerRegularViews {
    // Register regular views
    NSArray *viewsInfo = @[@[self.artViewName, [BRCArtObject class]],
                           @[self.campsViewName, [BRCCampObject class]],
                           @[self.eventsViewName, [BRCEventObject class]]];
    [viewsInfo enumerateObjectsUsingBlock:^(NSArray *viewInfo, NSUInteger idx, BOOL *stop) {
        NSString *viewName = [viewInfo firstObject];
        Class viewClass = [viewInfo lastObject];
        NSString *collection = [viewClass yapCollection];
        YapWhitelistBlacklist *allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:collection]];
        YapDatabaseView *view = [BRCDatabaseManager databaseViewForClass:viewClass allowedCollections:allowedCollections];
        BOOL success = [self.database registerExtension:view withName:viewName];
        if (success) {
            [self postExtensionRegisteredNotification:viewName];
        }
        NSLog(@"Registered %@ %d", viewName, success);
    }];
    YapWhitelistBlacklist *allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObjects:[BRCArtObject yapCollection], [BRCCampObject yapCollection], [BRCEventObject yapCollection], nil]];
    YapDatabaseView *dataObjectsView = [BRCDatabaseManager databaseViewForClass:[BRCDataObject class] allowedCollections:allowedCollections];
    BOOL success = [self.database registerExtension:dataObjectsView withName:self.dataObjectsViewName];
    if (success) {
        [self postExtensionRegisteredNotification:self.dataObjectsViewName];
    }
    NSLog(@"Registered %@ %d", self.dataObjectsViewName, success);
    
    success = [self registerUpdateInfoView];
    if (success) {
        [self postExtensionRegisteredNotification:BRCDatabaseManager.updateInfoViewName];
    }
    NSLog(@"Registered %@ %d", BRCDatabaseManager.updateInfoViewName, success);
    
    [self registerSearchObjectsView];
}

- (void) registerSearchObjectsView {
    YapDatabaseViewGrouping *searchObjectsGrouping = [YapDatabaseViewGrouping withObjectBlock:^NSString * _Nullable(YapDatabaseReadTransaction * _Nonnull transaction, NSString * _Nonnull collection, NSString * _Nonnull key, id  _Nonnull object) {
        if ([object isKindOfClass:[BRCEventObject class]]) {
            BRCEventObject *eventObject = (BRCEventObject*)object;
            NSDateFormatter *dateFormatter = [NSDateFormatter brc_eventGroupHourlyDateFormatter];
            NSString *groupName = [dateFormatter stringFromDate:eventObject.startDate];
            return groupName;
        } else if ([object isKindOfClass:[BRCDataObject class]]) {
            BRCDataObject *dataObject = object;
            NSString *groupName = nil;
            
            NSString *firstLetter = [[dataObject.title substringToIndex:1] uppercaseString];
            NSCharacterSet *alphabet = [NSCharacterSet letterCharacterSet];
            unichar firstChar = [firstLetter characterAtIndex:0];
            // ABCD... is fine
            if ([alphabet characterIsMember:firstChar]) {
                groupName = firstLetter;
            } else { // 123!@#$ goes to the top in "#"
                groupName = @"#";
            }
            return groupName;
        }
        return collection;
    }];
    YapWhitelistBlacklist *allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObjects:[BRCArtObject yapCollection], [BRCCampObject yapCollection], [BRCEventObject yapCollection], nil]];
    YapDatabaseViewOptions *searchObjectsViewOptions = [[YapDatabaseViewOptions alloc] init];
    searchObjectsViewOptions.allowedCollections = allowedCollections;
    YapDatabaseView *searchObjectsView = [[YapDatabaseAutoView alloc] initWithGrouping:searchObjectsGrouping sorting:[[self class] sorting] versionTag:@"2" options:searchObjectsViewOptions];
    BOOL success = [self.database registerExtension:searchObjectsView withName:self.searchObjectsViewName];
    if (success) {
        [self postExtensionRegisteredNotification:self.searchObjectsViewName];
    }
    NSLog(@"Registered %@ %d", self.searchObjectsViewName, success);
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
        BOOL success = [self.database registerExtension:fullTextSearch withName:ftsName];
        if (success) {
            [self postExtensionRegisteredNotification:ftsName];
        }
        NSLog(@"%@ ready %d", ftsName, success);
    }];
}

- (void) registerFilteredViews {
    // Register filtered views
    BOOL success = NO;
    
    NSSet *allowedCollections = [NSSet setWithArray:@[BRCEventObject.yapCollection]];
    YapWhitelistBlacklist *whitelist = [[YapWhitelistBlacklist alloc] initWithWhitelist:allowedCollections];
    YapDatabaseFilteredView *filteredByDayView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventSelectedDayOnly parentViewName:self.eventsViewName allowedCollections:whitelist];
    success = [self.database registerExtension:filteredByDayView withName:self.eventsFilteredByDayViewName];
    NSLog(@"%@ %d", self.eventsFilteredByDayViewName, success);
    if (success) {
        [self postExtensionRegisteredNotification: self.eventsFilteredByDayViewName];
    }
    
    YapDatabaseFilteredView *filteredByExpiryAndTypeView = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeEventExpirationAndType parentViewName:self.eventsFilteredByDayViewName allowedCollections:whitelist];
    success = [self.database registerExtension:filteredByExpiryAndTypeView withName:self.eventsFilteredByDayExpirationAndTypeViewName];
    NSLog(@"%@ %d", self.eventsFilteredByDayExpirationAndTypeViewName, success);
    if (success) {
        [self postExtensionRegisteredNotification:self.eventsFilteredByDayExpirationAndTypeViewName];
    }
    
    YapDatabaseFilteredView *favoritesFiltering = [BRCDatabaseManager filteredViewForType:BRCDatabaseFilteredViewTypeFavoritesOnly parentViewName:self.dataObjectsViewName allowedCollections:nil];
    success = [self.database registerExtension:favoritesFiltering withName:self.everythingFilteredByFavorite];
    if (success) {
        [self postExtensionRegisteredNotification:self.everythingFilteredByFavorite];
    }
    NSLog(@"%@ %d", self.everythingFilteredByFavorite, success);
    
    // Audio Tour
    YapDatabaseViewFiltering *audioTourFiltering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(YapDatabaseReadTransaction * _Nonnull transaction, NSString * _Nonnull group, NSString * _Nonnull collection, NSString * _Nonnull key, id  _Nonnull object) {
        if ([object isKindOfClass:[BRCArtObject class]]) {
            BRCArtObject *art = (BRCArtObject*)object;
            if (art.audioURL) {
                return YES;
            }
        }
        return NO;
    }];
    // The previous diff for this line looked correct, so I'm re-stating it to be sure.
    // If the error was on this specific line, it implies the string might have been malformed here.
    YapDatabaseFilteredView *audioTour = [[YapDatabaseFilteredView alloc] initWithParentViewName:self.artViewName filtering:audioTourFiltering versionTag:@"2"];
    success = [self.database registerExtension:audioTour withName:self.audioTourViewName];
    if (success) {
        [self postExtensionRegisteredNotification:self.audioTourViewName];
    }
    NSLog(@"%@ %d", self.audioTourViewName, success);
    
    // Art and camps with images
    YapDatabaseViewFiltering *objectsWithImagesFiltering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(YapDatabaseReadTransaction * _Nonnull transaction, NSString * _Nonnull group, NSString * _Nonnull collection, NSString * _Nonnull key, id  _Nonnull object) {
        if ([object isKindOfClass:[BRCArtObject class]]) {
            BRCArtObject *art = (BRCArtObject*)object;
            if (art.remoteThumbnailURL) {
                return YES;
            }
        } else if ([object isKindOfClass:[BRCCampObject class]]) {
            BRCCampObject *camp = (BRCCampObject*)object;
            if (camp.remoteThumbnailURL) {
                return YES;
            }
        }
        return NO;
    }];
    YapDatabaseFilteredView *objectsWithImages = [[YapDatabaseFilteredView alloc] initWithParentViewName:self.dataObjectsViewName filtering:objectsWithImagesFiltering versionTag:@"3"];
    success = [self.database registerExtension:objectsWithImages withName:self.artImagesViewName];
    if (success) {
        [self postExtensionRegisteredNotification:self.artImagesViewName];
    }
    NSLog(@"%@ %d", self.artImagesViewName, success);
}

- (void) registerSearchViews {
    // search view name, parent view name, fts name
    NSArray *searchInfoArrays = @[@[self.searchArtView, self.artViewName, self.ftsArtName],
                                  @[self.searchCampsView, self.campsViewName, self.ftsCampsName],
                                  @[self.searchEventsView, self.eventsFilteredByDayExpirationAndTypeViewName, self.ftsEventsName],
                                  @[self.searchEverythingView, self.searchObjectsViewName, self.ftsDataObjectName],
                                  @[self.searchFavoritesView, self.everythingFilteredByFavorite, self.ftsDataObjectName]];
    
    [searchInfoArrays enumerateObjectsUsingBlock:^(NSArray *searchInfoArray, NSUInteger idx, BOOL *stop) {
        NSString *searchViewName = searchInfoArray[0];
        NSString *parentViewName = searchInfoArray[1];
        NSString *ftsName = searchInfoArray[2];
        
        YapDatabaseSearchResultsViewOptions *searchViewOptions = [[YapDatabaseSearchResultsViewOptions alloc] init];
        
        YapDatabaseSearchResultsView *searchResultsView = [[YapDatabaseSearchResultsView alloc] initWithFullTextSearchName:ftsName
                                                                                                            parentViewName:parentViewName
                                                                                                                versionTag:@"7"
                                                                                                                   options:searchViewOptions];
        
        BOOL success = [self.database registerExtension:searchResultsView withName:searchViewName];
        if (success) {
            [self postExtensionRegisteredNotification:searchViewName];
        }
        NSLog(@"%@ %d", searchViewName, success);
    }];
}

- (void) registerRTreeIndex {
    YapDatabaseRTreeIndexSetup *setup = [[YapDatabaseRTreeIndexSetup alloc] init];
    [setup setColumns:@[RTreeMinLat,
                        RTreeMaxLat,
                        RTreeMinLon,
                        RTreeMaxLon]];
    YapDatabaseRTreeIndexHandler *handler = [YapDatabaseRTreeIndexHandler withObjectBlock:^(NSMutableDictionary *dict, NSString *collection, NSString *key, id object) {
        if ([object isKindOfClass:[BRCDataObject class]]) {
            BRCDataObject *dataObject = object;
            CLLocation *location = dataObject.location;
            if (!location) {
                location = dataObject.burnerMapLocation;
            }
            if (!location) {
                return;
            }
            dict[RTreeMinLat] = @(location.coordinate.latitude);
            dict[RTreeMaxLat] = @(location.coordinate.latitude);
            dict[RTreeMinLon] = @(location.coordinate.longitude);
            dict[RTreeMaxLon] = @(location.coordinate.longitude);
        }
    }];
    YapDatabaseRTreeIndexOptions *options = [[YapDatabaseRTreeIndexOptions alloc] init];
    NSSet *allowedCollections = [NSSet setWithArray:@[
                                                      [BRCArtObject yapCollection],
                                                      [BRCCampObject yapCollection],
                                                      [BRCEventObject yapCollection]]
                                 ];
    options.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:allowedCollections];
    YapDatabaseRTreeIndex *rTree = [[YapDatabaseRTreeIndex alloc] initWithSetup:setup handler:handler versionTag:@"2" options:options];
    BOOL success = [self.database registerExtension:rTree withName:self.rTreeIndex];
    if (success) {
        [self postExtensionRegisteredNotification:self.rTreeIndex];
    }
    NSLog(@"%@ with version tag %d", self.rTreeIndex, success);
}


+ (YapDatabaseViewGrouping*)groupingForClass:(Class)viewClass {
    YapDatabaseViewGrouping *grouping = nil;
    
    if (viewClass == [BRCEventObject class]) {
        grouping = [YapDatabaseViewGrouping withObjectBlock:^NSString *(YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object){
            if ([object isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *eventObject = (BRCEventObject*)object;
                NSDateFormatter *dateFormatter = [NSDateFormatter brc_eventGroupHourlyDateFormatter];
                NSString *groupName = [dateFormatter stringFromDate:eventObject.startDate];
                return groupName;
            }
            return nil;
        }];
    } else if (viewClass == [BRCDataObject class]) {
        grouping = [YapDatabaseViewGrouping withKeyBlock:^NSString * _Nullable(YapDatabaseReadTransaction * _Nonnull transaction, NSString * _Nonnull collection, NSString * _Nonnull key) {
            return collection;
        }];
    } else {
        // group art & camp by letter index
        grouping = [YapDatabaseViewGrouping withObjectBlock:^NSString *(YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object){
            if ([collection isEqualToString:[viewClass yapCollection]])
            {
                if ([object isKindOfClass:[BRCDataObject class]]) {
                    BRCDataObject *dataObject = object;
                    NSString *groupName = nil;
                    
                    NSString *firstLetter = [[dataObject.title substringToIndex:1] uppercaseString];
                    NSCharacterSet *alphabet = [NSCharacterSet letterCharacterSet];
                    unichar firstChar = [firstLetter characterAtIndex:0];
                    // ABCD... is fine
                    if ([alphabet characterIsMember:firstChar]) {
                        groupName = firstLetter;
                    } else { // 123!@#$ goes to the top in "#"
                        groupName = @"#";
                    }
                    return groupName;
                }
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

+ (YapDatabaseViewSorting*)sorting {
    return [YapDatabaseViewSorting withObjectBlock:^(YapDatabaseReadTransaction *transaction, NSString *group, NSString *collection1, NSString *key1, id obj1,
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
        } else if ([obj1 isKindOfClass:BRCDataObject.class] && [obj2 isKindOfClass:BRCDataObject.class]) {
            BRCDataObject *data1 = (BRCDataObject *)obj1;
            BRCDataObject *data2 = (BRCDataObject *)obj2;
            return [data1.title compare:data2.title];
        }
        return NSOrderedSame;
    }];
}

/**
 *  Does not register the view, but checks if it is registered and returns
 *  the registered view if it exists. (Caller should register the view)
 */
+ (YapDatabaseView*) databaseViewForClass:(Class)viewClass allowedCollections:(YapWhitelistBlacklist*)allowedCollections
{
    YapDatabaseViewGrouping *grouping = [[self class] groupingForClass:viewClass];
    YapDatabaseViewSorting *sorting = [[self class] sorting];
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    NSString *versionTag = @"7";
    if (options.allowedCollections) {
        options.allowedCollections = allowedCollections;
    }
    YapDatabaseAutoView *databaseView =
    [[YapDatabaseAutoView alloc] initWithGrouping:grouping
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
             NSStringFromSelector(@selector(artName)),
             NSStringFromSelector(@selector(artistLocation))
    ];
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
    YapDatabaseFullTextSearchHandler *searchHandler = [YapDatabaseFullTextSearchHandler withObjectBlock:^(YapDatabaseReadTransaction *transaction, NSMutableDictionary *dict, NSString *collection, NSString *key, id object) {
        
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
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withMetadataBlock:^BOOL(YapDatabaseReadTransaction * _Nonnull transaction, NSString * _Nonnull group, NSString * _Nonnull collection, NSString * _Nonnull key, id  _Nullable metadata) {
        if ([metadata isKindOfClass:BRCObjectMetadata.class]) {
            BRCObjectMetadata *ourMetadata = (BRCObjectMetadata*)metadata;
            return ourMetadata.isFavorite;
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
    } else {
        filtering = [[self class] allItemsFiltering];
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
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withKeyBlock:^BOOL(YapDatabaseReadTransaction *transaction, NSString *group, NSString *collection, NSString *key) {
        return YES;
    }];
    return filtering;
}

+ (YapDatabaseViewFiltering*) eventsFilteredByToday {
    NSDate *validDate = [[NSDate present] brc_dateWithinStartDate:[BRCEventObject festivalStartDate] endDate:[BRCEventObject festivalEndDate]];
    return [self eventsFilteredByDay:validDate];
}

/** TODO: Remove me. This is deprecated and not needed. */
+ (YapDatabaseViewFiltering*) eventsFilteredByDay:(NSDate*)day
{
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withKeyBlock:^BOOL (YapDatabaseReadTransaction *transaction, NSString *group, NSString *collection, NSString *key)
    {
        return YES;
    }];
    return filtering;
}

+ (YapDatabaseViewFiltering*) eventsFilteredByExpirationAndType {
    BOOL showExpiredEvents = [[NSUserDefaults standardUserDefaults] showExpiredEvents];
    NSSet *filteredSet = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] selectedEventTypes]];
    return [[self class] eventsFilteredByExpiration:showExpiredEvents eventTypes:filteredSet];
}

+ (YapDatabaseViewFiltering*) eventsFilteredByExpiration:(BOOL)showExpired eventTypes:(NSSet*)eventTypes {
    BOOL showAllDayEvents = [NSUserDefaults standardUserDefaults].showAllDayEvents;
    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(YapDatabaseReadTransaction *transaction, NSString *group, NSString *collection, NSString *key, id object) {
        if ([object isKindOfClass:[BRCEventObject class]]) {
            NSDate *now = [NSDate present];
            BRCEventObject *eventObject = (BRCEventObject*)object;
            if (eventObject.isAllDay && !showAllDayEvents) {
                return NO;
            }
            if (eventObject.eventType == BRCEventTypeAdult &&
                !BRCLocations.hasEnteredBurningManRegion) {
                return NO;
            }
            BOOL eventHasEnded = [eventObject hasEnded:now] || [eventObject isEndingSoon:now];
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
        YapDatabaseAutoViewTransaction *viewTransaction = [transaction ext:self.eventsViewName];
        if (!viewTransaction) {
            return;
        }
        Class viewClass = [BRCEventObject class];
        YapDatabaseViewGrouping *grouping = [BRCDatabaseManager groupingForClass:viewClass];
        YapDatabaseViewSorting *sorting = [BRCDatabaseManager sorting];
        [viewTransaction setGrouping:grouping sorting:sorting versionTag:[[NSUUID UUID] UUIDString]];
    } completionBlock:completionBlock];
}

/**
 * Query for objects in bounded region.
 * @see MKCoordinateRegionMakeWithDistance
 */
- (void) queryObjectsInRegion:(MKCoordinateRegion)region
              completionQueue:(dispatch_queue_t)completionQueue
                 resultsBlock:(void (^)(NSArray<BRCDataObject*> *results))resultsBlock {
    CLLocationCoordinate2D northWestCorner = kCLLocationCoordinate2DInvalid; // max
    CLLocationCoordinate2D southEastCorner = kCLLocationCoordinate2DInvalid; // min
    CLLocationCoordinate2D center = region.center;
    northWestCorner.latitude  = center.latitude  - (region.span.latitudeDelta  / 2.0);
    northWestCorner.longitude = center.longitude + (region.span.longitudeDelta / 2.0);
    southEastCorner.latitude  = center.latitude  + (region.span.latitudeDelta  / 2.0);
    southEastCorner.longitude = center.longitude - (region.span.longitudeDelta / 2.0);
    
    // gotta switch these around for some reason
    CLLocationCoordinate2D minCoord = CLLocationCoordinate2DMake(northWestCorner.latitude, southEastCorner.longitude);
    CLLocationCoordinate2D maxCoord = CLLocationCoordinate2DMake(southEastCorner.latitude, northWestCorner.longitude);
    [self queryObjectsInMinCoord:minCoord maxCoord:maxCoord completionQueue:completionQueue resultsBlock:resultsBlock];
}


- (void) queryObjectsInMinCoord:(CLLocationCoordinate2D)minCoord
                       maxCoord:(CLLocationCoordinate2D)maxCoord
                completionQueue:(dispatch_queue_t)completionQueue
                   resultsBlock:(void (^)(NSArray<BRCDataObject*> *results))resultsBlock {
    if (!resultsBlock) {
        return;
    }
    if (!completionQueue) {
        completionQueue = dispatch_get_main_queue();
    }
    NSMutableArray<BRCDataObject*> *results = [NSMutableArray array];
    NSString *queryString = [NSString stringWithFormat:@"WHERE %@ >= ? AND %@ <= ? AND %@ >= ? AND %@ <= ?",
                             RTreeMinLon,
                             RTreeMaxLon,
                             RTreeMinLat,
                             RTreeMaxLat];
    
    CLLocationDegrees minLat = minCoord.latitude;
    CLLocationDegrees minLon = minCoord.longitude;
    CLLocationDegrees maxLat = maxCoord.latitude;
    CLLocationDegrees maxLon = maxCoord.longitude;
    
    // Not sure why the order is different here
    NSArray *paramters = @[@(minLon),
                           @(maxLon),
                           @(minLat),
                           @(maxLat)];
    YapDatabaseQuery *query = [YapDatabaseQuery queryWithString:queryString parameters:paramters];
    
    [self.backgroundReadConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        YapDatabaseRTreeIndexTransaction *rTree = [transaction ext:self.rTreeIndex];
        [rTree enumerateKeysAndObjectsMatchingQuery:query usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
            if ([object isKindOfClass:[BRCDataObject class]]) {
                BRCDataObject *data = object;
                if ([BRCEmbargo canShowLocationForObject:data]) {
                    [results addObject:object];
                }
            }
        }];
    } completionQueue:completionQueue completionBlock:^{
        resultsBlock(results);
    }];
}

@end
