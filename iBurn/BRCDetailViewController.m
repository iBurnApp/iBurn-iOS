//
//  BRCDetailViewController.m
//  iBurn
//
//  Created by David Chiles on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDetailViewController.h"
#import "BRCDetailCellInfo.h"
#import "BRCRelationshipDetailInfoCell.h"
#import "BRCDataObject.h"
#import "BRCDatabaseManager.h"
#import <MessageUI/MessageUI.h>
#import "MGLMapView+iBurn.h"
@import Mapbox;
#import "BRCDetailInfoTableViewCell.h"
#import "PureLayout.h"
#import "BRCEmbargo.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"
#import "BRCAppDelegate.h"
#import "BRCEventRelationshipDetailInfoCell.h"
#import "iBurn-Swift.h"
@import JTSImageViewController;

static CGFloat const kTableViewHeaderHeight = 200;

@interface BRCDetailViewController () <MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) BRCDataObject *dataObject;
@property (nonatomic, strong, readwrite, nullable) BRCObjectMetadata *metadata;
@property (nonatomic, strong) NSArray<BRCDetailCellInfo*> *detailCellInfoArray;
@property (nonatomic, strong) UIBarButtonItem *favoriteBarButtonItem;
@property (nonatomic, strong) MGLMapView *mapView;
@property (nonatomic, strong) MapViewDelegate *mapViewDelegate;
@end

@implementation BRCDetailViewController

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithDataObject:(BRCDataObject *)dataObject
{
    NSParameterAssert(dataObject);
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        _colors = BRCImageColors.plain;
        self.dataObject = dataObject;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseExtensionRegistered:) name:BRCDatabaseExtensionRegisteredNotification object:BRCDatabaseManager.shared];

    }
    return self;
}

- (void) databaseExtensionRegistered:(NSNotification*)notification {
    NSString *extensionName = notification.userInfo[@"extensionName"];
    if ([extensionName isEqualToString:BRCDatabaseManager.shared.relationships]) {
        NSLog(@"databaseExtensionRegistered: %@", extensionName);
        self.dataObject = self.dataObject; // retrigger info array population
        [self.tableView reloadData];
    }
}

- (void)setDataObject:(BRCDataObject *)dataObject
{
    _dataObject = dataObject;
    __block BRCObjectMetadata *metadata = nil;
    [BRCDatabaseManager.shared.readConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        metadata = [dataObject metadataWithTransaction:transaction];
    }];
    self.metadata = metadata;
    if ([dataObject isKindOfClass:BRCEventObject.class]) {
        BRCEventObject *event = (BRCEventObject*)dataObject;
        _colors = [BRCImageColors colorsFor:event.eventType];
    }
    self.title = dataObject.title;
    self.detailCellInfoArray = [BRCDetailCellInfo infoArrayForObject:self.dataObject];
    [self setupMapViewWithObject:self.dataObject];
    [self configureColors:self.colors];
    [self.tableView reloadData];
}

- (void) setMetadata:(BRCObjectMetadata * _Nullable)metadata {
    _metadata = metadata;
    if ([metadata isKindOfClass:BRCArtMetadata.class]) {
        BRCArtMetadata *art = (BRCArtMetadata*)metadata;
        BRCImageColors *colors = art.thumbnailImageColors;
        if (colors) {
            _colors = colors;
        }
    }
    [self refreshFavoriteImage];
}

- (void) configureColors:(BRCImageColors*)colors {
    [self.tableView setColorTheme:colors animated:NO];
    [self setColorTheme:colors animated:NO];
}

- (void) refreshFavoriteImage {
    self.favoriteBarButtonItem.image = [self currentStarImage];
}

- (void) setNavbarStyle:(BOOL)animated {
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (!navBar) {
        return;
    }
    [navBar setColorTheme:self.colors animated:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.estimatedRowHeight = 44.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    [self.tableView registerClass:[BRCDetailInfoTableViewCell class] forCellReuseIdentifier:[BRCDetailInfoTableViewCell cellIdentifier]];
    
    self.favoriteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[self currentStarImage] style:UIBarButtonItemStylePlain target:self action:@selector(didTapFavorite:)];
    self.favoriteBarButtonItem.tintColor = [UIColor colorWithRed: 254./255 green: 110./255 blue: 111./255 alpha: 1.0];
    
    self.navigationItem.rightBarButtonItem = self.favoriteBarButtonItem;
}

- (void) beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated {
    [super beginAppearanceTransition:isAppearing animated:animated];
    if (isAppearing) {
        [self setNavbarStyle:animated];
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.mapView) {
        CGRect headerFrame = CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), kTableViewHeaderHeight);
        
        UIView *clearHeaderView = [[UIView alloc] initWithFrame:headerFrame];
        clearHeaderView.backgroundColor = [UIColor clearColor];
        
        CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
        
        self.mapView.frame = CGRectMake(0, -viewHeight+kTableViewHeaderHeight, CGRectGetWidth(self.view.bounds), viewHeight);
        [clearHeaderView addSubview:self.mapView];
        [self.mapView autoPinEdgesToSuperviewEdges];
        
        [clearHeaderView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapMapContainerview:)]];
        
        if ([self.dataObject isKindOfClass:BRCArtObject.class]) {
            self.tableView.tableFooterView = clearHeaderView;
        } else {
            self.tableView.tableHeaderView = clearHeaderView;
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Mapbox ignores you if it isn't loaded yet
        UIEdgeInsets padding = UIEdgeInsetsMake(45, 45, 45, 45);
        [self.mapView brc_showDestinationForDataObject:self.dataObject animated:NO padding:padding];
    });
}

- (UIImage*)imageIfFavorite:(BOOL)isFavorite {
    UIImage *starImage = nil;
    if (isFavorite) {
        starImage = [UIImage imageNamed:@"BRCHeartFilledIcon"];
    }
    else {
        starImage = [UIImage imageNamed:@"BRCHeartIcon"];
    }
    return starImage;
}

- (UIImage *)currentStarImage
{
    UIImage *starImage = [self imageIfFavorite:self.metadata.isFavorite];
    return starImage;
}

- (void)didTapFavorite:(id)sender
{
    if (!self.dataObject) {
        return;
    }
    BRCObjectMetadata *newMetadata = [self.metadata copy];
    newMetadata.isFavorite = !newMetadata.isFavorite;
    self.metadata = newMetadata;
    BRCDataObject *tempObject = self.dataObject;
    [BRCDatabaseManager.shared.readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self.dataObject replaceMetadata:newMetadata transaction:transaction];
        if ([tempObject isKindOfClass:[BRCEventObject class]]) {
            BRCEventObject *event = (BRCEventObject*)tempObject;
            [event refreshCalendarEntry:transaction];
        }
    }];
}

- (void)didTapMapContainerview:(id)sender
{
    MapDetailViewController *mapViewController = [[MapDetailViewController alloc] initWithDataObject:self.dataObject];
    mapViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:mapViewController animated:YES];
}

- (nullable BRCDetailCellInfo *)cellInfoForIndexPath:(NSIndexPath*)indexPath
{
    NSUInteger section = indexPath.section;
    if ([self.detailCellInfoArray count] > section) {
        return self.detailCellInfoArray[section];
    }
    return nil;
}

- (void)setupMapViewWithObject:(BRCDataObject *)dataObject
{
    if ((dataObject.location && [BRCEmbargo canShowLocationForObject:dataObject]) || dataObject.burnerMapLocation) {
        self.mapView = [[MGLMapView alloc] init];
        [self.mapView brc_setDefaults];
        self.mapViewDelegate = [[MapViewDelegate alloc] init];
        self.mapView.delegate = self.mapViewDelegate;
        MapAnnotation *annotation = [[MapAnnotation alloc] initWithObject:dataObject];
        if (annotation) {
            [self.mapView addAnnotation:annotation];
        }
        self.mapView.userInteractionEnabled = NO;
    }
    else {
        self.mapView = nil;
    }
}

//#pragma - mark RMMapviewDelegate Methods
//
//- (nullable MGLAnnotationImage *)mapView:(MGLMapView *)mapView imageForAnnotation:(id <MGLAnnotation>)annotation {
//    NSString *reuseIdentifier = @"Pin";
//    MGLAnnotationImage *annotationImage = [mapView dequeueReusableAnnotationImageWithIdentifier:reuseIdentifier];
//    UIImage *image = [UIImage imageNamed:@"BRCPurplePin"];
//    if ([annotation isKindOfClass:[BRCDataObject class]]) {
//        BRCDataObject *dataObject = (BRCDataObject*)annotation;
//        image = dataObject.markerImage;
//    }
//    if (!annotationImage) {
//        annotationImage = [MGLAnnotationImage annotationImageWithImage:image reuseIdentifier:reuseIdentifier];
//    } else {
//        annotationImage.image = image;
//    }
//    return annotationImage;
//}


#pragma - mark UITableViewDataSource Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDetailInfoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[BRCDetailInfoTableViewCell cellIdentifier] forIndexPath:indexPath];
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath];
    [cell setDetailCellInfo:cellInfo object:self.dataObject colors:self.colors];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.detailCellInfoArray count];
}

- (void) tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if (!self.colors) {
        return;
    }
    UITableViewHeaderFooterView *hfv = (UITableViewHeaderFooterView*)view;
    if (![hfv isKindOfClass:UITableViewHeaderFooterView.class]) {
        return;
    }
    hfv.textLabel.textColor = self.colors.detailColor;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath];
    if (cellInfo.cellType == BRCDetailCellInfoTypeImage) {
        // There is a "bug"/feature where returning 0 doesn't give 0 height
        return 0.01;
    } else if (cellInfo.cellType == BRCDetailCellInfoTypeText &&
               [cellInfo.key isEqualToString:NSStringFromSelector(@selector(detailDescription))]) {
        // This is the description, so we don't really need a heading for it.
        return 0.01;
    }
    return UITableViewAutomaticDimension;
}



- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *title = nil;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath];
    if (cellInfo) {
        // We don't need a header for the image itself
        if (cellInfo.cellType == BRCDetailCellInfoTypeImage) {
            return nil;
        } else if (cellInfo.cellType == BRCDetailCellInfoTypeText &&
                  [cellInfo.key isEqualToString:NSStringFromSelector(@selector(detailDescription))]) {
            // This is the description, so we don't really need a heading for it.
            return nil;
        }
        title = cellInfo.displayName;
    }
    return title;
}

#pragma - mark UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath];
    if (cellInfo.cellType == BRCDetailCellInfoTypeURL) {
        NSURL *url = cellInfo.value;
        [BRCAppDelegate openURL:url fromViewController:self];
    }
    else if (cellInfo.cellType == BRCDetailCellInfoTypeEmail) {
        
        if ([MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *mailComposeViewController = [[MFMailComposeViewController alloc] init];
            mailComposeViewController.mailComposeDelegate = self;
            [mailComposeViewController setToRecipients:@[cellInfo.value]];
            [self presentViewController:mailComposeViewController animated:YES completion:nil];
        }
    }
    else if(cellInfo.cellType == BRCDetailCellInfoTypeRelationship)
    {
        // Go to correct camp page
        BRCRelationshipDetailInfoCell *relationshipCellInfo = (BRCRelationshipDetailInfoCell *)cellInfo;
        __block BRCDataObject *dataObject = nil;
        [BRCDatabaseManager.shared.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            dataObject = [relationshipCellInfo.dataObject refetchWithTransaction:transaction];
        }];
        BRCDetailViewController *detailVC = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
        [self.navigationController pushViewController:detailVC animated:YES];
        
    } else if(cellInfo.cellType == BRCDetailCellInfoTypeEventRelationship) {
        // Shows events
        BRCEventRelationshipDetailInfoCell *eventRelationshipCellInfo = (BRCEventRelationshipDetailInfoCell *)cellInfo;
        BRCDataObject *relatedObject = eventRelationshipCellInfo.dataObject;
        HostedEventsViewController *eventsVC = [[HostedEventsViewController alloc] initWithStyle:UITableViewStyleGrouped extensionName:BRCDatabaseManager.shared.relationships relatedObject:relatedObject];
        [self.navigationController pushViewController:eventsVC animated:YES];
        
    } else if (cellInfo.cellType == BRCDetailCellInfoTypeCoordinates) {
        CLLocation *location = cellInfo.value;
        NSString *coordinatesString = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc]
                                                            initWithActivityItems:@[coordinatesString] applicationActivities:nil];
        [self presentViewController:activityViewController animated:YES completion:nil];
    } else if (cellInfo.cellType == BRCDetailCellInfoTypeImage) {
        NSURL *imageURL = cellInfo.value;
        UIImage *image = [UIImage imageWithContentsOfFile:imageURL.path];
        if (image) {
            // Create image info
            JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
            imageInfo.image = image;
            CGRect rect = [tableView rectForRowAtIndexPath:indexPath];
            imageInfo.referenceRect = rect;
            imageInfo.referenceView = tableView;
            
            // Setup view controller
            JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                                   initWithImageInfo:imageInfo
                                                   mode:JTSImageViewControllerMode_Image
                                                   backgroundStyle:JTSImageViewControllerBackgroundOption_Scaled];
            
            // Present the view controller.
            [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
        }
        
    } else if (cellInfo.cellType == BRCDetailCellInfoTypeAudio) {
        if ([self.dataObject isKindOfClass:[BRCArtObject class]]) {
            BRCArtObject *art = (BRCArtObject*)self.dataObject;
            if ([[BRCAudioPlayer sharedInstance] isPlaying:art]) {
                [[BRCAudioPlayer sharedInstance] togglePlayPause];
            } else if (art.audioURL) {
                [[BRCAudioPlayer sharedInstance] playAudioTour:@[art]];
            }
        }
    } else if (cellInfo.cellType == BRCDetailCellInfoTypePlayaAddress) {
        CLLocation *location = self.dataObject.location;
        if (!location) {
            location = self.dataObject.burnerMapLocation;
        }
        if ([cellInfo.key isEqualToString:NSStringFromSelector(@selector(playaLocation))] && ![BRCEmbargo canShowLocationForObject:self.dataObject]) {
            location = nil;
        }
        if (location) {
            [self didTapMapContainerview:tableView];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

#pragma - mark UIScrollViewDelegate

//- (void)scrollViewDidScroll:(UIScrollView *)scrollView
//{
//    CGFloat navBarY = CGRectGetMaxY(self.navigationController.navigationBar.frame);
//    CGFloat contentOffSetY = scrollView.contentOffset.y;
//    CGFloat headerViewHeight = CGRectGetHeight(self.tableView.tableHeaderView.frame);
//    CGFloat visibelHeight = headerViewHeight - (navBarY + contentOffSetY);
//    CGRect mapRect = CGRectZero;
//    if (visibelHeight > 0) {
//        mapRect = CGRectMake(0, headerViewHeight - visibelHeight, CGRectGetWidth(self.tableView.tableHeaderView.frame), visibelHeight);
//    }
//    self.mapView.frame = mapRect;
//    [self.mapView brc_showDestinationForDataObject:self.dataObject animated:NO];
//}


#pragma - mark MFMailComposeViewControllerDelegate 

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
