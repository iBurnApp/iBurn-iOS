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
#import "BRCMapView.h"
#import "BRCAnnotation.h"
#import "RMUserLocation.h"

#import "BRCDetailMapViewController.h"

NSString *const BRCTextCellIdentifier = @"BRCTextCellIdentifier";

@interface BRCDetailViewController () <UITableViewDataSource, UITableViewDelegate, MFMailComposeViewControllerDelegate, RMMapViewDelegate>

@property (nonatomic, strong) BRCDataObject *dataObject;

@property (nonatomic, strong) NSArray *detailCellInfoArray;

@property (nonatomic, strong) UIBarButtonItem *favoriteBarButtonItem;

@property (nonatomic, strong) BRCMapView *mapView;

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
    self.favoriteBarButtonItem.image = [self currentStarImage];
    self.title = dataObject.title;
    self.detailCellInfoArray = [BRCDetailCellInfo infoArrayForObject:self.dataObject];
    [self setupMapViewWithObject:self.dataObject];
    [self.tableView reloadData];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:BRCTextCellIdentifier];
    
    if (self.mapView) {
        self.tableView.tableHeaderView = self.mapView;
    }
    
    [self.view addSubview:self.tableView];
    
    self.favoriteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[self currentStarImage] style:UIBarButtonItemStylePlain target:self action:@selector(didTapFavorite:)];
    
    self.navigationItem.rightBarButtonItem = self.favoriteBarButtonItem;
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.mapView zoomToIncludeCoordinate:self.dataObject.location.coordinate andCoordinate:self.mapView.userLocation.location.coordinate animated:animated];
    
}

- (UIImage *)currentStarImage
{
    UIImage *starImage = nil;
    if (self.dataObject.isFavorite) {
        starImage = [UIImage imageNamed:@"BRCDarkStar"];
    }
    else {
        starImage = [UIImage imageNamed:@"BRCLightStar"];
    }
    return starImage;
}

- (void)didTapFavorite:(id)sender
{
    __block BRCDataObject *tempObject = nil;
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
        self.mapView = [BRCMapView defaultMapViewWithFrame:CGRectMake(0, 0, 10, 250)];
        self.mapView.delegate = self;
        RMAnnotation *annotation = [BRCAnnotation annotationWithMapView:self.mapView dataObject:dataObject];
        [self.mapView addAnnotation:annotation];
        self.mapView.draggingEnabled = NO;
    }
    else {
        self.mapView = nil;
    }
}

#pragma - mark RMMapviewDelegate Methods

- (void)singleTapOnMap:(RMMapView *)map at:(CGPoint)point
{
    BRCDetailMapViewController *mapViewController = [[BRCDetailMapViewController alloc] initWithDataObject:self.dataObject];
    [self.navigationController pushViewController:mapViewController animated:YES];
}

#pragma - mark UITableViewDataSource Methods

////// Required //////
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    BRCDetailCellInfo *cellInfo = [self cellInfoForIndexPath:indexPath.section];
    if (cellInfo) {
        
        
        switch (cellInfo.cellType) {
            case BRCDetailCellInfoTypeEmail:
            case BRCDetailCellInfoTypeText: {
                cell = [tableView dequeueReusableCellWithIdentifier:BRCTextCellIdentifier forIndexPath:indexPath];
                cell.textLabel.text = cellInfo.value;
                cell.textLabel.textColor = [UIColor blackColor];
                cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
                cell.textLabel.numberOfLines = 0;
                
                break;
            }
            case BRCDetailCellInfoTypeURL: {
                cell = [tableView dequeueReusableCellWithIdentifier:BRCTextCellIdentifier forIndexPath:indexPath];
                cell.textLabel.textColor = [UIColor blueColor];
                NSURL *url = cellInfo.value;
                cell.textLabel.text = [url absoluteString];
                
                break;

            }
            case BRCDetailCellInfoTypeCoordinates: {
                cell = [tableView dequeueReusableCellWithIdentifier:BRCTextCellIdentifier forIndexPath:indexPath];
                cell.textLabel.text = @"Coordinates";
                
                break;
            }
                
                
            case BRCDetailCellInfoTypeRelationship: {
                cell = [tableView dequeueReusableCellWithIdentifier:BRCTextCellIdentifier forIndexPath:indexPath];
                BRCRelationshipDetailInfoCell *relationshipCellInfo = (BRCRelationshipDetailInfoCell *)cellInfo;
                cell.textLabel.text = relationshipCellInfo.dataObject.title;
                break;
            }
                
        }
        
        
    }
    
    
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
    if (cellInfo.cellType == BRCDetailCellInfoTypeText) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        
        
        CGRect labelSize = [cellInfo.value boundingRectWithSize:CGSizeMake(tableView.bounds.size.width, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: cell.textLabel.font} context:nil];
        
        
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
        
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

#pragma - mark MFMailComposeViewControllerDelegate 

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
