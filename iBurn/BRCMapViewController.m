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
#import "BRCAcknowledgementsViewController.h"
#import "BButton.h"
#import "BRCMapPoint.h"
#import "BRCAnnotationEditView.h"

static NSString * const kBRCManRegionIdentifier = @"kBRCManRegionIdentifier";

@interface BRCMapViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, CLLocationManagerDelegate, BRCAnnotationEditViewDelegate>
@property (nonatomic, strong) YapDatabaseConnection *artConnection;
@property (nonatomic, strong) YapDatabaseConnection *eventsConnection;
@property (nonatomic, strong) YapDatabaseConnection *readConnection;
@property (nonatomic) BOOL currentlyAddingArtAnnotations;
@property (nonatomic) BOOL currentlyAddingEventAnnotations;
@property (nonatomic, strong) NSArray *artAnnotations;
@property (nonatomic, strong) NSArray *eventAnnotations;
@property (nonatomic, strong) NSArray *userMapPinAnnotations;
@property (nonatomic, strong) NSDate *lastEventAnnotationUpdate;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic) BOOL didUpdateConstraints;
@property (nonatomic, strong) NSString *ftsExtensionName;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) RMAnnotation *searchAnnotation;
@property (nonatomic, strong) CLCircularRegion *burningManRegion;
@property (nonatomic, strong) BButton *addMapPointButton;
@property (nonatomic, strong) RMAnnotation *editingMapPointAnnotation;
@property (nonatomic, strong) BRCAnnotationEditView *annotationEditView;
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
        [self setupInfoButton];
    }
    return self;
}

- (void) setupNewMapPointButton {
    self.addMapPointButton = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAMapMarker fontSize:20];
    [self.addMapPointButton addTarget:self action:@selector(newMapPointButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.addMapPointButton.alpha = 0.8;
    [self.view addSubview:self.addMapPointButton];
}

- (void) newMapPointButtonPressed:(id)sender {
    // show BRCANnotationEditView
    // set currentlyEditingAnnotation
    // drop a pin
    
    if (self.editingMapPointAnnotation) {
        [self.mapView removeAnnotation:self.editingMapPointAnnotation];
        self.editingMapPointAnnotation = nil;
    }
    CLLocationCoordinate2D pinDropCoordinate = self.mapView.centerCoordinate;
    self.editingMapPointAnnotation = [[RMAnnotation alloc] initWithMapView:self.mapView coordinate:pinDropCoordinate andTitle:nil];
    BRCMapPoint *mapPoint = [[BRCMapPoint alloc] initWithTitle:nil coordinate:pinDropCoordinate];
    self.editingMapPointAnnotation.userInfo = mapPoint;
    [self.mapView addAnnotation:self.editingMapPointAnnotation];
    [self showEditViewForAnnotation:self.editingMapPointAnnotation];
}

- (void) showEditViewForAnnotation:(RMAnnotation*)annotation {
    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
        BRCMapPoint *mapPoint = annotation.userInfo;
        self.annotationEditView = [[BRCAnnotationEditView alloc] initWithText:mapPoint.title delegate:self];
        self.annotationEditView.alpha = 0.0f;
        [self.view addSubview:self.annotationEditView];
        [self.annotationEditView autoPinToTopLayoutGuideOfViewController:self withInset:0];
        [self.annotationEditView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
        [self.annotationEditView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
        [self.annotationEditView autoSetDimension:ALDimensionHeight toSize:90];
        [self.annotationEditView autoAlignAxisToSuperviewAxis:ALAxisVertical];
        [UIView animateWithDuration:0.2 animations:^{
            self.annotationEditView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [self.annotationEditView.textField becomeFirstResponder];
        }];
    }
}

- (void) hideEditView:(BRCAnnotationEditView*)annotationEditView animated:(BOOL)animated completionBlock:(dispatch_block_t)completionBlock {
    [UIView animateWithDuration:0.5 animations:^{
        annotationEditView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [annotationEditView removeFromSuperview];
        if (completionBlock) {
            completionBlock();
        }
    }];
}

- (void) infoButtonPressed:(id)sender {
    CGFloat labelMargin = 10;
    TTTAttributedLabel *headerLabel = [[TTTAttributedLabel alloc] init];
    NSString *chrisballingerString = @"@chrisballinger";
    NSURL *chrisballingerURL = [NSURL URLWithString:@"https://github.com/chrisballinger"];
    NSString *davidchilesString = @"@davidchiles";
    NSURL *davidChilesURL = [NSURL URLWithString:@"https://github.com/davidchiles"];
    NSString *headerText = [NSString stringWithFormat:@"Crafted with ❤ by %@ & %@.", chrisballingerString, davidchilesString];
    NSRange chrisRange = [headerText rangeOfString:chrisballingerString];
    NSRange davidRange = [headerText rangeOfString:davidchilesString];

    UIFont *font = [UIFont systemFontOfSize:12];
    CGFloat labelWidth = CGRectGetWidth(self.view.frame) - 2 * labelMargin;
    CGFloat labelHeight;
    
    NSStringDrawingOptions options = (NSLineBreakByWordWrapping | NSStringDrawingUsesLineFragmentOrigin);
    CGRect labelBounds = [headerText boundingRectWithSize:CGSizeMake(labelWidth, CGFLOAT_MAX)
                                                       options:options
                                                    attributes:@{NSFontAttributeName: font}
                                                       context:nil];
    labelHeight = CGRectGetHeight(labelBounds) + 5; // emoji hearts are big
    
    CGRect labelFrame = CGRectMake(labelMargin, labelMargin*2, labelWidth, labelHeight);
    
    NSDictionary *linkAttributes = @{(NSString*)kCTForegroundColorAttributeName:(id)[[UIColor blackColor] CGColor],
                                     (NSString *)kCTUnderlineStyleAttributeName: @NO};
    headerLabel.linkAttributes = linkAttributes;
    
    headerLabel.frame = labelFrame;
    headerLabel.font             = font;
    headerLabel.textColor        = [UIColor grayColor];
    headerLabel.backgroundColor  = [UIColor clearColor];
    headerLabel.numberOfLines    = 0;
    headerLabel.textAlignment    = NSTextAlignmentCenter;
    headerLabel.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
    headerLabel.text = headerText;
    
    [headerLabel addLinkToURL:chrisballingerURL withRange:chrisRange];
    [headerLabel addLinkToURL:davidChilesURL withRange:davidRange];
    
    BRCAcknowledgementsViewController *viewController = [[BRCAcknowledgementsViewController alloc] initWithHeaderLabel:headerLabel];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void) setupInfoButton {
    UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[infoButton addTarget:self action:@selector(infoButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *modalButton = [[UIBarButtonItem alloc] initWithCustomView:infoButton];
    self.navigationItem.leftBarButtonItem = modalButton;
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
    [self.addMapPointButton autoPinToBottomLayoutGuideOfViewController:self withInset:10];
    [self.addMapPointButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:10];
    [self.addMapPointButton autoSetDimensionsToSize:CGSizeMake(40, 40)];
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

- (void) viewDidLoad {
    [super viewDidLoad];
    [self setupNewMapPointButton];
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
    [self reloadAllUserPoints];
    [self.view bringSubviewToFront:self.addMapPointButton];
}

- (RMAnnotation*) newAnnotationForMapPoint:(BRCMapPoint*)mapPoint {
    RMAnnotation *annotation = [[RMAnnotation alloc] initWithMapView:self.mapView coordinate:mapPoint.coordinate andTitle:mapPoint.title];
    annotation.userInfo = mapPoint;
    return annotation;
}

- (void) reloadAllUserPoints {
    // do it later
    NSMutableArray *annotationsToAdd = [NSMutableArray array];
    [self.readConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:[BRCMapPoint collection] usingBlock:^(NSString *key, id object, BOOL *stop) {
            if ([object isKindOfClass:[BRCMapPoint class]]) {
                BRCMapPoint *mapPoint = (BRCMapPoint*)object;
                RMAnnotation *annotation = [self newAnnotationForMapPoint:mapPoint];
                [annotationsToAdd addObject:annotation];
            }
        }];
    } completionBlock:^{
        [self.mapView removeAnnotations:self.userMapPinAnnotations];
        self.userMapPinAnnotations = annotationsToAdd;
        [self.mapView addAnnotations:self.userMapPinAnnotations];
    }];
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

- (BOOL)mapView:(RMMapView *)mapView shouldDragAnnotation:(RMAnnotation *)annotation {
    return [self.editingMapPointAnnotation isEqual:annotation];
}

- (void)mapView:(RMMapView *)mapView annotation:(RMAnnotation *)annotation didChangeDragState:(RMMapLayerDragState)newState fromOldState:(RMMapLayerDragState)oldState {
    if ([self.editingMapPointAnnotation isEqual:annotation]) {
        if (oldState == RMMapLayerDragStateDragging) {
            BRCMapPoint *mapPoint = annotation.userInfo;
            mapPoint.coordinate = annotation.coordinate;
        }
    }
}

- (void)tapOnCalloutAccessoryControl:(UIControl *)control forAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    if ([annotation isKindOfClass:[BRCAnnotation class]]) {
        BRCAnnotation *brcAnnotation = (BRCAnnotation*)annotation;
        BRCDataObject *dataObject = brcAnnotation.dataObject;
        BRCDetailViewController *detailViewController = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
        [self.navigationController pushViewController:detailViewController animated:YES];
    }
    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
        if (self.editingMapPointAnnotation) {
            [self.mapView removeAnnotation:self.editingMapPointAnnotation];
            self.editingMapPointAnnotation = nil;
        }
        self.editingMapPointAnnotation = annotation;
        [self showEditViewForAnnotation:annotation];
    }
}

- (RMMapLayer*) mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
    RMMapLayer *mapLayer = [super mapView:mapView layerForAnnotation:annotation];
    if (mapLayer) {
        mapLayer.canShowCallout = YES;
        mapLayer.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        return mapLayer;
    }
    RMMarker *userMapPointMarker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"BRCPurplePin"]]; // user map points
    if ([annotation isEqual:self.editingMapPointAnnotation]) {
        userMapPointMarker.canShowCallout = NO;
    } else {
        userMapPointMarker.canShowCallout = YES;
        userMapPointMarker.rightCalloutAccessoryView = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 35, 35) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAPencil fontSize:20];
    }
    return userMapPointMarker;
}

#pragma mark BRCAnnotationEditViewDelegate methods

- (void) editViewDidSelectDelete:(BRCAnnotationEditView *)view {
    BRCMapPoint *mapPoint = self.editingMapPointAnnotation.userInfo;
    NSParameterAssert(mapPoint != nil);
    [self.mapView removeAnnotation:self.editingMapPointAnnotation];
    self.editingMapPointAnnotation = nil;
    // delete the actual point here
    [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeObjectForKey:mapPoint.uuid inCollection:[BRCMapPoint collection]];
    } completionBlock:^{
        [self reloadAllUserPoints];
    }];
    [self hideEditView:view animated:YES completionBlock:^{
        self.annotationEditView = nil;
    }];
}

- (void) editViewDidSelectDone:(BRCAnnotationEditView *)view text:(NSString *)text {
    BRCMapPoint *mapPoint = self.editingMapPointAnnotation.userInfo;
    NSParameterAssert(mapPoint != nil);
    mapPoint.title = text;
    [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction setObject:mapPoint forKey:mapPoint.uuid inCollection:[BRCMapPoint collection]];
    } completionBlock:^{
        [self.mapView removeAnnotation:self.editingMapPointAnnotation];
        self.editingMapPointAnnotation = nil;
        [self reloadAllUserPoints];
    }];
    [self hideEditView:view animated:YES completionBlock:^{
        self.annotationEditView = nil;
    }];
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
        NSMutableArray *tempSearchResults = [NSMutableArray array];
        searchString = [NSString stringWithFormat:@"*%@*",searchString];
        [self.readConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [[transaction ext:self.ftsExtensionName] enumerateKeysAndObjectsMatching:searchString usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
                if (object) {
                    [tempSearchResults addObject:object];
                }
            }];
        } completionBlock:^{
            self.searchResults = tempSearchResults;
            [controller.searchResultsTableView reloadData];
        }];
    } else {
        self.searchResults = nil;
    }
    return NO;
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
