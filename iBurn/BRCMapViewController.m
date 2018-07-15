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
#import "BRCEventObject.h"
#import "BRCDetailViewController.h"
#import "BRCCampObject.h"
#import "PureLayout.h"
#import "BRCEventObjectTableViewCell.h"
#import "CLLocationManager+iBurn.h"
#import "MGLMapView+iBurn.h"
#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCAcknowledgementsViewController.h"
#import "BButton.h"
#import "BRCMapPoint.h"
#import "BRCAnnotationEditView.h"
#import "BRCEmbargoPasscodeViewController.h"
#import "BRCAppDelegate.h"
#import "NSDateFormatter+iBurn.h"
#import "UIColor+iBurn.h"
#import <pop/POP.h>
#import "BRCGeocoder.h"
#import "BRCUserMapPoint.h"
#import <KVOController/NSObject+FBKVOController.h>
@import YapDatabase;
#import "iBurn-Swift.h"
#import "BRCArtObject.h"
#import "BRCArtObjectTableViewCell.h"
@import AVFoundation;

static const float kBRCMapViewArtAndEventsMinZoomLevel = 16.0f;
static const float kBRCMapViewCampsMinZoomLevel = 17.0f;


@interface BRCMapViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, CLLocationManagerDelegate, BRCAnnotationEditViewDelegate>
@property (nonatomic, strong) YapDatabaseConnection *artConnection;
@property (nonatomic, strong) YapDatabaseConnection *eventsConnection;
@property (nonatomic, strong) YapDatabaseConnection *campsConnection;
@property (nonatomic, strong) YapDatabaseConnection *favoritesConnection;
@property (nonatomic, strong) YapDatabaseConnection *readConnection;
@property (nonatomic) BOOL currentlyAddingEventAnnotations;
@property (nonatomic) BOOL currentlyAddingArtAnnotations;
@property (nonatomic) BOOL currentlyAddingFavoritesAnnotations;
@property (nonatomic) BOOL currentlyAddingCampAnnotations;
@property (nonatomic, strong) NSArray *favoritesAnnotations;
@property (nonatomic, strong) NSArray *eventAnnotations;
@property (nonatomic, strong) NSArray *artAnnotations;
@property (nonatomic, strong) NSArray *campAnnotations;
@property (nonatomic, strong) NSArray *userMapPinAnnotations;
@property (nonatomic, strong) NSDate *lastEventAnnotationUpdate;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic) BOOL didUpdateConstraints;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *searchResults;
//@property (nonatomic, strong) RMAnnotation *searchAnnotation;
@property (nonatomic, strong) BButton *addMapPointButton;
//@property (nonatomic, strong) RMAnnotation *editingMapPointAnnotation;
@property (nonatomic, strong) BRCAnnotationEditView *annotationEditView;
@property (nonatomic, strong) UIActivityIndicatorView *searchActivityIndicatorView;
@property (nonatomic, strong) BRCGeocoder *geocoder;

//@property (nonatomic, strong) RMPolylineAnnotation *guidanceAnnotation;
/** same button goes in all annotations */
@property (nonatomic, strong) BButton *guidanceButton;
@property (nonatomic, strong) BRCDistanceView *distanceView;

@property (nonatomic, strong) BButton *pottyFinderButton;
@property (nonatomic, strong) BButton *bikeFinderButton;
@property (nonatomic, strong) BButton *homeFinderButton;
@property (nonatomic, strong) BButton *medicalFinderButton;

@end

@implementation BRCMapViewController

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Setup

- (instancetype) initWithFtsName:(NSString *)ftsName {
    if (self = [super init]) {
        _ftsName = ftsName;
        self.title = @"Map";
        self.artConnection = [BRCDatabaseManager.shared.database newConnection];
        self.eventsConnection = [BRCDatabaseManager.shared.database newConnection];
        self.eventsConnection.objectPolicy = YapDatabasePolicyShare;
        self.readConnection = [BRCDatabaseManager.shared.database newConnection];
        self.favoritesConnection = [BRCDatabaseManager.shared.database newConnection];
        self.campsConnection = [BRCDatabaseManager.shared.database newConnection];
        [self reloadFavoritesIfNeeded];
        [self setupSearchBar];
        [self setupSearchController];
        [self setupSearchIndicator];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseExtensionRegistered:) name:BRCDatabaseExtensionRegisteredNotification object:BRCDatabaseManager.shared];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerChangedNotification:) name:BRCAudioPlayer.BRCAudioPlayerChangeNotification object:BRCAudioPlayer.sharedInstance];
    }
    return self;
}

- (void) databaseExtensionRegistered:(NSNotification*)notification {
    NSString *extensionName = notification.userInfo[@"extensionName"];
    if ([extensionName isEqualToString:BRCDatabaseManager.shared.everythingFilteredByFavorite]) {
        [self reloadFavoritesIfNeeded];
        NSLog(@"databaseExtensionRegistered: %@", extensionName);
    }
}


- (void) setupSearchController {
    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar contentsController:self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchController.searchResultsDelegate = self;
    
    NSArray *classesToRegister = @[[BRCEventObject class], [BRCDataObject class], [BRCArtObject class]];
    [classesToRegister enumerateObjectsUsingBlock:^(Class viewClass, NSUInteger idx, BOOL *stop) {
        Class cellClass = [BRCDataObjectTableViewCell cellClassForDataObjectClass:viewClass];
        UINib *nib = [UINib nibWithNibName:NSStringFromClass(cellClass) bundle:nil];
        [self.searchController.searchResultsTableView registerNib:nib forCellReuseIdentifier:[cellClass cellIdentifier]];
    }];
}

- (void) setupSearchBar {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:.85];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];
}

- (void) setupSearchIndicator {
    self.searchActivityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.searchActivityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchActivityIndicatorView];
}

- (void) setupAnnotationEditView {
    self.annotationEditView = [[BRCAnnotationEditView alloc] initWithDelegate:self];
    self.annotationEditView.alpha = 0.0f;
    self.annotationEditView.userInteractionEnabled = NO;
    [self.view addSubview:self.annotationEditView];
}

#pragma mark Map Side Buttons

- (void) setupSideButtons {
    [self setupNewMapPointButton];
    [self setupPottyFinderButton];
    [self setupBikeFinderButton];
    [self setupHomeFinderButton];
    [self setupMedicalFinderButton];
}

- (void) setupMedicalFinderButton {
    self.medicalFinderButton = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAMedkit fontSize:20];
    [self.medicalFinderButton addTarget:self action:@selector(findNearestMedical:) forControlEvents:UIControlEventTouchUpInside];
    self.medicalFinderButton.alpha = 0.8;
    [self.view addSubview:self.medicalFinderButton];
}

- (void) setupPottyFinderButton {
    self.pottyFinderButton = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAFemale fontSize:20];
    [self.pottyFinderButton addTarget:self action:@selector(findNearestPotty:) forControlEvents:UIControlEventTouchUpInside];
    self.pottyFinderButton.alpha = 0.8;
    [self.view addSubview:self.pottyFinderButton];
}

- (void) setupBikeFinderButton {
    self.bikeFinderButton = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FABicycle fontSize:20];
    [self.bikeFinderButton addTarget:self action:@selector(findNearestBike:) forControlEvents:UIControlEventTouchUpInside];
    self.bikeFinderButton.alpha = 0.8;
    [self.view addSubview:self.bikeFinderButton];
}

- (void) setupHomeFinderButton {
    self.homeFinderButton = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAHome fontSize:20];
    [self.homeFinderButton addTarget:self action:@selector(findNearestHome:) forControlEvents:UIControlEventTouchUpInside];
    self.homeFinderButton.alpha = 0.8;
    [self.view addSubview:self.homeFinderButton];
}

- (void) setupNewMapPointButton {
    self.addMapPointButton = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAMapMarker fontSize:20];
    [self.addMapPointButton addTarget:self action:@selector(newMapPointButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.addMapPointButton.alpha = 0.8;
    [self.view addSubview:self.addMapPointButton];
}

#pragma mark View Lifecycle

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    if (self.didUpdateConstraints) {
        return;
    }
    CGFloat margin = 10;
    [self.searchBar autoPinToTopLayoutGuideOfViewController:self withInset:0];
    [self.searchBar autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.searchBar autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    [self.searchBar autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
    
    
    // side buttons
    [self.addMapPointButton autoPinToBottomLayoutGuideOfViewController:self withInset:margin];
    [self.addMapPointButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:margin];
    [self.addMapPointButton autoSetDimensionsToSize:CGSizeMake(40, 40)];
    
    [self.pottyFinderButton autoAlignAxis:ALAxisVertical toSameAxisOfView:self.addMapPointButton];
    [self.pottyFinderButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.addMapPointButton withOffset:-margin];
    [self.pottyFinderButton autoSetDimensionsToSize:CGSizeMake(40, 40)];
    
    [self.bikeFinderButton autoAlignAxis:ALAxisVertical toSameAxisOfView:self.addMapPointButton];
    [self.bikeFinderButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.pottyFinderButton withOffset:-margin];
    [self.bikeFinderButton autoSetDimensionsToSize:CGSizeMake(40, 40)];
    
    [self.homeFinderButton autoAlignAxis:ALAxisVertical toSameAxisOfView:self.addMapPointButton];
    [self.homeFinderButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.bikeFinderButton withOffset:-margin];
    [self.homeFinderButton autoSetDimensionsToSize:CGSizeMake(40, 40)];
    
    [self.medicalFinderButton autoAlignAxis:ALAxisVertical toSameAxisOfView:self.addMapPointButton];
    [self.medicalFinderButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.homeFinderButton withOffset:-margin];
    [self.medicalFinderButton autoSetDimensionsToSize:CGSizeMake(40, 40)];
    
    // editing annotations
    [self.annotationEditView autoPinToTopLayoutGuideOfViewController:self withInset:0];
    [self.annotationEditView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
    [self.annotationEditView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    [self.annotationEditView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    
    [self.searchActivityIndicatorView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
    [self.searchActivityIndicatorView autoCenterInSuperview];
    self.didUpdateConstraints = YES;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.isVisible = YES;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    [self setupSideButtons];
    [self setupAnnotationEditView];
    self.geocoder = [BRCGeocoder shared];
    self.guidanceButton = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 35, 35) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FALocationArrow fontSize:20];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.isVisible = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadAllAnnotations];
    [self.view bringSubviewToFront:self.addMapPointButton];
    // kludge to fix keyboard appearing at wrong time
//    if (!self.editingMapPointAnnotation) {
//        [self.annotationEditView.textField resignFirstResponder];
//    }
}

- (void) reloadAllAnnotations {
    [self reloadEventAnnotationsIfNeeded];
    [self reloadArtAnnotationsIfNeeded];
    [self reloadCampAnnotationsIfNeeded];
    [self reloadFavoritesIfNeeded];
    //[self reloadAllUserPoints];
}

#pragma mark Annotation Loading

- (void) reloadFavoritesIfNeeded {
    
    if (self.currentlyAddingFavoritesAnnotations) {
        return;
    }
    self.currentlyAddingFavoritesAnnotations = YES;
    NSMutableArray *favoritesAnnotationsToAdd = [NSMutableArray array];
    [self.favoritesConnection asyncReadWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        YapDatabaseViewTransaction *favesTransaction = [transaction ext:BRCDatabaseManager.shared.everythingFilteredByFavorite];
        [favesTransaction enumerateGroupsUsingBlock:^(NSString *group, BOOL *stop) {
            [favesTransaction enumerateKeysAndObjectsInGroup:group usingBlock:^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop) {
                if ([object isKindOfClass:[BRCDataObject class]]) {
//                    BRCDataObject *dataObject = object;
//                    RMAnnotation *annotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:dataObject];
//                    if ([dataObject isKindOfClass:[BRCEventObject class]]) {
//                        NSDateFormatter *dateFormatter = [NSDateFormatter brc_eventGroupDateFormatter];
//                        NSString *groupName = [dateFormatter stringFromDate:[NSDate date]];
//                        if (![groupName isEqualToString:group]) {
//                            return;
//                        }
//                    }
//                    if (annotation) {
//                        [favoritesAnnotationsToAdd addObject:annotation];
//                    }
                }
            }];
        }];
    } completionBlock:^{
        self.currentlyAddingFavoritesAnnotations = NO;
        if (self.favoritesAnnotations.count > 0) {
            [self.mapView removeAnnotations:self.favoritesAnnotations];
        }
        self.favoritesAnnotations = favoritesAnnotationsToAdd;
        [self.mapView addAnnotations:favoritesAnnotationsToAdd];
    }];
}

- (void) reloadCampAnnotationsIfNeeded {
    if (![BRCEmbargo allowEmbargoedData]) {
        return;
    }
    if (self.mapView.zoomLevel < kBRCMapViewCampsMinZoomLevel) {
        if (self.campAnnotations.count > 0) {
            [self.mapView removeAnnotations:self.campAnnotations];
            self.campAnnotations = nil;
        }
        return;
    }
    if (self.campAnnotations.count || self.currentlyAddingCampAnnotations) {
        return;
    }
    self.currentlyAddingCampAnnotations = YES;
    [self.campsConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *campAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:BRCCampObject.yapCollection usingBlock:^(NSString *key, BOOL *stop) {
            BRCCampObject *campObject = [transaction objectForKey:key inCollection:[BRCCampObject yapCollection]];
//            RMAnnotation *campAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:campObject];
//            // if campObject doesn't have a valid location, annotationWithMapView will
//            // return nil for the campAnnotation
//            if (campAnnotation) {
//                [campAnnotationsToAdd addObject:campAnnotation];
//            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentlyAddingCampAnnotations = NO;
            if (self.campAnnotations.count > 0) {
                [self.mapView removeAnnotations:self.campAnnotations];
            }
            self.campAnnotations = campAnnotationsToAdd;
            [self.mapView addAnnotations:campAnnotationsToAdd];
        });
    }];
}


- (void) reloadArtAnnotationsIfNeeded {
    if (self.mapView.zoomLevel < kBRCMapViewArtAndEventsMinZoomLevel) {
        if (self.artAnnotations.count > 0) {
            [self.mapView removeAnnotations:self.artAnnotations];
            self.artAnnotations = nil;
        }
        return;
    }
    if (self.artAnnotations.count || self.currentlyAddingArtAnnotations) {
        return;
    }
    self.currentlyAddingArtAnnotations = YES;
    [self.artConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *artAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:[BRCArtObject yapCollection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCArtObject *artObject = [transaction objectForKey:key inCollection:[BRCArtObject yapCollection]];
//            RMAnnotation *artAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:artObject];
//            // if artObject doesn't have a valid location, annotationWithMapView will
//            // return nil for the artAnnotation
//            if (artAnnotation) {
//                [artAnnotationsToAdd addObject:artAnnotation];
//            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentlyAddingArtAnnotations = NO;
            if (self.artAnnotations.count > 0) {
                [self.mapView removeAnnotations:self.artAnnotations];
            }
            self.artAnnotations = artAnnotationsToAdd;
            [self.mapView addAnnotations:artAnnotationsToAdd];
        });
    }];
}

//- (void) reloadAllUserPoints {
//    if (self.editingMapPointAnnotation) {
//        [self hideEditView:self.annotationEditView animated:YES completionBlock:nil];
//        [self.mapView removeAnnotation:self.editingMapPointAnnotation];
//    }
//    self.editingMapPointAnnotation = nil;
//    NSMutableArray *annotationsToAdd = [NSMutableArray array];
//    [self.readConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
//        [transaction enumerateKeysAndObjectsInCollection:[BRCUserMapPoint collection] usingBlock:^(NSString *key, id object, BOOL *stop) {
//            if ([object isKindOfClass:[BRCUserMapPoint class]]) {
//                BRCUserMapPoint *mapPoint = (BRCUserMapPoint*)object;
//                // only show points added by user
//                if (mapPoint.type == BRCMapPointTypeUserBike ||
//                    mapPoint.type == BRCMapPointTypeUserCamp ||
//                    mapPoint.type == BRCMapPointTypeUserHeart ||
//                    mapPoint.type == BRCMapPointTypeUserHome ||
//                    mapPoint.type == BRCMapPointTypeUserStar) {
//                    RMAnnotation *annotation = [RMAnnotation brc_annotationWithMapView:self.mapView mapPoint:mapPoint];
//                    if (annotation) {
//                        [annotationsToAdd addObject:annotation];
//                    }
//                }
//            }
//        }];
//    } completionBlock:^{
//        if (self.userMapPinAnnotations.count > 0) {
//            [self.mapView removeAnnotations:self.userMapPinAnnotations];
//        }
//        self.userMapPinAnnotations = annotationsToAdd;
//        [self.mapView addAnnotations:self.userMapPinAnnotations];
//    }];
//}

- (void)reloadEventAnnotationsIfNeeded
{
    if (self.mapView.zoomLevel < kBRCMapViewArtAndEventsMinZoomLevel) {
        if (self.eventAnnotations.count > 0) {
            [self.mapView removeAnnotations:self.eventAnnotations];
            self.eventAnnotations = nil;
        }
        return;
    }
    NSTimeInterval minTimeIntervalForRefresh = 5 * 60; // 5 minutes
    
    if ([[NSDate date] timeIntervalSinceDate:self.lastEventAnnotationUpdate] < minTimeIntervalForRefresh || self.currentlyAddingEventAnnotations) {
        return;
    }
    self.currentlyAddingEventAnnotations = YES;
    NSArray *oldAnnotations = [self.eventAnnotations copy];
    
    NSDate *now = [NSDate date];
    
    [self.eventsConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *eventAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:[BRCEventObject yapCollection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCEventObject *eventObject = [transaction objectForKey:key inCollection:[BRCEventObject yapCollection]];
            
            //Check if event is currently happening or that the start time is in the next time window
//            if([eventObject isHappeningRightNow:now] || [eventObject isStartingSoon:now]) {
//                RMAnnotation *eventAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:eventObject];
//                
//                // if eventObject doesn't have a valid location, annotationWithMapView will
//                // return nil for the eventAnnotation
//                if (eventAnnotation) {
//                    [eventAnnotationsToAdd addObject:eventAnnotation];
//                }
//            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentlyAddingEventAnnotations = NO;
            self.eventAnnotations = eventAnnotationsToAdd;
            [self.mapView addAnnotations:self.eventAnnotations];
            if (oldAnnotations.count > 0) {
                [self.mapView removeAnnotations:oldAnnotations];
            }
        });
    }];
}

#pragma mark Dropping / Editing Pins

- (void) newMapPointButtonPressed:(id)sender {
    [self hideGuide];
    // show BRCANnotationEditView
    // set currentlyEditingAnnotation
    // drop / add a pin
    
//    if (self.editingMapPointAnnotation) {
//        [self.mapView removeAnnotation:self.editingMapPointAnnotation];
//        self.editingMapPointAnnotation = nil;
//    }
    
    // drop pin at user location if possible
    CLLocationCoordinate2D pinDropCoordinate = kCLLocationCoordinate2DInvalid;
    if (self.mapView.userLocation.location) {
        pinDropCoordinate = self.mapView.userLocation.location.coordinate;
    } else {
        pinDropCoordinate = self.mapView.centerCoordinate;
    }
    // don't drop user-location pins if youre not at BM
    if (![[BRCLocations burningManRegion] containsCoordinate:pinDropCoordinate]) {
        pinDropCoordinate = self.mapView.centerCoordinate;
    }
    BRCUserMapPoint *mapPoint = [[BRCUserMapPoint alloc] initWithTitle:nil coordinate:pinDropCoordinate type:BRCMapPointTypeUserStar];
//    self.editingMapPointAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView mapPoint:mapPoint];
//    self.editingMapPointAnnotation.userInfo = mapPoint;
//    
//    self.editingMapPointAnnotation.layer.hidden = YES;
//    [self.mapView addAnnotation:self.editingMapPointAnnotation];
//    
//    [self.editingMapPointAnnotation.layer pop_removeAllAnimations];
//    // http://stackoverflow.com/a/23921147/805882
//    POPSpringAnimation *anim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
//    anim.fromValue = @(0);
//    anim.toValue = @(self.mapView.center.y);
//    anim.springSpeed = 8;
//    anim.springBounciness = 4;
//    [self.editingMapPointAnnotation.layer pop_addAnimation:anim forKey:kPOPLayerPositionY];
//    self.editingMapPointAnnotation.layer.hidden = NO;
//    
//    [self showEditView:self.annotationEditView forAnnotation:self.editingMapPointAnnotation];
}

//- (void) showEditView:(BRCAnnotationEditView*)annotationEditView forAnnotation:(RMAnnotation*)annotation {
//    if ([annotation.userInfo isKindOfClass:[BRCUserMapPoint class]]) {
//        BRCUserMapPoint *mapPoint = annotation.userInfo;
//        annotationEditView.mapPoint = mapPoint;
//        annotationEditView.alpha = 0.0f;
//        annotationEditView.userInteractionEnabled = NO;
//        [self.view bringSubviewToFront:annotationEditView];
//        [self.mapView setCenterCoordinate:mapPoint.coordinate animated:YES];
//        [UIView animateWithDuration:0.2 animations:^{
//            annotationEditView.alpha = 1.0f;
//        } completion:^(BOOL finished) {
//            annotationEditView.userInteractionEnabled = YES;
//        }];
//    }
//}

//- (void) hideEditView:(BRCAnnotationEditView*)annotationEditView animated:(BOOL)animated completionBlock:(dispatch_block_t)completionBlock {
//    annotationEditView.mapPoint = nil;
//    annotationEditView.userInteractionEnabled = NO;
//    [UIView animateWithDuration:0.5 animations:^{
//        annotationEditView.alpha = 0.0;
//    } completion:^(BOOL finished) {
//        if (completionBlock) {
//            completionBlock();
//        }
//    }];
//}


#pragma mark User Guide

- (void) findNearestPotty:(id)sender {
    [self findNearestMapPointOfType:BRCMapPointTypeToilet];
}

- (void) findNearestMedical:(id)sender {
    [self findNearestMapPointOfType:BRCMapPointTypeMedical];
}

- (void) findNearestHome:(id)sender {
    [self findNearestMapPointOfType:BRCMapPointTypeUserHome];
}

- (void) findNearestBike:(id)sender {
    [self findNearestMapPointOfType:BRCMapPointTypeUserBike];
}

- (void) findNearestMapPointOfType:(BRCMapPointType)type {
    CLLocation *currentLocation = self.mapView.userLocation.location;
    if (!currentLocation) {
        return;
    }
    currentLocation = [currentLocation copy];
    Class pointClass = [BRCMapPoint classForType:type];
    NSString *yapCollection = [pointClass yapCollection];
    __block BRCMapPoint *closestPoint = nil;
    [self.readConnection asyncReadWithBlock:^(YapDatabaseReadTransaction * transaction) {
        NSMutableArray *distances = [NSMutableArray array];
        [transaction enumerateKeysAndObjectsInCollection:yapCollection usingBlock:^(NSString * key, id object, BOOL * stop) {
            if ([object isKindOfClass:[BRCMapPoint class]]) {
                BRCMapPoint *mapPoint = object;
                if (mapPoint.type == type) {
                    CLLocationDistance distance = [currentLocation distanceFromLocation:mapPoint.location];
                    NSDictionary *info = @{@"point": mapPoint,
                                           @"distance": @(distance)};
                    [distances addObject:info];
                }
            }
        }];
        if (distances.count > 0) {
            [distances sortUsingComparator:^NSComparisonResult(NSDictionary *info1, NSDictionary *info2) {
                NSNumber *distance1 = info1[@"distance"];
                NSNumber *distance2 = info2[@"distance"];
                return [distance1 compare:distance2];
            }];
            NSDictionary *firstInfo = [distances firstObject];
            closestPoint = firstInfo[@"point"];
        }
    } completionBlock:^{
        if (closestPoint) {
            [self showGuideFromLocation:self.mapView.userLocation.location toLocation:closestPoint.location];
        }
    }];
}

- (void) showGuideFromLocation:(CLLocation*)fromLocation toLocation:(CLLocation*)toLocation {
    NSParameterAssert(fromLocation != nil);
    NSParameterAssert(toLocation != nil);
    if (!fromLocation || !toLocation) {
        return;
    }
    [self updateGuideFromLocation:fromLocation toLocation:toLocation];
    //self.mapView.userTrackingMode = RMUserTrackingModeFollowWithHeading;
    [self.mapView setTargetCoordinate:toLocation.coordinate animated:YES];
    //[self.mapView brc_zoomToIncludeCoordinate:fromLocation.coordinate andCoordinate:toLocation.coordinate inVisibleRect:self.view.bounds animated:YES];
}

- (void) updateGuideFromLocation:(CLLocation*)fromLocation toLocation:(CLLocation*)toLocation {
//    if (self.guidanceAnnotation) {
//        [self.mapView removeAnnotation:self.guidanceAnnotation];
//        self.guidanceAnnotation = nil;
//    }
//    self.guidanceAnnotation = [[RMPolylineAnnotation alloc] initWithMapView:self.mapView points:@[fromLocation, toLocation]];
//    self.guidanceAnnotation.lineColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.7];
//    self.guidanceAnnotation.lineWidth = 8.0;
//    [self.mapView addAnnotation:self.guidanceAnnotation];
    
    if (!self.distanceView) {
        self.distanceView = [[BRCDistanceView alloc] initWithFrame:CGRectZero destination:toLocation];
        self.distanceView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.distanceView];
        [self.view bringSubviewToFront:self.distanceView];
        [self.distanceView autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.addMapPointButton];
        [self.distanceView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    }
    self.distanceView.destination = toLocation; // just in case
    [self.distanceView updateDistanceFromLocation:fromLocation];
}

/** hide the guidance view */
- (void) hideGuide {
//    if (self.guidanceAnnotation) {
//        [self.mapView removeAnnotation:self.guidanceAnnotation];
//        self.guidanceAnnotation = nil;
//        self.mapView.userTrackingMode = RMUserTrackingModeNone;
//    }
    if (self.distanceView) {
        [self.distanceView removeFromSuperview];
        self.distanceView = nil;
    }
}



#pragma mark RMMapViewDelegate methods

//- (void)afterMapZoom:(RMMapView *)map byUser:(BOOL)wasUserAction {
//    if (map.zoom >= kBRCMapViewArtAndEventsMinZoomLevel) {
//        [self reloadArtAnnotationsIfNeeded];
//        [self reloadEventAnnotationsIfNeeded];
//    } else {
//        if (self.eventAnnotations.count > 0) {
//            [self.mapView removeAnnotations:self.eventAnnotations];
//            self.eventAnnotations = nil;
//        }
//        if (self.artAnnotations.count > 0) {
//            [self.mapView removeAnnotations:self.artAnnotations];
//            self.artAnnotations = nil;
//        }
//    }
//    if (map.zoom >= kBRCMapViewCampsMinZoomLevel) {
//        [self reloadCampAnnotationsIfNeeded];
//    } else {
//        if (self.campAnnotations.count > 0) {
//            [self.mapView removeAnnotations:self.campAnnotations];
//            self.campAnnotations = nil;
//        }
//    }
//}
//
//- (void) singleTapOnMap:(RMMapView *)map at:(CGPoint)point {
//    if (self.annotationEditView.mapPoint) {
//        [self hideEditView:self.annotationEditView animated:YES completionBlock:^{
//            [self reloadAllUserPoints];
//        }];
//    }
//    [self hideGuide];
//}
//
//- (BOOL)mapView:(RMMapView *)mapView shouldDragAnnotation:(RMAnnotation *)annotation {
//    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
//        BRCMapPoint *draggedMapPoint = annotation.userInfo;
//        BRCMapPoint *editingMapPoint = self.editingMapPointAnnotation.userInfo;
//        BOOL shouldDragAnnotation = [draggedMapPoint.uuid isEqual:editingMapPoint.uuid];
//        return shouldDragAnnotation;
//    }
//    return NO;
//}
//
//- (void)tapOnCalloutAccessoryControl:(UIControl *)control forAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
//{
//    if (control == self.guidanceButton) {
//        CLLocation *destination = nil;
//        if ([annotation.userInfo isKindOfClass:[BRCDataObject class]]) {
//            BRCDataObject *dataObject = annotation.userInfo;
//            destination = dataObject.location;
//        } else if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
//            BRCMapPoint *mapPoint = annotation.userInfo;
//            CLLocationCoordinate2D coordinate = mapPoint.coordinate;
//            destination = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
//        }
//        [self showGuideFromLocation:self.mapView.userLocation.location toLocation:destination];
//    } else {
//        if ([annotation.userInfo isKindOfClass:[BRCDataObject class]]) {
//            BRCDataObject *dataObject = annotation.userInfo;
//            BRCDetailViewController *detailViewController = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
//            detailViewController.hidesBottomBarWhenPushed = YES;
//            [self.navigationController pushViewController:detailViewController animated:YES];
//        }
//        if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
//            self.editingMapPointAnnotation = annotation;
//            [self showEditView:self.annotationEditView forAnnotation:annotation];
//        }
//    }
//}
//
//- (RMMapLayer*) mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
//    if (annotation.isUserLocationAnnotation) { // show default style
//        return nil;
//    }
//    if ([annotation.userInfo isKindOfClass:[BRCDataObject class]]) {
//        RMMapLayer *mapLayer = [super mapView:mapView layerForAnnotation:annotation];
//        if (mapLayer) {
//            mapLayer.canShowCallout = YES;
//            mapLayer.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
//            mapLayer.leftCalloutAccessoryView = self.guidanceButton;
//            return mapLayer;
//        }
//    }
//    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
//        RMMarker *userMapPointMarker = nil;
//        if ([annotation.userInfo isKindOfClass:[BRCUserMapPoint class]]) {
//            userMapPointMarker = [[RMMarker alloc] initWithUIImage:annotation.annotationIcon];
//        } else {
//            userMapPointMarker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"BRCRedPin"]]; // user map point
//        }
//        if ([annotation isEqual:self.editingMapPointAnnotation]) {
//            userMapPointMarker.canShowCallout = NO;
//        } else {
//            userMapPointMarker.canShowCallout = YES;
//            userMapPointMarker.rightCalloutAccessoryView = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 35, 35) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAPencil fontSize:20];
//        }
//        userMapPointMarker.leftCalloutAccessoryView = self.guidanceButton;
//        return userMapPointMarker;
//    }
//    return nil;
//}
//
//- (void)mapView:(RMMapView *)mapView didUpdateUserLocation:(RMUserLocation *)userLocation {
//    CLLocation *newLocation = userLocation.location;
//    if (newLocation) {
//        [self.geocoder asyncReverseLookup:newLocation.coordinate completionQueue:dispatch_get_main_queue() completion:^(NSString *locationString) {
//            if (locationString.length > 0) {
//                NSAttributedString *attrLocString = [BRCGeocoder locationStringWithCrosshairs:locationString];
//                UILabel *label = [[UILabel alloc] init];
//                label.attributedText = attrLocString;
//                [label sizeToFit];
//                self.navigationItem.titleView = label;
//            } else {
//                self.navigationItem.title = @"Map";
//            }
//        }];
//    }
//    
//    if (self.distanceView) {
//        [self updateGuideFromLocation:newLocation toLocation:self.distanceView.destination];
//    }
//}

#pragma mark BRCAnnotationEditViewDelegate methods

- (void) editViewDidSelectDelete:(BRCAnnotationEditView *)view mapPointToDelete:(BRCMapPoint *)mapPointToDelete {
    NSParameterAssert(mapPointToDelete != nil);
    // sometimes the point is removed from the map while youre editing it...
//    NSParameterAssert(self.editingMapPointAnnotation != nil);
//    if (mapPointToDelete && self.editingMapPointAnnotation) {
//        NSString *yapCollection = [[mapPointToDelete class] collection];
//        [self.mapView removeAnnotation:self.editingMapPointAnnotation];
//        self.editingMapPointAnnotation = nil;
//        [BRCDatabaseManager.shared.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//            [transaction removeObjectForKey:mapPointToDelete.uuid inCollection:yapCollection];
//        } completionBlock:^{
//            [self reloadAllUserPoints];
//        }];
//    }
//    [self hideEditView:view animated:YES completionBlock:nil];
}

- (void) editViewDidSelectSave:(BRCAnnotationEditView *)view editedMapPoint:(BRCMapPoint *)editedMapPoint {
    NSParameterAssert(editedMapPoint != nil);
//    NSParameterAssert(self.editingMapPointAnnotation != nil);
//    if (editedMapPoint && self.editingMapPointAnnotation) {
//        NSString *yapCollection = [[editedMapPoint class] collection];
//        CLLocationCoordinate2D newCoordinate = self.editingMapPointAnnotation.coordinate;
//        editedMapPoint.coordinate = newCoordinate;
//        [BRCDatabaseManager.shared.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//            [transaction setObject:editedMapPoint forKey:editedMapPoint.uuid inCollection:yapCollection];
//        } completionBlock:^{
//            [self reloadAllUserPoints];
//        }];
//    }
//    [self hideEditView:view animated:YES completionBlock:nil];
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
        searchString = [NSString stringWithFormat:@"%@*",searchString];
        [self.searchActivityIndicatorView startAnimating];
        [self.view bringSubviewToFront:self.searchActivityIndicatorView];
        [self.readConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [[transaction ext:self.ftsName] enumerateKeysAndObjectsMatching:searchString usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
                if (object) {
                    [tempSearchResults addObject:object];
                }
            }];
        } completionBlock:^{
            self.searchResults = tempSearchResults;
            [self.searchActivityIndicatorView stopAnimating];
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
//    if (self.searchAnnotation) {
//        [self.mapView removeAnnotation:self.searchAnnotation];
//        self.searchAnnotation = nil;
//    }
    
    if (![BRCEmbargo canShowLocationForObject:dataObject]) {
        [self.searchDisplayController setActive:NO animated:YES];
        UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *unlockAction = [UIAlertAction actionWithTitle:@"Unlock" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            BRCEmbargoPasscodeViewController *unlockVC = [[BRCEmbargoPasscodeViewController alloc] init];
            __weak BRCEmbargoPasscodeViewController *weakUnlock = unlockVC;
            unlockVC.dismissAction = ^{
                [weakUnlock dismissViewControllerAnimated:YES completion:nil];
            };
            [self presentViewController:unlockVC animated:YES
                             completion:nil];
        }];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Restricted" message:@"Sorry, location data for camps and events is only available after the gates open." preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:dismissAction];
        [alertController addAction:unlockAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    else {
        if (dataObject.location) {
//            self.searchAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:dataObject];
//            [self.mapView addAnnotation:self.searchAnnotation];
//            [self.mapView brc_zoomToIncludeCoordinate:self.mapView.userLocation.coordinate andCoordinate:dataObject.location.coordinate inVisibleRect:self.mapView.bounds animated:YES];
//            [self.mapView selectAnnotation:self.searchAnnotation animated:YES];
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

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat) tableView:(nonnull UITableView *)tableView estimatedHeightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return 120.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
    Class cellClass = [BRCDataObjectTableViewCell cellClassForDataObjectClass:[dataObject class]];
    BRCDataObjectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[cellClass cellIdentifier] forIndexPath:indexPath];
    cell.dataObject = dataObject;
    [cell updateDistanceLabelFromLocation:self.mapView.userLocation.location dataObject:dataObject];
    
    [cell setFavoriteButtonAction:^(BRCDataObjectTableViewCell *sender) {
        NSIndexPath *indexPath = [tableView indexPathForCell:sender];
        BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:tableView];
        dataObject.isFavorite = sender.favoriteButton.selected;
        [BRCDatabaseManager.shared.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
            [dataObject saveWithTransaction:transaction];
            if ([dataObject isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event = (BRCEventObject*)dataObject;
                [event refreshCalendarEntry:transaction];
            }
        }];
    }];
    
    if ([cell isKindOfClass:[BRCArtObjectTableViewCell class]]) {
        BRCArtObjectTableViewCell *artCell = (BRCArtObjectTableViewCell*)cell;
        [artCell configurePlayPauseButton:(BRCArtObject*)dataObject];
    }
    
    return cell;
}

- (void) audioPlayerChangedNotification:(NSNotification*)notification {
    [self.searchController.searchResultsTableView reloadData];
}

@end
