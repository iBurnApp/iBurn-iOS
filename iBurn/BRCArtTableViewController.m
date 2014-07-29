//
//  BRCArtTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCArtTableViewController.h"
#import "BRCDatabaseManager.h"
#import "YapDatabaseViewTransaction.h"
#import "BRCArtObject.h"

static NSString *const BRCArtTableViewCellIdentifier = @"BRCArtTableViewCellIdentifier";


@interface BRCArtTableViewController ()

@end

@implementation BRCArtTableViewController

- (id)init
{
    self = [self initWithItems:@[@"Name",@"Distance",@"Favorites"]];
    if (self) {
        self.title = @"Art";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:BRCArtTableViewCellIdentifier];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

////// Required //////
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    __block NSInteger numberOfRows = 0;
    [[BRCDatabaseManager sharedInstance].mainThreadReadOnlyDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfRows = [[transaction ext:BRCArtDatabaseViewExtensionName] numberOfKeysInGroup:[BRCArtObject collection]];
    }];
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BRCArtTableViewCellIdentifier forIndexPath:indexPath];
    __block BRCArtObject *artObject = nil;
    [[BRCDatabaseManager sharedInstance].mainThreadReadOnlyDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        artObject = [[transaction ext:BRCArtDatabaseViewExtensionName] objectAtIndex:indexPath.row inGroup:[BRCArtObject collection]];
    }];
    cell.textLabel.text = artObject.title;
    cell.detailTextLabel.text = artObject.detailDescription;
    return cell;
}

@end
