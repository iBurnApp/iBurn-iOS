//
//  InfoViewController.h
//  iBurn
//
//  Created by Andrew Johnson on 6/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface InfoViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
	UITableView *tableView;
	CGSize cellSize;
	UILabel *descriptionLabel;
  NSArray *headerTitles, *cellTexts;
}

- (id)initWithTitle:(NSString*)title;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath object:(id)object;

- (void) showOnMap;
- (void) showCamp;

@end
