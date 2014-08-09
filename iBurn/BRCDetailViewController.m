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
#import "BRCAnnotation.h"
#import "RMUserLocation.h"
#import "RMMarker+iBurn.h"
#import "BRCDetailInfoTableViewCell.h"
#import "BRCDetailMapViewController.h"
#import "PureLayout.h"
#import "BRCEmbargo.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"
#import "BRCLocations.h"

static NSString * const kBRCRowHeightDummyCellIdentifier = @"kBRCRowHeightDummyCellIdentifier";

static CGFloat const kMapHeaderOffsetY = -150.0;
static CGFloat const kMapHeaderHeight = 250.0;

@interface BRCDetailViewController () <UITableViewDataSource, UITableViewDelegate, MFMailComposeViewControllerDelegate, RMMapViewDelegate>

@property (nonatomic, strong) BRCDataObject *dataObject;
@property (nonatomic, strong) NSArray *detailCellInfoArray;
@property (nonatomic, strong) UIBarButtonItem *favoriteBarButtonItem;
@property (nonatomic, strong) RMMapView *mapView;
@property (nonatomic, strong) UIView *fakeTableViewBackground;
@property (nonatomic) BOOL didSetContraints;

@end

@implementation BRCDetailViewController

- (instancetype)initWithDataObject:(BRCDataObject *)dataObject
{
    if (self = [self init]) {
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


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.view.backgroundColor = self.tableView.backgroundColor;
    self.tableView.backgroundView = nil;
    self.tableView.backgroundView = [[UIView alloc] init];
    self.tableView.backgroundColor = [UIColor clearColor];
    
    [self.tableView registerClass:[BRCDetailInfoTableViewCell class] forCellReuseIdentifier:[BRCDetailInfoTableViewCell cellIdentifier]];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kBRCRowHeightDummyCellIdentifier];
    
    [self.view addSubview:self.tableView];
    
    if (self.mapView) {
        CGRect mapFrame = CGRectMake(0.0, 0.0, self.view.bounds.size.width, kMapHeaderHeight);
        self.fakeTableViewBackground = [[UIView alloc] init];
        self.fakeTableViewBackground.backgroundColor = self.view.backgroundColor;
        self.fakeTableViewBackground.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.mapView.frame = CGRectMake(0, kMapHeaderOffsetY, self.view.bounds.size.width, self.view.bounds.size.height + ABS(kMapHeaderOffsetY));
        UIView *tableHeader = [[UIView alloc] initWithFrame: mapFrame];
        [tableHeader addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapMapContainerview:)]];
        tableHeader.backgroundColor = [UIColor clearColor];
        self.tableView.tableHeaderView = tableHeader;
        
        [self.view insertSubview:self.mapView belowSubview:self.tableView];
        [self.view insertSubview:self.fakeTableViewBackground belowSubview:self.tableView];
    }
    
    
    
    self.favoriteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[self currentStarImage] style:UIBarButtonItemStylePlain target:self action:@selector(didTapFavorite:)];
    
    self.navigationItem.rightBarButtonItem = self.favoriteBarButtonItem;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    CGRect rect = self.tableView.tableHeaderView.bounds;
    rect.origin.y = kMapHeaderOffsetY;
    if ([BRCEmbargo canShowLocationForObject:self.dataObject]) {
        [self.mapView brc_zoomToIncludeCoordinate:self.dataObject.location.coordinate andCoordinate:self.mapView.userLocation.location.coordinate inVisibleRect:rect animated:animated];
    }
    else {
        [self.mapView setZoom:14.0 atCoordinate:[BRCLocations blackRockCityCenter] animated:animated];
    }
    
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    if (self.didSetContraints) {
        return;
    }
    
    [self.tableView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(0, 0, 0, 0) excludingEdge:ALEdgeBottom];
    [self.tableView autoPinToBottomLayoutGuideOfViewController:self withInset:0];
    
    [self.fakeTableViewBackground autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.fakeTableViewBackground autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(0, 0, 0, 0) excludingEdge:ALEdgeTop];
    [self.fakeTableViewBackground autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.tableView.tableHeaderView];
    
    self.didSetContraints = YES;
}

- (UIImage*)imageIfFavorite:(BOOL)isFavorite {
    UIImage *starImage = nil;
    if (isFavorite) {
        starImage = [UIImage imageNamed:@"BRCDarkStar"];
    }
    else {
        starImage = [UIImage imageNamed:@"BRCLightStar"];
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
    __block BRCDataObject *tempObject = nil;
    UIImage *reverseFavoriteImage = [self imageIfFavorite:!self.dataObject.isFavorite];
    self.favoriteBarButtonItem.image = reverseFavoriteImage;
    [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        tempObject = [transaction objectForKey:self.dataObject.uniqueID inCollection:[[self.dataObject class] collection]];
        if (tempObject) {
            tempObject = [tempObject copy];
            tempObject.isFavorite = !tempObject.isFavorite;
            [transaction setObject:tempObject forKey:tempObject.uniqueID inCollection:[[tempObject class] collection]];
        }
    } completionBlock:^{
        self.dataObject = tempObject;
    }];
}

- (void)didTapMapContainerview:(id)sender
{
    BRCDetailMapViewController *mapViewController = [[BRCDetailMapViewController alloc] initWithDataObject:self.dataObject];
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
        self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        BRCAnnotation *annotation = [BRCAnnotation annotationWithMapView:self.mapView dataObject:dataObject];
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
    if ([annotation isKindOfClass:[BRCAnnotation class]]) {
        BRCAnnotation *brcAnnotation = (BRCAnnotation*)annotation;
        BRCDataObject *dataObject = brcAnnotation.dataObject;
        
        return [RMMarker brc_defaultMarkerForDataObject:dataObject];
        
    }
    return nil;
}

#pragma - mark UITableViewDataSource Methods

////// Required //////
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

////// Optional //////

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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath.section];
    if (cellInfo.cellType == BRCDetailCellInfoTypeText || cellInfo.cellType == BRCDetailCellInfoTypeSchedule) {
        NSString *cellText = nil;
        if (cellInfo.cellType == BRCDetailCellInfoTypeText) {
            cellText = cellInfo.value;
        } else if (cellInfo.cellType == BRCDetailCellInfoTypeSchedule) {
            NSAttributedString *attrStr = cellInfo.value;
            cellText = [attrStr string];
        }
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kBRCRowHeightDummyCellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kBRCRowHeightDummyCellIdentifier];
        }
        CGRect labelSize = [cellText boundingRectWithSize:CGSizeMake(tableView.bounds.size.width, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: cell.textLabel.font} context:nil];

#warning Cuts off some multi line text
        return labelSize.size.height + 20;
    }
    
    return 44.0f;
    
}

#pragma - mark UITableViewDelegate Methods

////// Optional //////

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath.section];
    if (cellInfo.cellType == BRCDetailCellInfoTypeURL) {
        [[UIApplication sharedApplication] openURL:cellInfo.value];
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
        [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            dataObject = [transaction objectForKey:relationshipCellInfo.dataObject.uniqueID inCollection:[[relationshipCellInfo.dataObject class]collection]];
            
            
        } completionBlock:^{
            [self.navigationController pushViewController:[[BRCDetailViewController alloc] initWithDataObject:dataObject] animated:YES];
        }];
        
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
    CGFloat scrollOffset = scrollView.contentOffset.y;
    CGRect headerFrame = self.mapView.frame;
    
    if (scrollOffset < 0)
    {
        headerFrame.origin.y = MIN(kMapHeaderOffsetY - ((scrollOffset / 3)), 0);
        
    }
    else //scrolling up
    {
        headerFrame.origin.y = kMapHeaderOffsetY - scrollOffset;
    }
    
    self.mapView.frame = headerFrame;
}


#pragma - mark MFMailComposeViewControllerDelegate 

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
