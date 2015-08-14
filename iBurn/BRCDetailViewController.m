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
#import "RMMapView+iBurn.h"
#import "RMAnnotation+iBurn.h"
#import "RMUserLocation.h"
#import "RMMarker+iBurn.h"
#import "BRCDetailInfoTableViewCell.h"
#import "BRCDetailMapViewController.h"
#import "PureLayout.h"
#import "BRCEmbargo.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"
#import "BRCLocations.h"
#import "BRCAppDelegate.h"
@import Parse;
#import "PFAnalytics+iBurn.h"

static CGFloat const kTableViewHeaderHeight = 100;

@interface BRCDetailViewController () <MFMailComposeViewControllerDelegate, RMMapViewDelegate>

@property (nonatomic, strong) BRCDataObject *dataObject;
@property (nonatomic, strong) NSArray *detailCellInfoArray;
@property (nonatomic, strong) UIBarButtonItem *favoriteBarButtonItem;
@property (nonatomic, strong) RMMapView *mapView;

@end

@implementation BRCDetailViewController

- (instancetype)initWithDataObject:(BRCDataObject *)dataObject
{
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        self.dataObject = dataObject;
    }
    return self;
}

- (void)setDataObject:(BRCDataObject *)dataObject
{
    _dataObject = dataObject;
    self.title = dataObject.title;
    self.detailCellInfoArray = [BRCDetailCellInfo infoArrayForObject:self.dataObject];
    [self setupMapViewWithObject:self.dataObject];
    [self refreshFavoriteImage];
    [self.tableView reloadData];
}

- (void) refreshFavoriteImage {
    self.favoriteBarButtonItem.image = [self currentStarImage];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [PFAnalytics brc_trackEventInBackground:@"Detail" object:self.dataObject];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.estimatedRowHeight = 44.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    [self.tableView registerClass:[BRCDetailInfoTableViewCell class] forCellReuseIdentifier:[BRCDetailInfoTableViewCell cellIdentifier]];
    
    if (self.mapView) {
        CGRect headerFrame = CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), kTableViewHeaderHeight);
        
        UIView *clearHeaderView = [[UIView alloc] initWithFrame:headerFrame];
        clearHeaderView.backgroundColor = [UIColor clearColor];
        
        CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
        
        self.mapView.frame = CGRectMake(0, -viewHeight+kTableViewHeaderHeight, CGRectGetWidth(self.view.bounds), viewHeight);
        [clearHeaderView addSubview:self.mapView];
        
        [clearHeaderView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapMapContainerview:)]];
        
        self.tableView.tableHeaderView = clearHeaderView;
    }
    
    self.favoriteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[self currentStarImage] style:UIBarButtonItemStylePlain target:self action:@selector(didTapFavorite:)];
    self.favoriteBarButtonItem.tintColor = [UIColor colorWithRed: 254./255 green: 110./255 blue: 111./255 alpha: 1.0];
    
    self.navigationItem.rightBarButtonItem = self.favoriteBarButtonItem;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    CGRect rect = self.tableView.tableHeaderView.bounds;
    [self updateMapViewInRect:rect animated:NO];
}

- (void)updateMapViewInRect:(CGRect)rect animated:(BOOL)animated
{
    CLLocation *objectLocation = self.dataObject.location;
    if ([BRCEmbargo canShowLocationForObject:self.dataObject] && objectLocation) {
        CLLocation *userLocation = self.mapView.userLocation.location;
        if (userLocation) {
            [self.mapView brc_zoomToIncludeCoordinate:objectLocation.coordinate andCoordinate:userLocation.coordinate inVisibleRect:rect animated:animated];
        } else {
            [self.mapView brc_zoomToIncludeCoordinate:objectLocation.coordinate andCoordinate:objectLocation.coordinate inVisibleRect:rect animated:animated];
        }
    } else {
        [self.mapView setZoom:14.0 atCoordinate:[BRCLocations blackRockCityCenter] animated:animated];
    }
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
    UIImage *starImage = [self imageIfFavorite:self.dataObject.isFavorite];
    return starImage;
}

- (void)didTapFavorite:(id)sender
{
    if (!self.dataObject) {
        return;
    }
    BRCDataObject *tempObject = [self.dataObject copy];
    tempObject.isFavorite = !tempObject.isFavorite;
    self.dataObject = tempObject;
    if (self.dataObject.isFavorite) {
        [PFAnalytics brc_trackEventInBackground:@"Favorite" object:self.dataObject];
    }
    [[BRCDatabaseManager sharedInstance].readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction setObject:tempObject forKey:tempObject.uniqueID inCollection:[[tempObject class] collection]];
        if ([tempObject isKindOfClass:[BRCEventObject class]]) {
            BRCEventObject *event = (BRCEventObject*)tempObject;
            if (event.isFavorite) {
                [BRCEventObject scheduleNotificationForEvent:event transaction:transaction];
            } else {
                [BRCEventObject cancelScheduledNotificationForEvent:event transaction:transaction];
            }
        }
    }];
}

- (void)didTapMapContainerview:(id)sender
{
    BRCDetailMapViewController *mapViewController = [[BRCDetailMapViewController alloc] initWithDataObject:self.dataObject];
    mapViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:mapViewController animated:YES];
}

- (BRCDetailCellInfo *)cellInfoForIndexPath:(NSInteger)section
{
    if ([self.detailCellInfoArray count] > section) {
        return self.detailCellInfoArray[section];
    }
    return nil;
}

- (void)setupMapViewWithObject:(BRCDataObject *)dataObject
{
    if (dataObject.location) {
        self.mapView = [RMMapView brc_defaultMapViewWithFrame:CGRectMake(0, 0, 10, 150)];
        self.mapView.delegate = self;
        self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        RMAnnotation *annotation = [RMAnnotation brc_annotationWithMapView:self.mapView dataObject:dataObject];
        [self.mapView addAnnotation:annotation];
        self.mapView.draggingEnabled = NO;
        self.mapView.userInteractionEnabled = NO;
    }
    else {
        self.mapView = nil;
    }
}

#pragma - mark RMMapviewDelegate Methods

- (RMMapLayer*) mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
    if (annotation.isUserLocationAnnotation || ![BRCEmbargo canShowLocationForObject:self.dataObject]) { // show default style
        return nil;
    }
    if ([annotation.userInfo isKindOfClass:[BRCDataObject class]]) {
        BRCDataObject *dataObject = annotation.userInfo;
        
        return [RMMarker brc_defaultMarkerForDataObject:dataObject];
        
    }
    return nil;
}

#pragma - mark UITableViewDataSource Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDetailInfoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[BRCDetailInfoTableViewCell cellIdentifier] forIndexPath:indexPath];
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath.section];
    [cell setDetailCellInfo:cellInfo];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.detailCellInfoArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *title = nil;
    
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:section];
    if (cellInfo) {
        BRCDetailCellInfo *cellInfo = self.detailCellInfoArray[section];
        title = cellInfo.displayName;
    }
    return title;
}

#pragma - mark UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath.section];
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
        [[BRCDatabaseManager sharedInstance].readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            dataObject = [transaction objectForKey:relationshipCellInfo.dataObject.uniqueID inCollection:[[relationshipCellInfo.dataObject class]collection]];
        }];
        BRCDetailViewController *detailVC = [[BRCDetailViewController alloc] initWithDataObject:dataObject];
        [self.navigationController pushViewController:detailVC animated:YES];
        
    } else if (cellInfo.cellType == BRCDetailCellInfoTypeCoordinates) {
        CLLocation *location = cellInfo.value;
        NSString *coordinatesString = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc]
                                                            initWithActivityItems:@[coordinatesString] applicationActivities:nil];
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

#pragma - mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat navBarY = CGRectGetMaxY(self.navigationController.navigationBar.frame);
    CGFloat contentOffSetY = scrollView.contentOffset.y;
    CGFloat headerViewHeight = CGRectGetHeight(self.tableView.tableHeaderView.frame);
    CGFloat visibelHeight = headerViewHeight - (navBarY + contentOffSetY);
    CGRect mapRect = CGRectZero;
    if (visibelHeight > 0) {
        mapRect = CGRectMake(0, headerViewHeight - visibelHeight, CGRectGetWidth(self.tableView.tableHeaderView.frame), visibelHeight);
    }
    self.mapView.frame = mapRect;
    [self updateMapViewInRect:mapRect animated:NO];
}


#pragma - mark MFMailComposeViewControllerDelegate 

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
