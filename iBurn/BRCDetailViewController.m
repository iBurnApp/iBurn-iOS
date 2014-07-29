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

NSString *const BRCTextCellIdentifier = @"BRCTextCellIdentifier";

@interface BRCDetailViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) BRCDataObject *dataObject;

@property (nonatomic, strong) NSArray *detailCellInfoArray;

@property (nonatomic, strong) UIBarButtonItem *favoriteBarButtonItem;

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
    
    [self.view addSubview:self.tableView];
    
    self.favoriteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[self currentStarImage] style:UIBarButtonItemStylePlain target:self action:@selector(didTapFavorite:)];
    
    self.navigationItem.rightBarButtonItem = self.favoriteBarButtonItem;
    
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

#pragma - mark UITableViewDataSource Methods

////// Required //////
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if ([self.detailCellInfoArray count] > indexPath.section) {
        BRCDetailCellInfo *cellInfo = self.detailCellInfoArray[indexPath.section];
        
        switch (cellInfo.cellType) {
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
                cell.textLabel.text = @"Relationshiip";
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
    if ([self.detailCellInfoArray count] > section) {
        BRCDetailCellInfo *cellInfo = self.detailCellInfoArray[section];
        title = cellInfo.displayName;
    }
    return title;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCDetailCellInfo *cellInfo = self.detailCellInfoArray[indexPath.section];
    if (cellInfo.cellType == BRCDetailCellInfoTypeText) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        
        
        CGRect labelSize = [cellInfo.value boundingRectWithSize:CGSizeMake(tableView.bounds.size.width, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: cell.textLabel.font} context:nil];
        
        return labelSize.size.height + 20;
    }
    
    return 44.0f;
    
}

#pragma - mark UITableViewDelegate Methods

////// Optional //////

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

@end
