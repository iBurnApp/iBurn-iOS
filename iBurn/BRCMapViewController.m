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
#import "RMAnnotation+iBurn.h"
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
#import "UIAlertView+Blocks.h"
#import "BRCEmbargoPasscodeViewController.h"
#import "RMUserLocation.h"
#import "BRCAppDelegate.h"
#import "NSDateFormatter+iBurn.h"
#import "UIColor+iBurn.h"
#import <pop/POP.h>


static const float kBRCMapViewArtAndEventsMinZoomLevel = 16.0f;

@interface BRCMapViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, CLLocationManagerDelegate, BRCAnnotationEditViewDelegate, MCSwipeTableViewCellDelegate>
@property (nonatomic, strong) YapDatabaseConnection *artConnection;
@property (nonatomic, strong) YapDatabaseConnection *eventsConnection;
@property (nonatomic, strong) YapDatabaseConnection *favoritesConnection;
@property (nonatomic, strong) YapDatabaseConnection *readConnection;
@property (nonatomic) BOOL currentlyAddingEventAnnotations;
@property (nonatomic) BOOL currentlyAddingArtAnnotations;
@property (nonatomic) BOOL currentlyAddingFavoritesAnnotations;
@property (nonatomic, strong) NSArray *favoritesAnnotations;
@property (nonatomic, strong) NSArray *eventAnnotations;
@property (nonatomic, strong) NSArray *artAnnotations;
@property (nonatomic, strong) NSArray *userMapPinAnnotations;
@property (nonatomic, strong) NSDate *lastEventAnnotationUpdate;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic) BOOL didUpdateConstraints;
@property (nonatomic, strong) NSString *ftsExtensionName;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) RMAnnotation *searchAnnotation;
@property (nonatomic, strong) BButton *addMapPointButton;
@property (nonatomic, strong) RMAnnotation *editingMapPointAnnotation;
@property (nonatomic, strong) BRCAnnotationEditView *annotationEditView;
@property (nonatomic, strong) UIActivityIndicatorView *searchActivityIndicatorView;
@property (nonatomic, strong) UIImageView *favoriteImageView;
@property (nonatomic, strong) UIImageView *notYetFavoriteImageView;
@end

@implementation BRCMapViewController

- (instancetype) init {
    if (self = [super init]) {
        self.title = @"Map";
        self.artConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        self.eventsConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        self.eventsConnection.objectPolicy = YapDatabasePolicyShare;
        self.readConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        self.favoritesConnection = [[BRCDatabaseManager sharedInstance].database newConnection];
        [self reloadFavoritesIfNeeded];
        [self setupSearchBar];
        [self registerFullTextSearchExtension];
        [self setupSearchController];
        [self setupInfoButton];
        [self setupSearchIndicator];
    }
    return self;
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
    
    self.editingMapPointAnnotation.layer.hidden = YES;
    [self.mapView addAnnotation:self.editingMapPointAnnotation];
    
    [self.editingMapPointAnnotation.layer pop_removeAllAnimations];
    // http://stackoverflow.com/a/23921147/805882
    POPSpringAnimation *anim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    anim.fromValue = @(0);
    anim.toValue = @(self.mapView.center.y);
    anim.springSpeed = 8;
    anim.springBounciness = 4;
    [self.editingMapPointAnnotation.layer pop_addAnimation:anim forKey:kPOPLayerPositionY];
    self.editingMapPointAnnotation.layer.hidden = NO;
    
    [self showEditView:self.annotationEditView forAnnotation:self.editingMapPointAnnotation];
}

- (void) showEditView:(BRCAnnotationEditView*)annotationEditView forAnnotation:(RMAnnotation*)annotation {
    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
        BRCMapPoint *mapPoint = annotation.userInfo;
        annotationEditView.mapPoint = mapPoint;
        annotationEditView.alpha = 0.0f;
        annotationEditView.userInteractionEnabled = NO;
        [self.view bringSubviewToFront:annotationEditView];
        [self.mapView setCenterCoordinate:mapPoint.coordinate animated:YES];
        [UIView animateWithDuration:0.2 animations:^{
            annotationEditView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            annotationEditView.userInteractionEnabled = YES;
        }];
    }
}

- (void) hideEditView:(BRCAnnotationEditView*)annotationEditView animated:(BOOL)animated completionBlock:(dispatch_block_t)completionBlock {
    annotationEditView.mapPoint = nil;
    annotationEditView.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.5 animations:^{
        annotationEditView.alpha = 0.0;
    } completion:^(BOOL finished) {
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
    [self.annotationEditView autoPinToTopLayoutGuideOfViewController:self withInset:0];
    [self.annotationEditView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
    [self.annotationEditView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    [self.annotationEditView autoSetDimension:ALDimensionHeight toSize:90];
    [self.annotationEditView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    
    [self.searchActivityIndicatorView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
    [self.searchActivityIndicatorView autoCenterInSuperview];
    self.didUpdateConstraints = YES;
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.isVisible = YES;
}

- (UIImageView *)imageViewForFavoriteWithImageName:(NSString *)imageName {
    UIImage *image = [[UIImage imageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeCenter;
    UIColor *tintColor = [[[UIApplication sharedApplication] keyWindow] tintColor];
    imageView.tintColor = tintColor;
    return imageView;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    self.favoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCDarkStar"];
    self.notYetFavoriteImageView = [self imageViewForFavoriteWithImageName:@"BRCLightStar"];
    [self setupNewMapPointButton];
    [self setupAnnotationEditView];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.isVisible = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadEventAnnotationsIfNeeded];
    [self reloadArtAnnotationsIfNeeded];
    [self reloadFavoritesIfNeeded];
    [self reloadAllUserPoints];
    [self.view bringSubviewToFront:self.addMapPointButton];
    // kludge to fix keyboard appearing at wrong time
    if (self.annotationEditView.alpha == 0.0f) {
        [self.annotationEditView.textField resignFirstResponder];
    }
}

- (void) reloadFavoritesIfNeeded {
    if (self.currentlyAddingFavoritesAnnotations) {
        return;
    }
    self.currentlyAddingFavoritesAnnotations = YES;
    NSMutableArray *favoritesAnnotationsToAdd = [NSMutableArray array];
    [self.favoritesConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSString *artFavoritesExtensionName = [BRCAppDelegate appDelegate].artViewController.favoritesFilterForDistanceViewName;
        NSString *campFavoritesExtensionName = [BRCAppDelegate appDelegate].campsViewController.favoritesFilterForDistanceViewName;
        NSString *eventFavoritesExtensionName = [BRCAppDelegate appDelegate].eventsViewController.favoritesFilterForTimeAndDistanceViewName;
        
        YapDatabaseViewTransaction *artViewTransaction = [transaction ext:artFavoritesExtensionName];
        YapDatabaseViewTransaction *campsViewTransaction = [transaction ext:campFavoritesExtensionName];
        YapDatabaseViewTransaction *eventsViewTransaction = [transaction ext:eventFavoritesExtensionName];
        
        [artViewTransaction enumerateKeysAndObjectsInGroup:[BRCArtObject collection] usingBlock:^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop) {
            if ([object isKindOfClass:[BRCArtObject class]]) {
                BRCArtObject *artObject = object;
                if (artObject.isFavorite) {
                    RMAnnotation *artAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:artObject];
                    if (artAnnotation) {
                        [favoritesAnnotationsToAdd addObject:artAnnotation];
                    }
                }
            }
        }];
        
        [campsViewTransaction enumerateKeysAndObjectsInGroup:[BRCCampObject collection] usingBlock:^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop) {
            if ([object isKindOfClass:[BRCCampObject class]]) {
                BRCCampObject *campObject = object;
                if (campObject.isFavorite) {
                    RMAnnotation *campAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:campObject];
                    if (campAnnotation) {
                        [favoritesAnnotationsToAdd addObject:campAnnotation];
                    }
                }
            }
        }];
        NSDateFormatter *dateFormatter = [NSDateFormatter brc_threadSafeGroupDateFormatter];
        NSString *groupName = [dateFormatter stringFromDate:[NSDate date]];
        
        [eventsViewTransaction enumerateKeysAndObjectsInGroup:groupName usingBlock:^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop) {
            if ([object isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *eventObject = object;
                if (eventObject.isFavorite) {
                    RMAnnotation *eventAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:eventObject];
                    if (eventAnnotation) {
                        [favoritesAnnotationsToAdd addObject:eventAnnotation];
                    }
                }
            }
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

- (void) reloadArtAnnotationsIfNeeded {
    if (self.mapView.zoom < kBRCMapViewArtAndEventsMinZoomLevel) {
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
        [transaction enumerateKeysInCollection:[BRCArtObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCArtObject *artObject = [transaction objectForKey:key inCollection:[BRCArtObject collection]];
            RMAnnotation *artAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:artObject];
            // if artObject doesn't have a valid location, annotationWithMapView will
            // return nil for the artAnnotation
            if (artAnnotation) {
                [artAnnotationsToAdd addObject:artAnnotation];
            }
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

- (void) reloadAllUserPoints {
    if (self.editingMapPointAnnotation) {
        [self.mapView removeAnnotation:self.editingMapPointAnnotation];
    }
    self.editingMapPointAnnotation = nil;
    NSMutableArray *annotationsToAdd = [NSMutableArray array];
    [self.readConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:[BRCMapPoint collection] usingBlock:^(NSString *key, id object, BOOL *stop) {
            if ([object isKindOfClass:[BRCMapPoint class]]) {
                BRCMapPoint *mapPoint = (BRCMapPoint*)object;
                RMAnnotation *annotation = [RMAnnotation brc_annotationWithMapView:self.mapView mapPoint:mapPoint];
                [annotationsToAdd addObject:annotation];
            }
        }];
    } completionBlock:^{
        if (self.userMapPinAnnotations.count > 0) {
            [self.mapView removeAnnotations:self.userMapPinAnnotations];
        }
        self.userMapPinAnnotations = annotationsToAdd;
        [self.mapView addAnnotations:self.userMapPinAnnotations];
    }];
}

- (void)reloadEventAnnotationsIfNeeded
{
    if (self.mapView.zoom < kBRCMapViewArtAndEventsMinZoomLevel) {
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
    
    [self.eventsConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSMutableArray *eventAnnotationsToAdd = [NSMutableArray array];
        [transaction enumerateKeysInCollection:[BRCEventObject collection] usingBlock:^(NSString *key, BOOL *stop) {
            BRCEventObject *eventObject = [transaction objectForKey:key inCollection:[BRCEventObject collection]];
            
            //Check if event is currently happening or that the start time is in the next time window
            if([eventObject isHappeningRightNow] || [eventObject isStartingSoon]) {
                RMAnnotation *eventAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:eventObject];
                
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
            [self.mapView addAnnotations:self.eventAnnotations];
            if (oldAnnotations.count > 0) {
                [self.mapView removeAnnotations:oldAnnotations];
            }
        });
    }];
}

#pragma mark RMMapViewDelegate methods

- (void)afterMapZoom:(RMMapView *)map byUser:(BOOL)wasUserAction {
    if (map.zoom >= kBRCMapViewArtAndEventsMinZoomLevel) {
        [self reloadArtAnnotationsIfNeeded];
        [self reloadEventAnnotationsIfNeeded];
    } else {
        if (self.eventAnnotations.count > 0) {
            [self.mapView removeAnnotations:self.eventAnnotations];
            self.eventAnnotations = nil;
        }
        if (self.artAnnotations.count > 0) {
            [self.mapView removeAnnotations:self.artAnnotations];
            self.artAnnotations = nil;
        }
    }
}

- (void) singleTapOnMap:(RMMapView *)map at:(CGPoint)point {
    if (self.annotationEditView.mapPoint) {
        [self hideEditView:self.annotationEditView animated:YES completionBlock:^{
            [self reloadAllUserPoints];
        }];
    }
}

- (BOOL)mapView:(RMMapView *)mapView shouldDragAnnotation:(RMAnnotation *)annotation {
    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
        BRCMapPoint *draggedMapPoint = annotation.userInfo;
        BRCMapPoint *editingMapPoint = self.editingMapPointAnnotation.userInfo;
        BOOL shouldDragAnnotation = [draggedMapPoint.uuid isEqual:editingMapPoint.uuid];
        return shouldDragAnnotation;
    }
    return NO;
}

- (void)tapOnCalloutAccessoryControl:(UIControl *)control forAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    if ([annotation.userInfo isKindOfClass:[BRCDataObject class]]) {
        BRCDataObject *dataObject = annotation.userInfo;
        BRCDetailViewController *detailViewController = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
        [self.navigationController pushViewController:detailViewController animated:YES];
    }
    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
        self.editingMapPointAnnotation = annotation;
        [self showEditView:self.annotationEditView forAnnotation:annotation];
    }
}

- (RMMapLayer*) mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
    if (annotation.isUserLocationAnnotation) { // show default style
        return nil;
    }
    if ([annotation.userInfo isKindOfClass:[BRCDataObject class]]) {
        RMMapLayer *mapLayer = [super mapView:mapView layerForAnnotation:annotation];
        if (mapLayer) {
            mapLayer.canShowCallout = YES;
            mapLayer.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            return mapLayer;
        }
    }
    if ([annotation.userInfo isKindOfClass:[BRCMapPoint class]]) {
        RMMarker *userMapPointMarker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"BRCRedPin"]]; // user map points
        if ([annotation isEqual:self.editingMapPointAnnotation]) {
            userMapPointMarker.canShowCallout = NO;
        } else {
            userMapPointMarker.canShowCallout = YES;
            userMapPointMarker.rightCalloutAccessoryView = [[BButton alloc] initWithFrame:CGRectMake(0, 0, 35, 35) type:BButtonTypeDefault style:BButtonStyleBootstrapV3 icon:FAPencil fontSize:20];
        }
        return userMapPointMarker;
    }
    return nil;
}

#pragma mark BRCAnnotationEditViewDelegate methods

- (void) editViewDidSelectDelete:(BRCAnnotationEditView *)view mapPointToDelete:(BRCMapPoint *)mapPointToDelete {
    NSParameterAssert(mapPointToDelete != nil);
    if (mapPointToDelete) {
        [self.mapView removeAnnotation:self.editingMapPointAnnotation];
        self.editingMapPointAnnotation = nil;
        [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [transaction removeObjectForKey:mapPointToDelete.uuid inCollection:[BRCMapPoint collection]];
        } completionBlock:^{
            [self reloadAllUserPoints];
        }];
    }
    [self hideEditView:view animated:YES completionBlock:nil];
}

- (void) editViewDidSelectSave:(BRCAnnotationEditView *)view editedMapPoint:(BRCMapPoint *)editedMapPoint {
    NSParameterAssert(editedMapPoint != nil);
    if (editedMapPoint) {
        CLLocationCoordinate2D newCoordinate = self.editingMapPointAnnotation.coordinate;
        editedMapPoint.coordinate = newCoordinate;
        [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [transaction setObject:editedMapPoint forKey:editedMapPoint.uuid inCollection:[BRCMapPoint collection]];
        } completionBlock:^{
            [self reloadAllUserPoints];
        }];
    }
    [self hideEditView:view animated:YES completionBlock:nil];
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
        [self.searchActivityIndicatorView startAnimating];
        [self.view bringSubviewToFront:self.searchActivityIndicatorView];
        [self.readConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [[transaction ext:self.ftsExtensionName] enumerateKeysAndObjectsMatching:searchString usingBlock:^(NSString *collection, NSString *key, id object, BOOL *stop) {
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
    if (self.searchAnnotation) {
        [self.mapView removeAnnotation:self.searchAnnotation];
        self.searchAnnotation = nil;
    }
    
    if (![BRCEmbargo canShowLocationForObject:dataObject]) {
        [self.searchDisplayController setActive:NO animated:YES];
        RIButtonItem *dismissItem = [RIButtonItem itemWithLabel:@"Dismiss"];
        RIButtonItem *unlockItem = [RIButtonItem itemWithLabel:@"Unlock" action:^{
            BRCEmbargoPasscodeViewController *unlockVC = [[BRCEmbargoPasscodeViewController alloc] init];
            __weak BRCEmbargoPasscodeViewController *weakUnlock = unlockVC;
            unlockVC.dismissAction = ^{
                [weakUnlock dismissViewControllerAnimated:YES completion:nil];
            };
            [self presentViewController:unlockVC animated:YES
                             completion:nil];
        }];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Restricted" message:@"Sorry, location data for camps and events is only available after the gates open." cancelButtonItem:dismissItem otherButtonItems:unlockItem, nil];
        [alertView show];
    }
    else {
        if (dataObject.location) {
            self.searchAnnotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:dataObject];
            [self.mapView addAnnotation:self.searchAnnotation];
            [self.mapView brc_zoomToIncludeCoordinate:self.mapView.userLocation.coordinate andCoordinate:dataObject.location.coordinate inVisibleRect:self.mapView.bounds animated:YES];
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
    [cell setStyleFromDataObject:dataObject];
    [cell updateDistanceLabelFromLocation:self.mapView.userLocation.location toLocation:dataObject.location];
    // Adding gestures per state basis.
    UIImageView *viewState = [self imageViewForFavoriteStatus:dataObject.isFavorite];
    UIColor *color = [UIColor brc_navBarColor];
    [cell setSwipeGestureWithView:viewState color:color mode:MCSwipeTableViewCellModeSwitch state:MCSwipeTableViewCellState1 completionBlock:^(MCSwipeTableViewCell *swipeCell, MCSwipeTableViewCellState state, MCSwipeTableViewCellMode mode) {
        BRCDataObjectTableViewCell *dataCell = (BRCDataObjectTableViewCell*)swipeCell;
        [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            dataObject = [[transaction objectForKey:dataObject.uniqueID inCollection:[[dataObject class] collection]] copy];
        }];
        dataObject.isFavorite = !dataObject.isFavorite;
        [dataCell setStyleFromDataObject:dataObject];
        [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            if ([dataObject isKindOfClass:[BRCEventObject class]]) {
                BRCEventObject *event = (BRCEventObject*)dataObject;
                if (event.isFavorite) {
                    [BRCEventObject scheduleNotificationForEvent:event transaction:transaction];
                } else {
                    [BRCEventObject cancelScheduledNotificationForEvent:event transaction:transaction];
                }
            }
            [transaction setObject:dataObject forKey:dataObject.uniqueID inCollection:[[dataObject class] collection]];
        } completionBlock:^{
            [self.searchController.searchResultsTableView reloadData];
        }];
    }];
    cell.delegate = self;
    
    return cell;
}

- (void)swipeTableViewCell:(BRCDataObjectTableViewCell *)cell didSwipeWithPercentage:(CGFloat)percentage {
    NSIndexPath *indexPath = [self.searchController.searchResultsTableView indexPathForCell:cell];
    __block BRCDataObject *dataObject = [self dataObjectForIndexPath:indexPath tableView:self.searchController.searchResultsTableView];
    // We want to switch states to give a hint of the future value
    // is there a way to optimize this further?
    if (percentage >= cell.firstTrigger) {
        BOOL inverseFavorite = !dataObject.isFavorite;
        cell.view1 = [self imageViewForFavoriteStatus:inverseFavorite];
        [cell setTitleLabelBold:inverseFavorite];
    } else if (percentage < cell.firstTrigger) {
        BOOL isFavorite = dataObject.isFavorite;
        cell.view1 = [self imageViewForFavoriteStatus:isFavorite];
        [cell setTitleLabelBold:isFavorite];
    }
}

- (void) centerMapAtManCoordinates {
    [self.mapView brc_zoomToFullTileSourceAnimated:YES];
    [self.mapView brc_moveToBlackRockCityCenterAnimated:YES];
}

- (UIImageView *) imageViewForFavoriteStatus:(BOOL)isFavorite {
    UIImageView *viewState = nil;
    if (isFavorite) {
        viewState = self.favoriteImageView;
    } else {
        viewState = self.notYetFavoriteImageView;
    }
    return viewState;
}

@end
