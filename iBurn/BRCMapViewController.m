//
//  BRCMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCMapViewController.h"
#import "BRCDatabaseManager.h"
#import "BRCArtObject.h"
#import "BRCAnnotation.h"
#import "BRCEventObject.h"
#import "BRCDetailViewController.h"
#import "BRCCampObject.h"
#import "RMMarker.h"
#import "PureLayout.h"
#import "BRCEventObjectTableViewCell.h"
#import "CLLocationManager+iBurn.h"
#import "RMMapView+iBurn.h"
#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCLocations.h"

static NSString * const kBRCManRegionIdentifier = @"kBRCManRegionIdentifier";

@interface BRCMapViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) YapDatabaseConnection *artConnection;
@property (nonatomic, strong) YapDatabaseConnection *eventsConnection;
@property (nonatomic, strong) YapDatabaseConnection *readConnection;
@property (nonatomic) BOOL currentlyAddingArtAnnotations;
@property (nonatomic) BOOL currentlyAddingEventAnnotations;
@property (nonatomic, strong) NSArray *artAnnotations;
@property (nonatomic, strong) NSArray *eventAnnotations;
@property (nonatomic, strong) NSDate *lastEventAnnotationUpdate;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic) BOOL didUpdateConstraints;
@property (nonatomic, strong) NSString *ftsExtensionName;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) RMAnnotation *searchAnnotation;
@property (nonatomic, strong) CLCircularRegion *burningManRegion;
@end

@implementation BRCMapViewController

- (instancetype) init {
    if (self = [super init]) {
        self.title = @"Map";
        self.artConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        self.artConnection.objectPolicy = YapDatabasePolicyShare;
        self.eventsConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        self.eventsConnection.objectPolicy = YapDatabasePolicyShare;
        self.readConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        [self reloadArtAnnotationsIfNeeded];
        [self reloadEventAnnotationsIfNeeded];
        [self setupSearchBar];
        [self registerFullTextSearchExtension];
        [self setupSearchController];
        self.locationManager = [CLLocationManager brc_locationManager];
        self.locationManager.delegate = self;
        [self.locationManager startUpdatingLocation];
        [self setupRegionBasedUnlock];
    }
    return self;
}

- (void) setupSearchController {
    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar contentsController:self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchController.searchResultsDelegate = self;
    
    NSArray *classesToRegister = @[[BRCEventObject class], [BRCDataObject class]];
    [classesToRegister enumerateObjectsUsingBlock:^(Class viewClass, NSUInteger idx, BOOL *stop) {
        Class cellClass = [self cellClassForDataObjectClass:viewClass];
        UINib *nib = [UINib nibWithNibName:NSStringFromClass(cellClass) bundle:nil];
        [self.searchController.searchResultsTableView registerNib:nib forCellReuseIdentifier:[cellClass cellIdentifier]];
    }];
}

- (void) setupRegionBasedUnlock {
    NSParameterAssert(self.locationManager != nil);
    CLLocationCoordinate2D manCoordinate2014 = [BRCLocations blackRockCityCenter];
    CLLocationDistance radius = 5 * 8046.72; // Within 5 miles of the man
    self.burningManRegion = [[CLCircularRegion alloc] initWithCenter:manCoordinate2014 radius:radius identifier:kBRCManRegionIdentifier];
}

- (void) setupSearchBar {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:.85];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];
}

- (void) registerFullTextSearchExtension {
    Class dataClass = [BRCDataObject class];
    NSArray *indexedProperties = @[NSStringFromSelector(@selector(title))];
    NSString *ftsName = [BRCDatabaseManager fullTextSearchNameForClass:dataClass withIndexedProperties:indexedProperties];
    YapDatabaseFullTextSearch *fullTextSearch = [BRCDatabaseManager fullTextSearchForClass:dataClass withIndexedProperties:indexedProperties];
    self.ftsExtensionName = ftsName;
    [[BRCDatabaseManager sharedInstance].database asyncRegisterExtension:fullTextSearch withName:ftsName completionBlock:^(BOOL ready) {
        NSLog(@"%@ ready %d", ftsName, ready);
    }];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    if (self.didUpdateConstraints) {
        return;
    }
    [self.searchBar autoPinToTopLayoutGuideOfViewController:self withInset:0];
    [self.searchBar autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.searchBar autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    [self.searchBar autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
    self.didUpdateConstraints = YES;
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.mapView removeAllAnnotations];
    self.artAnnotations = nil;
    self.eventAnnotations = nil;
    self.lastEventAnnotationUpdate = nil;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.isVisible = YES;
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.isVisible = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadArtAnnotationsIfNeeded];
    [self reloadEventAnnotationsIfNeeded];
}

- (void) reloadArtAnnotationsIfNeeded {
#warning disabled art annotations
    return;
    if (self.artAnnotations.count || self.currentlyAddingArtAnnotations) {
        return;
    }
    self.currentlyAddingArtAnnotations = YES;
    [self.artConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *artAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:[BRCArtObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCArtObject *artObject = [transaction objectForKey:key inCollection:[BRCArtObject collection]];
            BRCAnnotation *artAnnotation = [BRCAnnotation annotationWithMapView:self.mapView dataObject:artObject];
            // if artObject doesn't have a valid location, annotationWithMapView will
            // return nil for the artAnnotation
            if (artAnnotation) {
                [artAnnotationsToAdd addObject:artAnnotation];
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentlyAddingArtAnnotations = NO;
            self.artAnnotations = artAnnotationsToAdd;
            [self.mapView addAnnotations:artAnnotationsToAdd];
        });
    }];
}

- (void)reloadEventAnnotationsIfNeeded
{
    NSTimeInterval minTimeIntervalForRefresh = 5 * 60; // 5 minutes
    
    if ([[NSDate date] timeIntervalSinceDate:self.lastEventAnnotationUpdate] < minTimeIntervalForRefresh || self.currentlyAddingEventAnnotations) {
        return;
    }
    self.currentlyAddingEventAnnotations = YES;
    NSArray *oldAnnotations = [self.eventAnnotations copy];
    
    [self.eventsConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *eventAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:[BRCEventObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCEventObject *eventObject = [transaction objectForKey:key inCollection:[BRCEventObject collection]];
            
            //Check if event is currently happening or that the start time is in the next time window
            if([eventObject isHappeningRightNow] || [eventObject isStartingSoon]) {
                BRCAnnotation *eventAnnotation = [BRCAnnotation annotationWithMapView:self.mapView dataObject:eventObject];
                
                // if eventObject doesn't have a valid location, annotationWithMapView will
                // return nil for the eventAnnotation
                if (eventAnnotation) {
                    [eventAnnotationsToAdd addObject:eventAnnotation];
                }
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentlyAddingEventAnnotations = NO;
            self.eventAnnotations = eventAnnotationsToAdd;
            [self.mapView removeAnnotations:oldAnnotations];
            [self.mapView addAnnotations:self.eventAnnotations];
        });
    }];
}

#pragma mark RMMapViewDelegate methods

- (void)tapOnCalloutAccessoryControl:(UIControl *)control forAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    if ([annotation isKindOfClass:[BRCAnnotation class]]) {
        BRCAnnotation *brcAnnotation = (BRCAnnotation*)annotation;
        BRCDataObject *dataObject = brcAnnotation.dataObject;
        BRCDetailViewController *detailViewController = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
        [self.navigationController pushViewController:detailViewController animated:YES];
    }
}

- (RMMapLayer*) mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
    RMMapLayer *mapLayer = [super mapView:mapView layerForAnnotation:annotation];
    if (mapLayer) {
        mapLayer.canShowCallout = YES;
        mapLayer.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        return mapLayer;
    }
    return nil;
}

#pragma - mark UISearchBarDelegate Methods

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [self.searchDisplayController setActive:YES animated:YES];
}

#pragma - mark  UISearchDisplayDelegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    if ([searchString length]) {
        searchString = [NSString stringWithFormat:@"*%@*",searchString];
        [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            NSMutableArray *tempSearchResults = [NSMutableArray array];
            [[transaction ext:self.ftsExtensionName] enumerateKeysAndObjectsMatching:searchString usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
                if (object) {
                    [tempSearchResults addObject:object];
                }
            }];
            self.searchResults = [tempSearchResults copy];
        }];
    }
    else {
        self.searchResults = nil;
    }
    return YES;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    return [self.searchResults count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    if (self.searchAnnotation) {
        [self.mapView removeAnnotation:self.searchAnnotation];
        self.searchAnnotation = nil;
    }
    
    if (![BRCEmbargo canShowLocationForObject:dataObject]) {
        [self.searchDisplayController setActive:NO animated:YES];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Embargoed" message:@"Sorry, location data for camps and events is only available after the gates open." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
    else {
        if (dataObject.location) {
            self.searchAnnotation = [BRCAnnotation annotationWithMapView:self.mapView dataObject:dataObject];
            [self.mapView addAnnotation:self.searchAnnotation];
            [self.mapView brc_zoomToIncludeCoordinate:self.locationManager.location.coordinate andCoordinate:dataObject.location.coordinate inVisibleRect:self.mapView.bounds animated:YES];
            [self.mapView selectAnnotation:self.searchAnnotation animated:YES];
        } else { // no location to show
            BRCDetailViewController *detailViewController = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
            [self.navigationController pushViewController:detailViewController animated:YES];
        }
        [self.searchDisplayController setActive:NO animated:YES];

    }
    
    
}

- (BRCDataObject *)dataObjectForIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView
{
    BRCDataObject *dataObject = nil;
    if ([self.searchResults count] > indexPath.row) {
        dataObject = self.searchResults[indexPath.row];
    }
    return dataObject;
}

- (Class) cellClassForDataObjectClass:(Class)dataObjectClass {
    if (dataObjectClass == [BRCEventObject class]) {
        return [BRCEventObjectTableViewCell class];
    } else {
        return [BRCDataObjectTableViewCell class];
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    Class cellClass = [self cellClassForDataObjectClass:[dataObject class]];
    return [cellClass cellHeight];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    Class cellClass = [self cellClassForDataObjectClass:[dataObject class]];
    BRCDataObjectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[cellClass cellIdentifier] forIndexPath:indexPath];
    cell.dataObject = dataObject;
    [cell updateDistanceLabelFromLocation:self.locationManager.location toLocation:dataObject.location];
    return cell;
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *lastLocation = [locations lastObject];
    if ([self.burningManRegion containsCoordinate:lastLocation.coordinate]) {
        [self enteredBurningManRegion];
    }
}

- (void) enteredBurningManRegion {
    if ([BRCEmbargo allowEmbargoedData]) {
        return;
    }
    NSDate *now = [NSDate date];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    if (timeLeftInterval >= 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Data Unlocked" message:@"Looks like you're at Burning Man! The embargoed data is now unlocked." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [[NSUserDefaults standardUserDefaults] setEnteredEmbargoPasscode:YES];
    }
}

- (void) centerMapAtManCoordinates {
    [self.mapView brc_zoomToFullTileSourceAnimated:YES];
    [self.mapView brc_moveToBlackRockCityCenterAnimated:YES];
}

@end
