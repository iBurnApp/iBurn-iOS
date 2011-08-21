//
//  SortableTable.h
//  iBurn
//
//  Created by Andrew Johnson on 8/21/11.
//


@interface SortableTable : UITableViewController <UITableViewDataSource, UITableViewDelegate> {
  UISegmentedControl *sortControl;
}


@property(nonatomic,retain) UISegmentedControl *sortControl;


@end
